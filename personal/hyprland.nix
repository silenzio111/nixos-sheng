{ config, lib, pkgs, ... }:
let
  user = "silenzio";
  password = import ./password.nix;
  keyboard = pkgs.writeShellApplication {
    name = "sheng-keyboard";
    runtimeInputs = [ pkgs.procps pkgs.wvkbd ];
    text = ''
      if pgrep -x wvkbd-mobintl >/dev/null; then
        pkill -RTMIN -x wvkbd-mobintl
      else
        wvkbd-mobintl -H 320 -L 260 &
      fi
    '';
  };
  desktop = pkgs.writeShellScript "sheng-hyprland-session" ''
    set -eu
    # The first user's home can be created before /etc/skel is populated.
    # Seed missing files before Hyprland can generate its default config.
    configHome="''${XDG_CONFIG_HOME:-$HOME/.config}"
    for relative in hypr/hyprland.lua waybar/config.jsonc waybar/style.css wofi/config; do
      if [ ! -e "$configHome/$relative" ]; then
        ${pkgs.coreutils}/bin/install -Dm644 \
          "/etc/skel/.config/$relative" "$configHome/$relative"
      fi
    done
    export XDG_CURRENT_DESKTOP=Hyprland
    export XDG_SESSION_DESKTOP=Hyprland
    export XDG_SESSION_TYPE=wayland
    exec ${pkgs.uwsm}/bin/uwsm start -e -D Hyprland -- hyprland.desktop
  '';
in
{
  networking.hostName = lib.mkForce "sheng-hyprland";
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "zh_CN.UTF-8/UTF-8" ];

  users.users.root.hashedPassword = lib.mkForce "!";
  services.getty.autologinUser = lib.mkForce null;
  users.users.${user} = {
    isNormalUser = true;
    inherit (password) hashedPassword;
    extraGroups = [ "wheel" "networkmanager" "video" "render" "input" ];
    openssh.authorizedKeys.keys = [ (builtins.readFile ./ssh.pub) ];
  };
  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  # Retain the USB console for first-boot diagnostics. The daily specialisation
  # releases the port for USB host use without needing a network rebuild.
  specialisation.daily.configuration = {
    services.shengSerialConsole.enable = lib.mkForce false;
  };

  hardware.graphics.enable = true;
  programs.hyprland.enable = true;
  programs.hyprland.xwayland.enable = true;
  programs.hyprland.withUWSM = true;
  security.polkit.enable = true;
  security.rtkit.enable = true;
  programs.dconf.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  services.greetd = {
    enable = true;
    settings = {
      initial_session = { command = "${desktop}"; inherit user; };
      default_session = {
        command = "${pkgs.greetd}/bin/agreety --cmd ${desktop}";
        user = "greeter";
      };
    };
  };
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  services.blueman.enable = true;
  services.gvfs.enable = true;
  services.upower.enable = true;
  services.libinput.enable = true;
  fonts.packages = with pkgs; [ dejavu_fonts noto-fonts-cjk-sans noto-fonts-color-emoji ];

  environment.systemPackages = with pkgs; [
    foot waybar wofi wvkbd keyboard firefox
    networkmanagerapplet blueman pavucontrol
    brightnessctl playerctl grim slurp wl-clipboard
    polkit_gnome thunar xdg-utils wlogout
    jq libinput usbutils
  ];

  environment.etc."skel/.config/hypr/hyprland.lua".text =
    builtins.replaceStrings [ "@POLKIT_AGENT@" ]
      [ "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1" ]
      (builtins.readFile ./hyprland.lua);
  environment.etc."skel/.config/waybar/config.jsonc".text = builtins.toJSON {
    layer = "top";
    height = 44;
    spacing = 8;
    "modules-left" = [ "custom/launcher" "hyprland/workspaces" "custom/terminal" "custom/keyboard" ];
    "modules-center" = [ "clock" ];
    "modules-right" = [ "tray" "network" "bluetooth" "pulseaudio" "backlight" "battery" "custom/power" ];
    "custom/launcher" = { format = " Apps "; "on-click" = "wofi --show drun"; };
    "custom/terminal" = { format = " Terminal "; "on-click" = "foot"; };
    "custom/keyboard" = { format = " Keyboard "; "on-click" = "sheng-keyboard"; };
    "hyprland/workspaces" = {
      "on-click" = "activate";
      "persistent-workspaces" = { "*" = [ 1 2 3 4 ]; };
    };
    clock = { format = "{:%m-%d %H:%M}"; };
    network = {
      "format-wifi" = "Wi-Fi {signalStrength}%";
      "format-disconnected" = "Wi-Fi off";
      "on-click" = "nm-connection-editor";
    };
    bluetooth = { format = "BT {status}"; "on-click" = "blueman-manager"; };
    pulseaudio = {
      format = "Vol {volume}%";
      "format-muted" = "Muted";
      "on-click" = "pavucontrol";
      "on-scroll-up" = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+";
      "on-scroll-down" = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
    };
    backlight = { format = "Light {percent}%"; "on-click" = "brightnessctl set 50%"; };
    battery = { format = "Bat {capacity}%"; "format-charging" = "Charging {capacity}%"; };
    "custom/power" = { format = " Power "; "on-click" = "wlogout"; };
  };
  environment.etc."skel/.config/waybar/style.css".text = ''
    * { font-family: "DejaVu Sans", "Noto Sans CJK SC"; font-size: 16px; }
    window#waybar { background: #1e1e2e; color: #cdd6f4; }
    #workspaces button { color: #cdd6f4; padding: 4px 10px; }
    #workspaces button.active { background: #313244; color: #89b4fa; }
    #custom-launcher, #custom-terminal, #custom-keyboard, #custom-power,
    #network, #bluetooth, #pulseaudio, #backlight, #battery, #clock {
      padding: 4px 8px;
    }
  '';
  environment.etc."skel/.config/wofi/config".text = ''
    width=600
    height=480
    allow_images=true
    insensitive=true
    prompt=Apps
  '';
}

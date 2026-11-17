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
        wvkbd-mobintl &
      fi
    '';
  };
  desktop = pkgs.writeShellScript "sheng-hyprland-session" ''
    export XDG_CURRENT_DESKTOP=Hyprland
    export XDG_SESSION_DESKTOP=Hyprland
    export XDG_SESSION_TYPE=wayland
    exec ${pkgs.dbus}/bin/dbus-run-session ${config.programs.hyprland.package}/bin/Hyprland
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
  security.polkit.enable = true;
  security.rtkit.enable = true;
  programs.dconf.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  services.greetd = {
    enable = true;
    settings = {
      initial_session = { command = "${desktop}"; inherit user; };
      default_session = { command = "${desktop}"; inherit user; };
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

  environment.etc."skel/.config/hypr/hyprland.conf".text = ''
    monitor = ,preferred,auto,2
    monitor = DSI-1,3048x2032@120,auto,2
    $mod = SUPER
    exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
    exec-once = waybar
    exec-once = nm-applet --indicator
    exec-once = blueman-applet
    exec-once = ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
    env = XCURSOR_SIZE,32
    env = HYPRCURSOR_SIZE,32
    env = QT_QPA_PLATFORM,wayland;xcb
    env = QT_AUTO_SCREEN_SCALE_FACTOR,1
    env = MOZ_ENABLE_WAYLAND,1
    input {
      kb_layout = us
      follow_mouse = 1
      touchpad {
        natural_scroll = true
        tap-to-click = true
      }
      touchdevice {
        output = DSI-1
      }
    }
    general {
      gaps_in = 4
      gaps_out = 8
      border_size = 2
      col.active_border = rgb(89b4fa)
      col.inactive_border = rgb(45475a)
      layout = dwindle
    }
    decoration {
      rounding = 12
      blur {
        enabled = false
      }
    }
    animations {
      enabled = false
    }
    misc {
      disable_hyprland_logo = true
      disable_splash_rendering = true
    }
    dwindle {
      preserve_split = true
    }
    bind = $mod, Return, exec, foot
    bind = $mod, D, exec, wofi --show drun
    bind = $mod, Q, killactive,
    bind = $mod, F, fullscreen,
    bind = $mod, V, togglefloating,
    bind = $mod, K, exec, sheng-keyboard
    bind = $mod, E, exec, thunar
    bind = $mod, B, exec, firefox
    bind = $mod, 1, workspace, 1
    bind = $mod, 2, workspace, 2
    bind = $mod, 3, workspace, 3
    bind = $mod, 4, workspace, 4
    bind = $mod SHIFT, 1, movetoworkspace, 1
    bind = $mod SHIFT, 2, movetoworkspace, 2
    bind = $mod SHIFT, 3, movetoworkspace, 3
    bind = $mod SHIFT, 4, movetoworkspace, 4
    bindm = $mod, mouse:272, movewindow
    bindm = $mod, mouse:273, resizewindow
    bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
    bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bindl = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    bindel = , XF86MonBrightnessUp, exec, brightnessctl set +5%
    bindel = , XF86MonBrightnessDown, exec, brightnessctl set 5%-
  '';
  environment.etc."skel/.config/waybar/config.jsonc".text = builtins.toJSON {
    layer = "top";
    height = 44;
    spacing = 8;
    "modules-left" = [ "custom/launcher" "hyprland/workspaces" "custom/terminal" "custom/keyboard" ];
    "modules-center" = [ "clock" ];
    "modules-right" = [ "network" "bluetooth" "pulseaudio" "backlight" "battery" "custom/power" ];
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

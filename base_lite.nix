
{ config, pkgs, ... }:
let
  nixChannel = "https://nixos.org/channels/nixos-24.11"; 
in
{
  zramSwap.enable = true;
  systemd.extraConfig = ''
    DefaultTimeoutStopSec=10s
  '';

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;

  # Wayland support
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
  };


  environment.systemPackages = with pkgs; [
    # Version control and network tools
    git
    curl
    neovim
    alacritty

    # Web browser
    firefox

    # KDE Applications
    libnotify
    kcalc           # KDE Calculator
    merkuro         # KDE Calendar
    spectacle       # KDE Screenshot tool

    # System utilities
    gawk
    sudo
    system-config-printer
  ];

  # Optional: Set neovim as default editor
  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    TERMINAL = "alacritty";
  };
  # XDG Portal for Wayland
  xdg = {
    portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-kde
      ];
    };
  };

  nix.gc = {
    automatic = true;
    dates = "Mon 3:40";
    options = "--delete-older-than 14d";
  };

  # Auto update config, channel
  systemd.timers."auto-update-config" = {
  wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      Unit = "auto-update-config.service";
    };
  };

  systemd.services."auto-update-config" = {
    script = ''
      set -eu
      export PATH=${pkgs.git}/bin:${pkgs.nix}/bin:${pkgs.gnugrep}/bin:${pkgs.gawk}/bin:${pkgs.util-linux}/bin:${pkgs.coreutils-full}/bin::$PATH

      # Update nixbook configs
      git -C /etc/nixbook reset --hard
      git -C /etc/nixbook clean -fd
      git -C /etc/nixbook pull --rebase

      currentChannel=$(nix-channel --list | grep '^nixos' | awk '{print $2}')
      targetChannel="${nixChannel}"

      echo "Current Channel is: $currentChannel"

      if [ "$currentChannel" != "$targetChannel" ]; then
        echo "Updating Nix channel to $targetChannel"
        nix-channel --add "$targetChannel" nixos
        nix-channel --update
      else
        echo "Nix channel is already set to $targetChannel"
      fi
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    after = [ "network-online.target" "graphical.target" ];
    wants = [ "network-online.target" ];
  };

  # Auto Upgrade NixOS
  systemd.timers."auto-upgrade" = {
  wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
      Unit = "auto-upgrade.service";
    };
  };

  systemd.services."auto-upgrade" = {
    script = ''
      set -eu
      export PATH=${pkgs.nixos-rebuild}/bin:${pkgs.nix}/bin:${pkgs.systemd}/bin:${pkgs.util-linux}/bin:${pkgs.coreutils-full}/bin:$PATH
      export NIX_PATH="nixpkgs=${pkgs.path} nixos-config=/etc/nixos/configuration.nix"
      
      systemctl start auto-update-config.service
      nice -n 19 ionice -c 3 nixos-rebuild boot --upgrade
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };

    after = [ "network-online.target" "graphical.target" ];
    wants = [ "network-online.target" ];
  };
  
}

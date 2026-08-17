{pkgs, ...}: {
  # Headless server profile.
  #
  # Deliberately does NOT import:
  #   ./linux/packages.nix — carries the whole Playwright GTK/CUPS/mesa desktop
  #                          stack, which is dead weight on a box with no display
  #   ./personal.nix       — pulls in Obsidian (Electron). identity-personal.nix
  #                          below gives the git identity without it
  imports = [
    ./shared/cli.nix
    ./shared/git.nix
    ./shared/shell.nix
    ./shared/editor.nix
    ./shared/tmux.nix
    ./identity-personal.nix
  ];

  home.packages = with pkgs; [
    # Build tooling — kodama compiles its own generations when kasasagi is off.
    gcc
    gnumake
    unzip
    curl

    # Server-shaped extras
    lazydocker # container status without memorising docker ps flags
    dua        # disk usage — the failure mode on a media box is a full disk
    rsync      # library moves to and from the external drive
    glow
  ];

  home.sessionPath = [ "$HOME/.local/bin" ];

  programs.zsh.shellAliases = {
    # Mirrors the `hms` alias on the WSL box, but for a whole NixOS system.
    "nrs" = "sudo nixos-rebuild switch --flake ~/nix-config#kodama";
    "nrb" = "sudo nixos-rebuild boot --flake ~/nix-config#kodama";
  };

  programs.zsh.initContent = ''
    [[ -f ~/.secrets/env ]] && source ~/.secrets/env
  '';

  home.stateVersion = "26.05";
  programs.home-manager.enable = true;
}

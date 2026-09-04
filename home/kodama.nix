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

    # Agentic CLI, run on the box itself rather than driven over SSH from
    # kasasagi. The point is phone access: ssh in from anywhere on the tailnet,
    # `ta` into the persistent tmux session, and pick up whatever was running.
    # tmux comes from ./shared/tmux.nix and the `ta` alias from ./shared/shell.nix,
    # so the session survives the connection dropping — which it will, from a phone.
    #
    # `pi` (pi.dev) rather than claude-code: minimal harness, four tools
    # (read/write/edit/bash), behaviour left to skills and extensions.
    # Packaged in nixpkgs, so no npm and no nix-ld wrapper. Binary is `pi`.
    #
    # ⚠️ BYO model — needs an API key in ~/.secrets/env (sourced by zsh below),
    # which is pay-per-token, unlike a flat Claude subscription.
    pi-coding-agent
  ];

  home.sessionPath = [ "$HOME/.local/bin" ];

  programs.zsh.shellAliases = {
    # Mirrors the `hms` alias on the WSL box, but for a whole NixOS system.
    "nrs" = "sudo nixos-rebuild switch --flake ~/nix-config#kodama";
    "nrb" = "sudo nixos-rebuild boot --flake ~/nix-config#kodama";

    # Resume the last pi conversation rather than starting cold. `ta` restores
    # the tmux session but not the agent's context, and after a reboot that is
    # the whole point — the phone workflow is `ssh kodama` -> `ta` -> `p`.
    # Plain `pi` is still there for a genuinely fresh session.
    "p" = "pi -c";
  };

  programs.zsh.initContent = ''
    [[ -f ~/.secrets/env ]] && source ~/.secrets/env
  '';

  home.stateVersion = "26.05";
  programs.home-manager.enable = true;
}

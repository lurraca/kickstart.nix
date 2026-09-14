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
    ./shared/herdr.nix
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

    # Sends the magic packet that wakes tokoyo. kodama is the only box that is
    # always on, so it is the only one that can do this. Same L2 segment
    # (192.168.1.111 -> 192.168.1.4), so a broadcast reaches it.
    # ⚠️ Waking needs BOTH halves: the BIOS keeps the NIC powered in soft-off
    # and permits a PCIe wake (done 12 Sep, ROB-119), and tokoyo's OS must arm
    # the card's wake register before shutdown, or the driver disarms on the
    # way down. On tokoyo that is NetworkManager, not a systemd unit:
    #   sudo nmcli connection modify "Wired connection 1" 802-3-ethernet.wake-on-lan magic
    wakeonlan
  ];

  home.sessionPath = [ "$HOME/.local/bin" ];

  programs.zsh.shellAliases = {
    # Mirrors the `hms` alias on the WSL box, but for a whole NixOS system.
    "nrs" = "sudo nixos-rebuild switch --flake ~/nix-config#kodama";
    "nrb" = "sudo nixos-rebuild boot --flake ~/nix-config#kodama";

    # Resume the last pi conversation rather than starting cold, which after a
    # reboot is the whole point. The phone workflow is `ssh kodama` -> `h` ->
    # pick up pi in its pane; `p` is the fallback when pi is not already
    # running, and plain `pi` starts a genuinely fresh session.
    # 12 Sep: this used to route through tmux (`ta`). Agents run under herdr on
    # both machines now, so tmux is no longer in the path — the `ta` alias in
    # ./shared/shell.nix survives for the other hosts.
    "p" = "pi -c";

    # Matches Omarchy's own `h` on tokoyo. Attaches the persistent session.
    "h" = "herdr";

    # Wake tokoyo. MAC is enp7s0, the Intel I225-V, measured 12 Sep and
    # matching the 10 Sep handover brief. Typed from a phone, so it is one
    # word rather than a MAC nobody remembers.
    "waketokoyo" = "wakeonlan f0:2f:74:23:8d:23";
  };

  programs.zsh.initContent = ''
    [[ -f ~/.secrets/env ]] && source ~/.secrets/env
  '';

  home.stateVersion = "26.05";
  programs.home-manager.enable = true;
}

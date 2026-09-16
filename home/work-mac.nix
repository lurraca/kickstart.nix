{pkgs, ...}: {
  imports = [
    ./shared/cli.nix
    ./shared/git.nix
    ./shared/shell.nix
    ./shared/editor.nix
    ./shared/tmux.nix
    ./shared/herdr.nix
    ./darwin/packages.nix
    ./darwin/homelab-ssh.nix
    ./darwin/aerospace.nix
    ./work.nix
  ];

  home.stateVersion = "23.11";
  programs.home-manager.enable = true;

  # Hide desktop icons (macOS "Show Items → On Desktop" toggle)
  targets.darwin.defaults."com.apple.finder".CreateDesktop = false;
}

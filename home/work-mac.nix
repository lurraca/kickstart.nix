{pkgs, ...}: {
  imports = [
    ./shared/cli.nix
    ./shared/git.nix
    ./shared/shell.nix
    ./shared/editor.nix
    ./shared/tmux.nix
    ./darwin/packages.nix
    ./work.nix
  ];

  home.stateVersion = "23.11";
  programs.home-manager.enable = true;
}

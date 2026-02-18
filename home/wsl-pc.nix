{pkgs, ...}: {
  imports = [
    ./shared/cli.nix
    ./shared/git.nix
    ./shared/shell.nix
    ./shared/editor.nix
    ./shared/tmux.nix
    ./linux/packages.nix
    ./personal.nix
  ];

  home.packages = with pkgs; [
    claude-code
  ];

  home.stateVersion = "24.05";
  programs.home-manager.enable = true;
}

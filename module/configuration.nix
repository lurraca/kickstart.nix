{username}: {self, pkgs, ...}: {
  nix = {
    settings = {
      builders-use-substitutes = true;
      experimental-features = "nix-command flakes";
      substituters = ["https://nix-community.cachix.org"];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      trusted-users = ["@wheel"];
      warn-dirty = false;
    };
  };

  system = {
    configurationRevision = self.rev or self.dirtyRev or null;
    stateVersion = 6;
  };

  environment = {
    shells = [pkgs.zsh];
  };

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config = {
      allowUnfree = true;
    };
  };

  fonts.packages = [
    pkgs.nerd-fonts.fira-code
    pkgs.nerd-fonts.fira-mono
    pkgs.nerd-fonts.hack
    pkgs.nerd-fonts.jetbrains-mono
  ];

  programs.zsh.enable = true;
  # Skip nix-darwin's uncached compinit in /etc/zshrc: it audits ~1200 nix
  # completion functions on every shell start (~2.7s). home-manager runs a
  # single cached compinit instead (see home/shared/shell.nix completionInit).
  programs.zsh.enableGlobalCompInit = false;

  users.users."luis.urraca" = {
    home = "/Users/luis.urraca";
    shell = pkgs.zsh;
  };
}

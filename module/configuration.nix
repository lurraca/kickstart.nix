{username}: {pkgs, ...}: {
  # add more system settings here
  nix = {
    settings = {
      #auto-optimise-store = true;
      builders-use-substitutes = true;
      # experimental-features = ["flakes" "nix-command"];
      substituters = ["https://nix-community.cachix.org"];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      trusted-users = ["@wheel"];
      warn-dirty = false;
    };
  };

  system = {
  };

  environment = {
    shells = [pkgs.zsh];
  };

  fonts.packages = [
    pkgs.nerd-fonts.fira-code
    pkgs.nerd-fonts.fira-mono
    pkgs.nerd-fonts.hack
    pkgs.nerd-fonts.jetbrains-mono
  ];

  programs.zsh.enable = true;

  users.users."luis.urraca" = {
    home = "/Users/luis.urraca";
    shell = pkgs.zsh;
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };
}

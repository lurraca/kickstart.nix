{
  description = "nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, home-manager, nix-darwin, nixpkgs }:
  let
    username = "luis.urraca";
    systemConfig = import ./module/configuration.nix { inherit username; };
    homeManagerConfig = import ./module/home-manager.nix;
    libHomebrew = import ./lib/homebrew.nix;
  in
  {
    darwinConfigurations."X7X56XWY9W" = nix-darwin.lib.darwinSystem {
      specialArgs = { inherit self; };
      modules = [
        systemConfig
        libHomebrew
        inputs.home-manager.darwinModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users."${username}" = homeManagerConfig;
        }
      ];
    };
  };
}

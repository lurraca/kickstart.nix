{
  description = "Example kickstart Nix on macOS environment.";

  inputs = {
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    darwin.url = "github:lnl7/nix-darwin";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-23.11";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  };

  outputs = inputs @ {
    self,
    darwin,
    home-manager,
    nixpkgs,
    ...
  }: let
      darwin-system = import ./system/darwin.nix {inherit username inputs;};
      username = "luis.urraca";
      system = "aarch64-darwin";
  in {
    darwinConfigurations = {
      host = darwin-system system;
    };
  };
}

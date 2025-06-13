{
  description = "Example kickstart Nix on macOS environment.";

  inputs = {
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    darwin.url = "github:lnl7/nix-darwin";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-24.05";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
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
    system = "X7X56XWY9W.local";
  in {
    darwinConfigurations = {
      host = darwin-system system;
    };
  };
}

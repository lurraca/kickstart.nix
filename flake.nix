{
  description = "multi-host nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nixgl.url = "github:nix-community/nixGL";
    nixgl.inputs.nixpkgs.follows = "nixpkgs";
    claude-code.url = "github:sadjow/claude-code-nix";
    claude-code.inputs.nixpkgs.follows = "nixpkgs";
    opencode.url = "github:AodhanHayter/opencode-flake";
    opencode.inputs.nixpkgs.follows = "nixpkgs";
    treehouse.url = "github:kunchenguid/treehouse";
    treehouse.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, home-manager, nix-darwin, nixpkgs, nixgl, claude-code, opencode, treehouse }:
  let
    systemConfig = import ./module/configuration.nix { username = "luis.urraca"; };
    homeManagerConfig = import ./home/work-mac.nix;
    libHomebrew = import ./lib/homebrew.nix;
    piOverlay = import ./lib/pi-coding-agent-overlay.nix;
  in
  {
    # macOS (nix-darwin + home-manager as module)
    darwinConfigurations."X7X56XWY9W" = nix-darwin.lib.darwinSystem {
      specialArgs = { inherit self; };
      modules = [
        systemConfig
        libHomebrew
        { nixpkgs.overlays = [ piOverlay ]; }
        inputs.home-manager.darwinModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users."luis.urraca" = homeManagerConfig;
        }
      ];
    };

    # Standalone home-manager (WSL2 Ubuntu)
    homeConfigurations."kasasagi" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux.extend piOverlay;
      extraSpecialArgs = { inherit inputs nixgl claude-code opencode; };
      modules = [
        ./home/wsl-pc.nix
        {
          home.username = "kasasagi";
          home.homeDirectory = "/home/kasasagi";
          nixpkgs.config.allowUnfree = true;
          nixpkgs.config.allowUnfreePredicate = _: true;
        }
      ];
    };
  };
}

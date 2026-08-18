{
  description = "multi-host nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    # Declarative disk partitioning for the kodama server host.
    #
    # git+https, not the github: shorthand. The shorthand fetches a codeload
    # tarball, and codeload has its own IP-based rate limiter separate from
    # the API — it returned HTTP 429 here even with a valid token (API quota
    # was 0/5000 at the time). Git protocol is a different endpoint and was
    # unaffected. Switch back to `github:` if this ever needs the speed.
    disko.url = "git+https://github.com/nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixgl.url = "github:nix-community/nixGL";
    nixgl.inputs.nixpkgs.follows = "nixpkgs";
    claude-code.url = "github:sadjow/claude-code-nix";
    claude-code.inputs.nixpkgs.follows = "nixpkgs";
    opencode.url = "github:AodhanHayter/opencode-flake";
    opencode.inputs.nixpkgs.follows = "nixpkgs";
    treehouse.url = "github:kunchenguid/treehouse";
    treehouse.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, home-manager, nix-darwin, nixpkgs, nixgl, claude-code, opencode, treehouse, disko }:
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

    # NixOS server — ThinkCentre M920q, homelab box (home-manager as a module,
    # same pattern as the darwin host above).
    nixosConfigurations."kodama" = nixpkgs.lib.nixosSystem {
      # No `system =` here: it is deprecated in favour of nixpkgs.hostPlatform,
      # which hardware-configuration.nix already sets.
      specialArgs = { inherit self inputs; };
      modules = [
        inputs.disko.nixosModules.disko
        ./hosts/kodama/disk.nix
        ./hosts/kodama/persistence.nix
        ./hosts/kodama/configuration.nix
        ./hosts/kodama/monitoring.nix
        ./hosts/kodama/homepage.nix
        ./hosts/kodama/media.nix
        { nixpkgs.overlays = [ piOverlay ]; }
        home-manager.nixosModules.home-manager {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs claude-code opencode; };
          home-manager.users."kasasagi" = import ./home/kodama.nix;
        }
      ];
    };

    # Custom installer ISO for kodama — sshd + authorised key baked in, so the
    # install runs over AMT IDE-R with no keyboard and no USB stick.
    #   nix build .#kodama-installer
    nixosConfigurations."kodama-installer" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./hosts/kodama/installer.nix ];
    };
    packages.x86_64-linux.kodama-installer =
      self.nixosConfigurations."kodama-installer".config.system.build.isoImage;

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

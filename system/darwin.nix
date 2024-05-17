# system/darwin.nix
{ inputs, username }: system:
let
  system-config = import ../module/configuration.nix { inherit username; };
  home-manager-config = import ../module/home-manager.nix;
in
  inputs.darwin.lib.darwinSystem {
    inherit system;
    modules = [
      {
        services.nix-daemon.enable = true;

        users.users."${username}" = {
          home = "/Users/${username}";
        };
      }
      system-config
      inputs.home-manager.darwinModules.home-manager {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users."${username}" = home-manager-config;
      }
      ../lib/homebrew.nix
    ];
  }

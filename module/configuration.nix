{username}: {pkgs, ...}:
{
  # add more system settings here
  nix = {
    settings = {
      auto-optimise-store = true;
      builders-use-substitutes = true;
      experimental-features = ["flakes" "nix-command"];
      substituters = ["https://nix-community.cachix.org"];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      trusted-users = ["@wheel"];
      warn-dirty = false;
    };
  };

  system = {
    activationScripts.postUserActivation.text = ''
    # Following line should allow us to avoid a logout/login cycle
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';
    defaults = {
      dock = {
        mru-spaces = false;
        autohide = true;
        show-recents = false;
        tilesize = 32;
        show-process-indicators = true;
        orientation = "bottom";
        wvous-tr-corner = 13;
      };
      CustomUserPreferences = {
        "com.apple.screencapture" = {
          location = "~/Desktop";
          type = "png";
        };
        "com.apple.desktopservices" = {
          # Avoid creating .DS_Store files on network or USB volumes
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };
      };
      NSGlobalDomain = {
        # 2 = heavy font smoothing; if text looks blurry, back this down to 1
        AppleFontSmoothing = 2;
        AppleShowAllExtensions = true;
      };
    };
  };
  
  services.nix-daemon.enable = true;

  environment = {
    shells = [pkgs.zsh];
    loginShell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  users.users.${username} = {
    home = "/Users/${username}";
    shell = pkgs.zsh;
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };
}

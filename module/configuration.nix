{username}: {self, pkgs, ...}: {
  # nix-darwin master vs nixpkgs-unstable: nixos-render-docs CLI skew breaks
  # the HTML manual build; keep man pages, skip the HTML docs.
  documentation.doc.enable = false;
  # The uninstaller builds an embedded pristine darwin-system with default
  # options (docs on), which hits the same nixos-render-docs breakage.
  system.tools.darwin-uninstaller.enable = false;

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
      # Netskope (Zendesk's corporate TLS-intercepting proxy) terminates
      # outbound HTTPS with its own root CA. The user's shell tools pick
      # this up via ~/.netskope-env (SSL_CERT_FILE et al.), but the nix
      # daemon is a separate system process with its own trust store and
      # doesn't inherit shell env vars. Without this, any nix fetch that
      # crosses Netskope's proxy (tarballs.nixos.org substitute checks,
      # fetchFromGitHub, cargo/npm vendoring FODs) fails with "self-signed
      # certificate in certificate chain". The bundle below is a full
      # combined chain (132 certs: system roots + Netskope's root), not
      # just Netskope's cert alone, so it doesn't break trust to
      # non-intercepted hosts.
      ssl-cert-file = "/Users/luis.urraca/.netskope-cert-bundle.pem";
    };
    # Keep /nix/store from growing forever: old system generations pin their
    # full ~8GiB closure each, and without GC they accumulate (33 gens ≈ 150GiB).
    gc = {
      automatic = true;
      interval = { Weekday = 1; Hour = 3; Minute = 0; }; # Mondays 03:00
      options = "--delete-older-than 7d";
    };
    # Hardlink identical files in the store to dedup closure bloat.
    settings.auto-optimise-store = true;
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

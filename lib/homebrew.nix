{
  config,
  pkgs,
  ...
}: {
  homebrew.enable = true;
  system.primaryUser = "luis.urraca";

  homebrew.brews = [
    "bun"
    "carvel-dev/carvel/vendir"
    "docker-credential-helper-ecr"
    "librdkafka"
    "openjdk@21"
    "rbenv"
    "ruby-build"
    "sbt"
    "snowflake-cli"
    "zendesk/devops/appconfig"
    "zendesk/devops/cicd-cli"
    "zendesk/zendesk/ric"
    "zendesk/zendesk/zd_sigil"
    "zendesk-aws-shell"
  ];

  homebrew.casks = [
    "1password"
    "zen-browser"
    # Cask (not nixpkgs) so the Accessibility grant targets the stable
    # /Applications path instead of a versioned /nix/store path.
    "nikitabobko/tap/aerospace"
    "claude"
    # @latest variant tracks Anthropic's fast release channel (~daily) — the
    # plain claude-code cask only moves when someone manually bumps it.
    "claude-code@latest"
    "cmux"
    "cursor"
    "cursor-cli"
    "docker-desktop"
    "github"
    "karabiner-elements"
    "logi-options+"
    "notion"
    "obs"
    "obsidian"
    "raycast"
    "shottr"
    "superlist"
    "zd_aws-sso"
  ];

  homebrew.taps = [
    "nikitabobko/tap"
    {
      name = "zendesk/devops";
      clone_target = "git@github.com:zendesk/homebrew-devops.git";
    }
    {
      name = "zendesk/zendesk";
      clone_target = "git@github.com:zendesk/homebrew-zendesk.git";
    }
    "carvel-dev/carvel"
    "oven-sh/bun"
  ];
}

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
    "arc"
    "claude"
    "claude-code"
    "cursor"
    "cursor-cli"
    "docker-desktop"
    "github"
    "logi-options-plus"
    "notion"
    "obsidian"
    "raycast"
    "shottr"
    "superlist"
    "zd_aws-sso"
  ];

  homebrew.taps = [
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

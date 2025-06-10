{
  config,
  pkgs,
  ...
}: {
  homebrew.enable = true;

  homebrew.brews = [
    "carvel-dev/carvel/vendir"
    "docker-credential-helper-ecr"
    "librdkafka"
    "zendesk/devops/appconfig"
    "zendesk/devops/cicd-cli"
    "zendesk/zendesk/ric"
    "zendesk/zendesk/zd_sigil"
  ];

  homebrew.casks = [
    "1password"
    "arc"
    "github"
    "logi-options-plus"
    "notion"
    "shottr"
    "superlist"
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
  ];
}

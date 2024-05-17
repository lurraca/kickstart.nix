{
  config,
  pkgs,
  ...
}: {
  homebrew.enable = true;

  homebrew.brews = [
    "docker-credential-helper-ecr"
    "carvel-dev/carvel/vendir"
    "zendesk/devops/appconfig"
    "zendesk/devops/cicd-cli"
    "zendesk/zendesk/ric"
    "zendesk/zendesk/zd_sigil"
  ];

  homebrew.casks = [
    "1password"
    "arc"
    "docker"
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

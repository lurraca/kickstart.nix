{lib, ...}: {
  programs.git = {
    enable = true;

    ignores = [
      ".DS_Store"
    ];

    settings = {
      user = {
        email = lib.mkDefault "luis.urraca@zendesk.com";
        name = lib.mkDefault "Luis Urraca";
      };
      push = {autoSetupRemote = true;};
      #   url = {
      #     "git@github.com:" = {
      #       insteadOf = "https://github.com/";
      #     };
      #   };
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      line-numbers = true;
      navigate = true;
      keep-plus-minus-markers = true;
      side-by-side = true;
    };
  };

  programs.gh = {
    enable = true;
  };
}

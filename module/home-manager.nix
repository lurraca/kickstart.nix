{pkgs, ...}: {
  # add home-manager user settings here
  home.packages = with pkgs; [];
  home.stateVersion = "23.11";


  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;

    # plugins:
    # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins
    # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/gh
    # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/z
    oh-my-zsh = {
      plugins = ["aliases" "gh" "git" "themes" "web-search" "z"];
      theme = "robbyrussell";
    };

    shellAliases = {
      "cat"            = "bat";
      "be"             = "bundle exec";
      "docker-machine" = "__docker_machine_wrapper";
      "drc"            = ''darwin-rebuild check --flake ".#x86_64"'';
      "drs"            = ''darwin-rebuild switch --flake ".#x86_64"'';
      "gbr"            = "git branch";
      "gci"            = "git commit";
      "gco"            = "git checkout";
      "gpf"            = "git push --force-with-lease";
      "gst"            = "git status";
      "gti"            = "git";
      "k"              = "kubectl";
      "ka"             = "kubectl --as admin --as-group system:masters --context";
      "kc"             = "kubectl --context";
      "knife"          = "be knife";
      "kz"             = "kubectl --as admin --as-group edge-infra-admin --as-group system:authenticated --namespace zorg --context";
      "ll"             = "ls -lah";
      "t"              = "tmux -f ~/.config/tmux.conf";
      "v"              = "nvim";
      "vi"             = "nvim";
      "vim"            = "nvim";
    };

    syntaxHighlighting = {
      enable = true;
    };
  };


{pkgs, ...}: let
  # nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs-unstable
  # nix-channel --update
  #unstablePkgs = import <nixpkgs-unstable> {};
in {
  # add home-manager user settings here
  # packages managed directly with nix
  home.packages = with pkgs; [
    alejandra
    amazon-ecr-credential-helper
    awscli2
    delta
    discord
    lua5_1
    lua51Packages.luarocks
    nerdfonts
    nil
    jetbrains.goland
    jetbrains.idea-ultimate
    raycast
    rustup
    saml2aws
    slack
    ssm-session-manager-plugin
    tig
    unixtools.watch
    wget
    zoom-us
  ];

  home.stateVersion = "23.11";

  home.sessionVariables = {
    EDITOR = "nvim";
    SHELL = "${pkgs.zsh}/bin/zsh";
  };

  programs.alacritty = {
    enable = true;

    settings = {
      font = {
        normal = {
          family = "Hack Nerd Font Mono";
        };
        size = 15;
      };

      live_config_reload = true;

      selection.save_to_clipboard = true;

      shell = {
        program = "${pkgs.zsh}/bin/zsh";
      };

      window = {
        decorations = "buttonless";
        dimensions = {
          columns = 270;
          lines = 80;
        };
        opacity = 0.85;
        padding = {
          x = 25;
          y = 20;
        };
      };
    };
  };

  programs.bat = {
    enable = true;

    config = {
      theme = "1337";
    };
  };

  programs.bottom = {
    enable = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.eza = {
    enable = true;
  };

  programs.git = {
    enable = true;

    userEmail = "luis.urraca@zendesk.com";
    userName = "Luis Urraca";

    delta = {
      enable = true;
      options = {
        line-numbers = true;
        navigate = true;
        keep-plus-minus-markers = true;
        side-by-side = true;
      };
    };

    ignores = [
      ".DS_Store"
    ];

    # extraConfig = {
    #   url = {
    #     "git@github.com:" = {
    #       insteadOf = "https://github.com/";
    #     };
    #   };
    # };
  };

  programs.gh = {
    enable = true;
  };

  programs.hstr = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.jq = {
    enable = true;
  };

  programs.neovim = {
    enable = true;
  };

  programs.ripgrep = {
    enable = true;
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      palette = "catppuccin_macchiato";

      git_status = {
        deleted = "✗";
        modified = "✶";
        staged = "✓";
        stashed = "≡";
      };

      palettes = {
        catppuccin_macchiato = {
          flamingo = "#f0c6c6";
          maroon = "#ee99a0";
          mauve = "#c6a0f6";
          peach = "#f5a97f";
          pink = "#f5bde6";
          red = "#ed8796";
          rosewater = "#f4dbd6";
        };
      };

      right_format = "$time";

      time = {
        disabled = false;
      };
    };
  };

  programs.tmux = {
    enable = true;
    historyLimit = 10000;
    mouse = true;
    shell = "${pkgs.zsh}/bin/zsh";

    extraConfig = ''
      unbind C-b
      set -g prefix C-a
      bind C-a send-prefix


      bind '"' split-window -h -c '#{pane_current_path}'
      bind % split-window -v -c '#{pane_current_path}'
    '';
  };

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
      "cat" = "bat";
      "be" = "bundle exec";
      "docker-machine" = "__docker_machine_wrapper";
      "drc" = ''darwin-rebuild check --flake ".#x86_64"'';
      "drs" = ''darwin-rebuild switch --flake ".#x86_64"'';
      "gbr" = "git branch";
      "gci" = "git commit";
      "gco" = "git checkout";
      "gpf" = "git push --force-with-lease";
      "gst" = "git status";
      "gti" = "git";
      "k" = "kubectl";
      "ka" = "kubectl --as admin --as-group system:masters --context";
      "kc" = "kubectl --context";
      "knife" = "be knife";
      "kz" = "kubectl --as admin --as-group edge-infra-admin --as-group system:authenticated --namespace zorg --context";
      "ll" = "ls -lah";
      "t" = "tmux -f ~/.config/tmux.conf";
      "v" = "nvim";
      "vi" = "nvim";
      "vim" = "nvim";
    };

    syntaxHighlighting = {
      enable = true;
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    options = [
      "--hook pwd"
    ];
  };
}

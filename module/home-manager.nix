{pkgs, ...}: {
  home.packages = with pkgs; [
    alejandra
    awscli2
    discord
    lua5_1
    lua51Packages.luarocks
    jetbrains.goland
    jetbrains.idea
    nodejs_24
    nil
    raycast
    rustup
    saml2aws
    slack
    ssm-session-manager-plugin
    stern
    tenv
    tig
    unixtools.watch
    wget
    zoom-us
  ];

  home.stateVersion = "23.11";

  home.sessionVariables = {
    CLAUDE_CODE_DISABLE_AUTO_MEMORY = "0";
    EDITOR = "nvim";
    SHELL = "${pkgs.zsh}/bin/zsh";
  };
  programs.home-manager.enable = true;

  programs.alacritty = {
    enable = true;

    settings = {
      font = {
        normal = {
          family = "Hack Nerd Font Mono";
        };
        size = 15;
      };

      general.live_config_reload = true;

      selection.save_to_clipboard = true;

      terminal.shell = {
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

    ignores = [
      ".DS_Store"
    ];

    settings = {
      user = {
        email = "luis.urraca@zendesk.com";
        name = "Luis Urraca";
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

      scala = {
        disabled = true;
      };

      time = {
        disabled = false;
      };
    };
  };

  programs.tmux = {
    enable = true;
    tmuxinator.enable = true;
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
    autosuggestion.enable = true;
    enableCompletion = true;

    initContent = ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
      source ~/Code/zendesk/kubectl_config/dotfiles/kubectl_stuff.bash
    '';

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
      "drc" = ''darwin-rebuild check --flake "/etc/nix-darwin#X7X56XWY9W"'';
      "drs" = ''darwin-rebuild switch --flake "/etc/nix-darwin#X7X56XWY9W"'';
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
      "superclaude" = "claude --dangerously-skip-permissions --model global.anthropic.claude-opus-4-6-v1";
      "t" = "tmux";
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

  xdg.configFile."tmuxinator/work.yml".text = ''
    name: work

    windows:
      - edge-state-manager:
          root: ~/Code/zendesk/edge-state-manager
          layout: even-horizontal
          panes:
            - superclaude
            -
      - zendesk-public-ips:
          root: ~/Code/zendesk/zendesk-public-ips
          layout: even-horizontal
          panes:
            - superclaude
            -
      - jaurvis:
          root: ~/Code/self/jaurvis
          layout: even-horizontal
          panes:
            - superclaude
            -
      - scratch:
          root: ~/Code
          layout: even-horizontal
          panes:
            - superclaude
            -
  '';
}

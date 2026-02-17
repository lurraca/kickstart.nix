{pkgs, ...}: {
  home.sessionVariables = {
    CLAUDE_CODE_DISABLE_AUTO_MEMORY = "0";
    EDITOR = "nvim";
    SHELL = "${pkgs.zsh}/bin/zsh";
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

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
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
      "gbr" = "git branch";
      "gci" = "git commit";
      "gco" = "git checkout";
      "gpf" = "git push --force-with-lease";
      "gst" = "git status";
      "gti" = "git";
      "ll" = "ls -lah";
      "t" = "tmux";
      "v" = "nvim";
      "vi" = "nvim";
      "vim" = "nvim";
    };

    syntaxHighlighting = {
      enable = true;
    };
  };
}

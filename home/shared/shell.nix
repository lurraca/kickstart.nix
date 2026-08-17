{pkgs, ...}: {
  home.sessionVariables = {
    CLAUDE_CODE_DISABLE_AUTO_MEMORY = "0";
    EDITOR = "nvim";
    SHELL = "${pkgs.zsh}/bin/zsh";
  };

  # Local bin for uvx, uv, and other user-installed tools (was in ~/.zprofile).
  home.sessionPath = ["$HOME/.local/bin"];

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

    # Cache compinit: the default is an uncached `compinit` that re-audits and
    # recompiles ~1200 nix completion functions on every shell start (~2.4s).
    # `-C` skips the audit and reuses the dumpfile; we rebuild the dump only
    # when it is missing or older than 20h, so completions still refresh but a
    # normal shell start pays ~0.05s instead of ~2.4s. Paired with
    # programs.zsh.enableGlobalCompInit = false in module/configuration.nix so
    # this is the only compinit that runs.
    completionInit = ''
      autoload -U compinit
      _zdump="''${ZDOTDIR:-$HOME}/.zcompdump"
      if [[ -n "$_zdump"(#qN.mh-20) ]]; then
        compinit -C -d "$_zdump"
      else
        compinit -d "$_zdump"
      fi
      unset _zdump
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
    "superclaude" = "claude --dangerously-skip-permissions";
    "cat" = "bat";
    "gbr" = "git branch";
    "gci" = "git commit";
    "gco" = "git checkout";
    "gpf" = "git push --force-with-lease";
    "gst" = "git status";
    "gti" = "git";
    "ll" = "ls -lah";
    "t" = "tmux";
    # Attach to the 'home' session (detaching other clients so the window
    # sizes to the current screen); create it if it doesn't exist.
    "ta" = "tmux new-session -A -D -s home";
    "v" = "nvim";
    "vi" = "nvim";
    "vim" = "nvim";
    # WSL clipboard integration
    "clip" = "/mnt/c/Windows/System32/clip.exe";
    "pbcopy" = "clip.exe";
    "pbpaste" = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -command 'Get-Clipboard' | tr -d '\r'";
  };

    syntaxHighlighting = {
      enable = true;
    };

    initContent = ''
      # Bandwhich wrapper - preserves PATH for sudo
      bw() {
        sudo -E env "PATH=$PATH" bandwhich "$@"
      }

      # Run `go` under sudo while preserving the Nix PATH (sudo's secure_path
      # strips it). Separate build cache keeps root-owned files out of GOCACHE.
      sudogo() {
        sudo env "PATH=$PATH" GOCACHE=/tmp/go-root-cache go "$@"
      }
    '';
  };
}

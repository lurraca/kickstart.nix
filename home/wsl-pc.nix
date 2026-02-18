{pkgs, ...}: {
  imports = [
    ./shared/cli.nix
    ./shared/git.nix
    ./shared/shell.nix
    ./shared/editor.nix
    ./shared/tmux.nix
    ./linux/packages.nix
    ./personal.nix
  ];

  home.packages = with pkgs; [
    opencode
    (pkgs.writeShellScriptBin "ghostty" ''
      export WAYLAND_DISPLAY=
      export DISPLAY=:0
      export LIBGL_ALWAYS_SOFTWARE=1
      exec ${pkgs.ghostty}/bin/ghostty "$@"
    '')
  ];

  # Ghostty config for WSL
  xdg.configFile."ghostty/config".text = ''
    font-family = "Hack Nerd Font Mono"
    font-size = 15

    window-decoration = false
    window-padding-x = 25
    window-padding-y = 20
    background-opacity = 0.85

    clipboard-read = allow
    clipboard-write = allow

    shell-integration = none
    command = wsl.exe -d Ubuntu --cd ~ -e zsh
  '';

  # Note: Ghostty doesn't use programs.ghostty module yet, configured manually above

  # OpenCode config — API key read from local file outside version control
  xdg.configFile."opencode/config.json".text = builtins.toJSON {
    model = "moonshotai/kimi-k2.5";
    provider = {
      nvidia = {
        npm = "@ai-sdk/openai-compatible";
        name = "NVIDIA NIM";
        options = {
          baseURL = "https://integrate.api.nvidia.com/v1";
          apiKey = "{file:~/.secrets/nvidia-api-key}";
        };
        models = {
          "moonshotai/kimi-k2.5" = {
            name = "Kimi K2.5";
          };
        };
      };
    };
    mcp = {
      playwright = {
        type = "stdio";
        command = "npx";
        args = ["@playwright/mcp@latest"];
      };
    };
  };

  # Source local secrets into shell (for tools that need env vars)
  programs.zsh.initContent = ''
    [[ -f ~/.secrets/env ]] && source ~/.secrets/env
  '';

  home.stateVersion = "24.05";
  programs.home-manager.enable = true;
}

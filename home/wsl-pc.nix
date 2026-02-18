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
    claude-code
    opencode
  ];

  # OpenCode config — API key read from local file outside version control
  xdg.configFile."opencode/config.json".text = builtins.toJSON {
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
  };

  # Source local secrets into shell (for tools that need env vars)
  programs.zsh.initContent = ''
    [[ -f ~/.secrets/env ]] && source ~/.secrets/env
  '';

  home.stateVersion = "24.05";
  programs.home-manager.enable = true;
}

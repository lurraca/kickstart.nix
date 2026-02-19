{pkgs, nixgl, ...}: {
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
    alacritty
    nixgl.packages.${pkgs.system}.nixGLIntel
  ];

  # Wrapper script for Alacritty with nixGL
  home.file.".local/bin/alacritty-wrapped" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      export WAYLAND_DISPLAY=
      export DISPLAY=:0
      exec ${nixgl.packages.${pkgs.system}.nixGLIntel}/bin/nixGLIntel ${pkgs.alacritty}/bin/alacritty "$@"
    '';
  };

  # Paste helper script using Windows PowerShell
  home.file.".local/bin/wsl-paste" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -command 'Get-Clipboard' | tr -d '\r'
    '';
  };

  # Alacritty config for WSL (manual config since we wrap the binary)
  xdg.configFile."alacritty/alacritty.toml".text = ''
    [font]
    size = 12

    [font.normal]
    family = "DejaVu Sans Mono"

    [font.offset]
    y = 1

    [general]
    live_config_reload = true

    [selection]
    save_to_clipboard = true

    [terminal]
    osc52 = "CopyPaste"

    [terminal.shell]
    program = "${pkgs.zsh}/bin/zsh"

    [window]
    decorations = "buttonless"
    opacity = 0.85

    [window.dimensions]
    columns = 120
    lines = 40

    [window.padding]
    x = 25
    y = 20

    [[keyboard.bindings]]
    key = "V"
    mods = "Control|Shift"
    action = "Paste"

    [[keyboard.bindings]]
    key = "C"
    mods = "Control|Shift"
    action = "Copy"
  '';

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

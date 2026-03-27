{pkgs, lib, nixgl, claude-code, opencode, ...}: {
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
    alacritty
    nerd-fonts.jetbrains-mono
    noto-fonts-cjk-sans
    piper-tts
    nixgl.packages.${pkgs.stdenv.hostPlatform.system}.nixGLIntel
    claude-code.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode
  ];

  # Wrapper script for Alacritty with nixGL
  home.file.".local/bin/alacritty-wrapped" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      export WAYLAND_DISPLAY=
      export DISPLAY=:0
      exec ${nixgl.packages.${pkgs.stdenv.hostPlatform.system}.nixGLIntel}/bin/nixGLIntel ${pkgs.alacritty}/bin/alacritty "$@"
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
    family = "JetBrainsMono Nerd Font"

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
    args = ["-l"]

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

  # Install/upgrade notebooklm-mcp-cli via uv on every home-manager switch
  home.activation.install-notebooklm-cli = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${pkgs.uv}/bin/uv tool install --upgrade notebooklm-mcp-cli
  '';

  # OpenCode config — copied (not symlinked) so opencode can write to it at runtime
  home.activation.opencode-config = lib.hm.dag.entryAfter ["writeBoundary"] ''
    config_dir="$HOME/.config/opencode"
    config_file="$config_dir/config.json"
    mkdir -p "$config_dir"
    if [ ! -e "$config_file" ] || [ -L "$config_file" ]; then
      rm -f "$config_file"
      cp ${pkgs.writeText "opencode-config.json" (builtins.toJSON {
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
            type = "local";
            command = ["npx" "@playwright/mcp@latest"];
            enabled = true;
          };
        };
      })} "$config_file"
      chmod 644 "$config_file"
    fi
  '';

  # Enable home-manager fontconfig so Nix-installed fonts are discoverable
  fonts.fontconfig.enable = true;

  # Fontconfig: fallback to Noto Sans CJK JP for Japanese glyphs
  xdg.configFile."fontconfig/conf.d/99-cjk-fallback.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <alias>
        <family>JetBrainsMono Nerd Font</family>
        <prefer>
          <family>JetBrainsMono Nerd Font</family>
          <family>Noto Sans CJK JP</family>
        </prefer>
      </alias>
      <alias>
        <family>monospace</family>
        <prefer>
          <family>JetBrainsMono Nerd Font</family>
          <family>Noto Sans CJK JP</family>
        </prefer>
      </alias>
    </fontconfig>
  '';

  home.sessionPath = [ "$HOME/.local/bin" ];

  programs.zsh.shellAliases = {
    "hms" = "nix flake update claude-code --flake ~/nix-config && home-manager switch --flake ~/nix-config#$USER";
  };

  # Source local secrets into shell (for tools that need env vars)
  programs.zsh.initContent = ''
    [[ -f ~/.secrets/env ]] && source ~/.secrets/env
  '';

  home.stateVersion = "24.05";
  programs.home-manager.enable = true;
}

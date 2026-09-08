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

  # Wrapper script for Obsidian with nixGL (Electron under WSLg)
  # --no-sandbox: Electron's sandbox does not work under WSL.
  # --ozone-platform=x11: WSLg exposes X11 here (WAYLAND_DISPLAY is empty).
  home.file.".local/bin/obsidian-wrapped" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      export WAYLAND_DISPLAY=
      export DISPLAY=:0
      exec ${nixgl.packages.${pkgs.stdenv.hostPlatform.system}.nixGLIntel}/bin/nixGLIntel \
        ${pkgs.obsidian}/bin/obsidian --no-sandbox --ozone-platform=x11 "$@"
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

  # ── Used-drive watch (Adverts.ie + DoneDeal) ───────────────────────────────
  #
  # 🔴 WHY THIS LIVES ON KASASAGI AND NOT ON KODAMA, where every other watcher
  # runs. Both sites sit behind Cloudflare and 403 plain curl outright, so the
  # RSS-and-a-regex approach used for the reddit parts watch cannot reach them.
  # scripts/drive-search.py in the robotina repo gets through with a REAL,
  # HEADED Chrome attached over CDP — every headless variant is blocked — and a
  # headed browser needs a display. kodama is a headless server; kasasagi has
  # WSLg. That is the whole reason, and it is unlikely to change.
  #
  # ⚖️ Consequence, stated rather than hidden: this only runs when kasasagi is
  # ON, and the live plan is to turn kasasagi off (~EUR350/yr). That is
  # acceptable here and nowhere else — a used private-seller ad needs a human to
  # message the seller anyway, so an alert that only arrives while Luis is at
  # the machine loses almost nothing. Anything that must fire unattended belongs
  # on kodama.
  #
  # Threshold and dedupe live in the script; the ntfy topic comes from
  # ~/.secrets/env, which is not in this repo.
  systemd.user.services.drive-watch = {
    Unit.Description = "Watch Adverts.ie + DoneDeal for cheap used NVMe";
    Service = {
      Type = "oneshot";
      # DISPLAY is for WSLg: the script falls back to :0 on its own, but being
      # explicit means a failure is a real failure and not a missing variable.
      Environment = [ "DISPLAY=:0" ];
      ExecStart = "${pkgs.bash}/bin/bash -lc 'python3 %h/code/robotina/scripts/drive-search.py --type nvme --min-capacity 1000 --notify'";
      # Chrome, Cloudflare and two scrapes: slow, and a hang must not wedge the timer.
      TimeoutStartSec = "12min";
    };
  };

  systemd.user.timers.drive-watch = {
    Unit.Description = "Daily used-drive check";
    Timer = {
      # Once a day is right: these are private-seller ads that sit for days, not
      # flash sales measured in minutes. The minute-scale deals are reddit's job.
      OnCalendar = "*-*-* 19:30";
      RandomizedDelaySec = "20min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  home.stateVersion = "24.05";
  programs.home-manager.enable = true;
}

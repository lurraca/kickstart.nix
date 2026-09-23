# Omarchy-style tiling on macOS: AeroSpace + Caps Lock as Hyper key.
#
# Modifier story:
#   - Karabiner-Elements remaps Caps Lock -> Ctrl+Alt+Cmd ("Hyper") when held,
#     Escape when tapped. Rule installed below as a karabiner asset.
#   - Every binding written "ctrl-alt-cmd-X" is physically "Caps + X",
#     matching Omarchy's "Super + X".
#
# Manual steps that Nix cannot do (macOS TCC is unscriptable):
#   1. Grant AeroSpace Accessibility permission on first launch.
#      (with launchd.enable, also allow the background item when prompted)
#   2. Approve the Karabiner driver extension, then in Karabiner-Elements:
#      Complex Modifications -> Add predefined rule -> "Caps Lock -> Hyper/Esc".
#   3. In Raycast settings, set the Raycast hotkey to Ctrl+Alt+Cmd+Space
#      (one owner per chord: Raycast owns Caps+Space, not AeroSpace).
{pkgs, lib, ...}: let
  # ---------------------------------------------------------------------------
  # Bindings: single source of truth for both AeroSpace and the cheatsheet.
  # key = aerospace binding string, desc = human label, cmd = aerospace command
  # (cmd omitted for chords owned by other apps, e.g. Raycast)
  # ---------------------------------------------------------------------------
  categories = [
    { title = "Launchers"; entries = [
      { key = "ctrl-alt-cmd-enter"; desc = "Terminal (Alacritty)";
        cmd = "exec-and-forget open -na Alacritty"; }
      { key = "ctrl-alt-cmd-space"; desc = "Raycast (hotkey set in Raycast prefs)"; }
      { key = "ctrl-alt-cmd-c"; desc = "Keybind cheatsheet";
        cmd = "exec-and-forget open ~/.config/aerospace/cheatsheet.html"; }
      { key = "ctrl-alt-cmd-b"; desc = "Browser (Zen)";
        cmd = "exec-and-forget open -na Zen"; }
      { key = "ctrl-alt-cmd-e"; desc = "Files (Finder)";
        cmd = "exec-and-forget open -a Finder"; }
    ]; }
    { title = "Windows"; entries = [
      { key = "ctrl-alt-cmd-w"; desc = "Close window"; cmd = "close"; }
      { key = "ctrl-alt-cmd-f"; desc = "Fullscreen"; cmd = "fullscreen"; }
      { key = "ctrl-alt-cmd-t"; desc = "Toggle floating / tiling";
        cmd = "layout floating tiling"; }
      # AeroSpace >=0.18: 'split' conflicts with container normalization;
      # toggling the tiles layout orientation is the equivalent.
      { key = "ctrl-alt-cmd-v"; desc = "Toggle split direction";
        cmd = "layout tiles horizontal vertical"; }
      { key = "ctrl-alt-cmd-s"; desc = "Toggle accordion layout";
        cmd = "layout accordion horizontal vertical"; }
      { key = "ctrl-alt-cmd-minus"; desc = "Shrink window"; cmd = "resize smart -50"; }
      { key = "ctrl-alt-cmd-equal"; desc = "Grow window"; cmd = "resize smart +50"; }
    ]; }
    { title = "Focus"; entries = [
      { key = "ctrl-alt-cmd-h"; desc = "Focus left"; cmd = "focus left"; }
      { key = "ctrl-alt-cmd-j"; desc = "Focus down"; cmd = "focus down"; }
      { key = "ctrl-alt-cmd-k"; desc = "Focus up"; cmd = "focus up"; }
      { key = "ctrl-alt-cmd-l"; desc = "Focus right"; cmd = "focus right"; }
      { key = "ctrl-alt-cmd-tab"; desc = "Cycle focus → next window";
        cmd = "focus --wrap-around dfs-next"; }
      { key = "ctrl-alt-cmd-shift-tab"; desc = "Cycle focus → previous window";
        cmd = "focus --wrap-around dfs-prev"; }
    ]; }
    { title = "Move windows"; entries = [
      { key = "ctrl-alt-cmd-shift-h"; desc = "Move left"; cmd = "move left"; }
      { key = "ctrl-alt-cmd-shift-j"; desc = "Move down"; cmd = "move down"; }
      { key = "ctrl-alt-cmd-shift-k"; desc = "Move up"; cmd = "move up"; }
      { key = "ctrl-alt-cmd-shift-l"; desc = "Move right"; cmd = "move right"; }
    ]; }
    { title = "Workspaces"; entries = [
      { key = "ctrl-alt-cmd-1"; desc = "Workspace 1"; cmd = "workspace 1"; }
      { key = "ctrl-alt-cmd-2"; desc = "Workspace 2"; cmd = "workspace 2"; }
      { key = "ctrl-alt-cmd-3"; desc = "Workspace 3"; cmd = "workspace 3"; }
      { key = "ctrl-alt-cmd-4"; desc = "Workspace 4"; cmd = "workspace 4"; }
      { key = "ctrl-alt-cmd-5"; desc = "Workspace 5"; cmd = "workspace 5"; }
      { key = "ctrl-alt-cmd-shift-1"; desc = "Move window → ws 1";
        cmd = "move-node-to-workspace 1"; }
      { key = "ctrl-alt-cmd-shift-2"; desc = "Move window → ws 2";
        cmd = "move-node-to-workspace 2"; }
      { key = "ctrl-alt-cmd-shift-3"; desc = "Move window → ws 3";
        cmd = "move-node-to-workspace 3"; }
      { key = "ctrl-alt-cmd-shift-4"; desc = "Move window → ws 4";
        cmd = "move-node-to-workspace 4"; }
      { key = "ctrl-alt-cmd-shift-5"; desc = "Move window → ws 5";
        cmd = "move-node-to-workspace 5"; }
    ]; }
  ];

  allEntries = lib.concatMap (c: c.entries) categories;

  # Bindings that AeroSpace owns (have a cmd), as an attrset
  aerospaceBindings = lib.listToAttrs (lib.concatMap (e:
    lib.optional (e ? cmd) { name = e.key; value = e.cmd; }
  ) allEntries);

  # ---------------------------------------------------------------------------
  # Pin apps to workspaces: every new window of these app-ids is moved to the
  # given workspace on detection. Find app-ids with:
  #   defaults read /Applications/<App>.app/Contents/Info CFBundleIdentifier
  # ---------------------------------------------------------------------------
  workspaceAssignments = [
    { app-id = "org.alacritty"; workspace = "1"; }          # Terminal
    { app-id = "app.zen-browser.zen"; workspace = "2"; }   # Zen Browser
    { app-id = "com.google.Chrome"; workspace = "2"; }     # Chrome
    { app-id = "com.tinyspeck.slackmacgap"; workspace = "2"; }   # Slack
    { app-id = "com.1password.1password"; workspace = "5"; }     # 1Password
    { app-id = "com.apple.finder"; workspace = "3"; }       # Finder
  ];

  # ---------------------------------------------------------------------------
  # Cheatsheet HTML, generated from the same `categories` table.
  # ---------------------------------------------------------------------------

  # "ctrl-alt-cmd-shift-h" -> "Caps ⇧ + H"  (ctrl-alt-cmd IS the Caps chord)
  pretty = key: let
    parts = lib.splitString "-" key;
    shift = lib.any (m: m == "shift") (lib.init parts);
    last = lib.last parts;
    name = { enter = "⏎"; space = "Space"; minus = "−"; equal = "="; }.${last}
      or (lib.toUpper last);
  in "Caps" + lib.optionalString shift " ⇧" + " + " + name;

  row = e: "<tr><td><kbd>${pretty e.key}</kbd></td><td>${e.desc}</td></tr>";

  section = cat: ''
    <h2>${cat.title}</h2>
    <table>${lib.concatStringsSep "\n" (map row cat.entries)}</table>
  '';

  cheatsheet = pkgs.writeText "aerospace-cheatsheet.html" ''
    <!doctype html><html><head><meta charset="utf-8"><title>Keybinds</title>
    <style>
      body { font: 14px -apple-system; background: #1e1e2e; color: #cdd6f4;
             max-width: 520px; margin: 32px auto; padding: 0 24px 32px; }
      h1 { font-size: 18px; color: #89b4fa; margin-bottom: 4px; }
      h2 { font-size: 13px; text-transform: uppercase; letter-spacing: 1px;
           color: #a6e3a1; margin: 22px 0 6px; border-bottom: 1px solid #313244;
           padding-bottom: 4px; }
      table { width: 100%; border-collapse: collapse; }
      td { padding: 5px 12px 5px 0; }
      td:last-child { color: #a6adc8; }
      kbd { background: #313244; border-radius: 4px; padding: 2px 8px;
            font-family: "SF Mono", monospace; font-size: 12px;
            white-space: nowrap; }
    </style></head>
    <body>
      <h1>Omarchy-style keybinds</h1>
      ${lib.concatStringsSep "\n" (map section categories)}
    </body></html>
  '';

  # ---------------------------------------------------------------------------
  # Karabiner rule: Caps Lock -> Hyper (hold) / Escape (tap).
  # Installed as a "complex modification asset"; enable it once in the
  # Karabiner-Elements UI (Complex Modifications -> Add predefined rule).
  # Karabiner owns karabiner.json and rewrites it, so we must NOT manage
  # that file with home-manager — assets are the supported extension point.
  # ---------------------------------------------------------------------------
  karabinerRule = pkgs.writeText "caps-hyper.json" (builtins.toJSON {
    title = "Caps Lock → Hyper / Escape";
    rules = [{
      description = "Caps Lock → Hyper (hold) / Escape (tap)";
      manipulators = [{
        type = "basic";
        from = { key_code = "caps_lock"; modifiers.optional = [ "any" ]; };
        to = [{
          key_code = "left_control";
          modifiers = [ "left_command" "left_option" ];
        }];
        to_if_alone = [{ key_code = "escape"; }];
      }];
    }];
  });
  # ---------------------------------------------------------------------------
  # aerospace.toml
  # NOTE: we deliberately do NOT use programs.aerospace / the nixpkgs package.
  # The app runs from the Homebrew cask at /Applications/AeroSpace.app so that
  # the macOS Accessibility (TCC) grant survives package updates — a Nix store
  # path changes on every version bump and silently breaks the permission.
  # The cask is installed via lib/homebrew.nix and manages its own login item.
  # ---------------------------------------------------------------------------
  aerospaceConfig = {
    # Login launch. 'start-at-login' is deprecated (parse warning), but it is
    # the ONLY mechanism proven to launch AeroSpace at login on this setup:
    # the cask registers no login item, and home-manager's launchd.agents
    # silently produced an empty home-manager-agents output (verified 22 Sep).
    start-at-login = true;

    enable-normalization-flatten-containers = true;
    enable-normalization-opposite-orientation-for-nested-containers = true;

    default-root-container-layout = "tiles";
    default-root-container-orientation = "auto";

    on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];

    on-window-detected = map (a: {
      # v2 callback syntax: if = 'test %{app-bundle-id} = <id>'
      # (the old dotted if.app-id is soft-deprecated; hyphenated if-app-id was never valid)
      "if" = "test %{app-bundle-id} = ${a.app-id}";
      run = [ "move-node-to-workspace ${a.workspace}" ];
    }) workspaceAssignments;

    gaps = {
      inner.horizontal = 8;
      inner.vertical = 8;
      outer.left = 8;
      outer.right = 8;
      outer.top = 8;
      outer.bottom = 8;
    };

    mode.main.binding = aerospaceBindings;
  };

  aerospaceToml = (pkgs.formats.toml {}).generate "aerospace.toml" aerospaceConfig;

  # ---------------------------------------------------------------------------
  # Login launch. 'start-at-login' is deprecated in favor of the app's own
  # login-item / launchd integration, BUT: the cask registers no login item,
  # and home-manager's launchd.agents option silently produces an empty
  # home-manager-agents output on this setup (verified 22 Sep — empty store
  # path, no plist in ~/Library/LaunchAgents). This key is the only mechanism
  # proven to launch AeroSpace at login here. Keep despite the parse warning.
  # ---------------------------------------------------------------------------
  launchd.agents.aerospace = lib.mkRemovedOptionless { }; # placeholder no-op

in {
  home.file.".config/aerospace/aerospace.toml".source = aerospaceToml;
  home.file.".config/aerospace/cheatsheet.html".source = cheatsheet;
  home.file.".config/karabiner/assets/complex_modifications/caps-hyper.json".source =
    karabinerRule;
}

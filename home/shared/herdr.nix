{pkgs, ...}: {
  # Shared by every host that runs agents under herdr and is managed here:
  # kodama (NixOS) and the work Mac (nix-darwin). tokoyo is NOT in this repo —
  # it gets herdr from Omarchy, and its ~/.config/herdr/config.toml is the
  # source the config below mirrors. Moved out of home/kodama.nix 14 Sep 2026
  # when the Mac joined, so the keymap cannot drift between machines.
  #
  # herdr reads ~/.config/herdr/config.toml on macOS too (not Application
  # Support): src/config/io.rs falls back to $HOME/.config on every non-Windows
  # platform. Checked against upstream source, 14 Sep.
  #
  # Terminal workspace manager for agents. 0.9.0 is the version that added
  # `herdr machine`, so one client on tokoyo can hold Local and this box in
  # the same sidebar instead of a separate window per machine — which is the
  # only reason it is here rather than on tokoyo alone.
  # Reaching it required bumping the nixpkgs input past 2026-08-28; nixpkgs
  # had 0.8.2 pinned, which has no `machine` command at all.
  # The keymap is no longer upstream's (ctrl+b): config.toml below is
  # home-manager-owned and mirrors tokoyo's ctrl+space, so the prefix is the
  # same on both machines. Copied by hand 12 Sep, declared here the same day.
  # `herdr integration install pi` adds agent-state detection for pi.
  home.packages = [ pkgs.herdr ];

  # Herdr's keymap, kept identical to tokoyo's so muscle memory carries across
  # machines. Upstream's default prefix is ctrl+b; Omarchy ships ctrl+space in
  # /usr/share/omarchy/config/herdr/config.toml, and nothing copies that here,
  # so it is declared rather than copied. `herdr server reload-config` applies
  # it to an already-running server without restarting panes.
  xdg.configFile."herdr/config.toml".text = ''
    onboarding = false
    # Mirrors the Omarchy tmux config in config/tmux/tmux.conf
    # tmux session -> herdr workspace, tmux window -> herdr tab, tmux pane -> herdr pane

    [theme]
    # tmux ran on the terminal's own palette (bg=default, fg=default, ANSI blue accents)
    name = "terminal"

    [theme.custom]
    # The active tab is drawn as panel_bg text on an accent background, so panel_bg
    # has to be dark for it to read - same colors as status-left's "#[fg=black,bg=blue]"
    panel_bg = "black"

    [terminal]
    # Matches -c "#{pane_current_path}" on every split, window, and session
    new_cwd = "follow"

    [keys]
    prefix = "ctrl+space"

    # Config and help
    reload_config = "prefix+q"
    help = "prefix+?"
    detach = "prefix+d"

    # Copy mode
    copy_mode = "prefix+["

    # Panes
    split_horizontal = ["prefix+h", "alt+enter"]
    split_vertical = ["prefix+v", "alt+shift+enter"]
    close_pane = ["prefix+x", "alt+esc"]
    zoom = "prefix+z"
    last_pane = "prefix+;"

    focus_pane_left = "ctrl+alt+left"
    focus_pane_down = "ctrl+alt+down"
    focus_pane_up = "ctrl+alt+up"
    focus_pane_right = "ctrl+alt+right"

    resize_mode = ["prefix+ctrl+left", "prefix+ctrl+down", "prefix+ctrl+up", "prefix+ctrl+right"]

    # Like resize-pane on C-M-S-arrows
    resize_pane_left = "ctrl+alt+shift+left"
    resize_pane_down = "ctrl+alt+shift+down"
    resize_pane_up = "ctrl+alt+shift+up"
    resize_pane_right = "ctrl+alt+shift+right"

    # No tmux equivalent; herdr's default prefix+shift+p is taken by previous session
    rename_pane = "prefix+shift+o"

    # Windows -> tabs
    new_tab = "prefix+c"
    rename_tab = "prefix+r"
    close_tab = "prefix+k"
    switch_tab = ["prefix+1..9", "alt+1..9"]
    previous_tab = ["prefix+p", "alt+left"]
    next_tab = ["prefix+n", "alt+right"]

    # Like swap-window -t -1/+1 on M-S-Left/Right
    move_tab_previous = "alt+shift+left"
    move_tab_next = "alt+shift+right"

    # Sessions -> workspaces
    new_workspace = "prefix+shift+c"
    rename_workspace = "prefix+shift+r"
    close_workspace = "prefix+shift+k"
    previous_workspace = ["prefix+shift+p", "alt+up"]
    next_workspace = ["prefix+shift+n", "alt+down"]

    [ui]
    accent = "blue"

    # tmux drew single-line dividers between adjacent panes and no outer frame
    pane_gaps = false
    pane_outer_borders = false

    # tmux had no scrollbar column beside its panes
    pane_scrollbars = false

    # kill-window and kill-session never asked
    confirm_close = false

    # automatic-rename gave windows a name without prompting
    prompt_new_tab_name = false

    # set -g mouse on
    mouse_capture = true

    # status-right had the zoom flag followed by #h
    tab_bar_right = [{ type = "zoom" }, { type = "hostname" }]

    # set -g set-titles on / set -g set-titles-string '#h:#W', where tmux's #W was
    # the basename of the pane cwd. This is what Hyprland shows in the group bar,
    # and it resolves on the server so remote sessions name the remote host.
    window_title = "{hostname}: {workspace}"

    [ui.toast]
    delivery = "system"

    # Show which machine each agent is on. The default rows omit it, which is fine
    # with one machine and useless with several — the whole point of holding Local
    # and kodama in one window is knowing where a given agent is running.
    [ui.sidebar.agents]
    rows = [["state_icon", "machine", "workspace", "tab"], ["agent"]]
  '';
}

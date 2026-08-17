{pkgs, ...}: {
  # Desktop-flavoured personal config. The git identity itself lives in
  # identity-personal.nix so headless hosts (kodama) can reuse it alone.
  imports = [ ./identity-personal.nix ];

  home.packages = with pkgs; [
    # Markdown vault reader — used to browse the robotina workspace
    # (graph view, backlinks, Dataview over frontmatter).
    #
    # Deliberately here and NOT in home/shared/: shared is imported by the
    # work MacBook too, and the robotina vault holds health records and
    # personal financial analysis, so it never goes on work hardware.
    # Keeping the reader off that machine as well removes the temptation.
    #
    # On WSL this needs the nixGL + --no-sandbox wrapper defined in
    # wsl-pc.nix (Electron under WSLg), same pattern as alacritty.
    obsidian
  ];

  xdg.configFile."tmuxinator/home.yml".text = ''
    name: home

    windows:
      - main:
          layout: even-horizontal
          panes:
            - opencode
            -
      - scratch:
          root: ~/Code
          layout: even-horizontal
          panes:
            - opencode
            -
      - scratch2:
          root: ~
          layout: even-horizontal
          panes:
            - opencode
            -
  '';
}

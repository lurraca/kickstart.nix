{lib, ...}: {
  programs.git.settings.user = {
    email = lib.mkForce "me@lurraca.com";
    name = lib.mkForce "Luis Urraca";
  };

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

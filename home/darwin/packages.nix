{pkgs, ...}: {
  home.packages = with pkgs; [
    discord
    jetbrains.goland
    jetbrains-toolbox
    raycast
    slack
    zoom-us
  ];

  programs.alacritty = {
    enable = true;

    settings = {
      font = {
        normal = {
          family = "Hack Nerd Font Mono";
        };
        size = 15;
      };

      general.live_config_reload = true;

      selection.save_to_clipboard = true;

      terminal.shell = {
        program = "${pkgs.zsh}/bin/zsh";
      };

      window = {
        decorations = "buttonless";
        dimensions = {
          columns = 270;
          lines = 80;
        };
        opacity = 0.85;
        padding = {
          x = 25;
          y = 20;
        };
      };
    };
  };
}

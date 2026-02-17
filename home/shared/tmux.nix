{pkgs, ...}: {
  programs.tmux = {
    enable = true;
    tmuxinator.enable = true;
    historyLimit = 10000;
    mouse = true;
    shell = "${pkgs.zsh}/bin/zsh";

    extraConfig = ''
      unbind C-b
      set -g prefix C-a
      bind C-a send-prefix


      bind '"' split-window -h -c '#{pane_current_path}'
      bind % split-window -v -c '#{pane_current_path}'
    '';
  };
}

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

      # Vi copy mode
      setw -g mode-keys vi

      # WSL clipboard integration
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "/mnt/c/Windows/System32/clip.exe"
      bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "/mnt/c/Windows/System32/clip.exe"

      bind '"' split-window -h -c '#{pane_current_path}'
      bind % split-window -v -c '#{pane_current_path}'
    '';
  };
}

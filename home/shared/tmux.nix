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

      # Forward modified keys (Shift+Enter, Ctrl+Enter) through to the running
      # program. Off by default, and TUIs that want a newline-vs-submit
      # distinction silently lose it — `pi` warns about exactly this on startup.
      # Matters most from the phone, where the pi session is driven inside tmux
      # and Shift+Enter is the only way to get a newline without submitting.
      # tmux 3.2+; both boxes are on 3.7.
      set -g extended-keys on

    # OSC 52 clipboard integration (works with Alacritty)
    # Let tmux use OSC 52 escape sequences instead of piping to clip.exe
    # This avoids crashes when Alacritty handles the clipboard internally
    set -g set-clipboard on
    
    # Use 'y' to copy selection (tmux will use OSC 52)
    bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel
    bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-selection-and-cancel

      bind '"' split-window -h -c '#{pane_current_path}'
      bind % split-window -v -c '#{pane_current_path}'
    '';
  };
}

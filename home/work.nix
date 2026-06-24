{pkgs, ...}: {
  home.packages = with pkgs; [
    awscli2
    saml2aws
    ssm-session-manager-plugin
    stern
  ];

  programs.zsh = {
    initContent = ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
      eval "$(rbenv init - zsh)"
      source ~/Code/zendesk/kubectl_config/dotfiles/kubectl_stuff.bash
    '';

    shellAliases = {
      "be" = "bundle exec";
      "docker-machine" = "__docker_machine_wrapper";
      "drc" = ''darwin-rebuild check --flake "/etc/nix-darwin#X7X56XWY9W"'';
      "drs" = ''darwin-rebuild switch --flake "/etc/nix-darwin#X7X56XWY9W"'';
      "k" = "kubectl";
      "ka" = "kubectl --as admin --as-group system:masters --context";
      "kc" = "kubectl --context";
      "knife" = "be knife";
      "kz" = "kubectl --as admin --as-group edge-infra-admin --as-group system:authenticated --namespace zorg --context";
      "superclaude" = ''claude --dangerously-skip-permissions --model "global.anthropic.claude-opus-4-8[1m]"'';
    };
  };

  xdg.configFile."tmuxinator/work.yml".text = ''
    name: work

    windows:
      - work-brain:
          root: ~/Code/zendesk/work-brain
          layout: even-horizontal
          panes:
            - superclaude
            -
      - edge-state-manager:
          root: ~/Code/zendesk/edge-state-manager
          layout: even-horizontal
          panes:
            - superclaude
            -
      - scratch:
          root: ~/Code
          layout: even-horizontal
          panes:
            - superclaude
            -
      - ticket-duty:
          root: ~/Code/zendesk/ticket-duty-rotations
          layout: even-horizontal
          panes:
            - superclaude
            -
  '';
}

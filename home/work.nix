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
      "superclaude" = "claude --dangerously-skip-permissions --model global.anthropic.claude-opus-4-6-v1";
    };
  };

  xdg.configFile."tmuxinator/work.yml".text = ''
    name: work

    windows:
      - edge-state-manager:
          root: ~/Code/zendesk/edge-state-manager
          layout: even-horizontal
          panes:
            - superclaude
            -
      - zendesk-public-ips:
          root: ~/Code/zendesk/zendesk-public-ips
          layout: even-horizontal
          panes:
            - superclaude
            -
      - jaurvis:
          root: ~/Code/self/jaurvis
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
  '';
}

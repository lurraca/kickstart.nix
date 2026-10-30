# agent-root — let a coding agent run commands as root with explicit user
# approval via macOS's native admin-auth dialog (Touch ID works there).
#
# Why not plain sudo: agent exec contexts have no TTY, so sudo can never
# prompt, and Touch ID (pam_tid) only fires in interactive terminal sessions.
# `do shell script ... with administrator privileges` shows the standard
# SecurityAgent dialog instead — password OR fingerprint — and macOS caches
# the approval for ~5 minutes, so consecutive agent-root calls don't re-prompt.
#
# Usage:   agent-root <command> [args...]
# Deny:    press Cancel in the dialog -> exit 1, nothing runs.
#
# The command is passed via env var (AGENT_ROOT_CMD) + `system attribute`
# rather than string-interpolated into the AppleScript, so arbitrary
# quoting/args survive intact. stderr is merged into stdout so agents see
# the full output; failures propagate as non-zero exit codes.
{
  pkgs,
  ...
}: {
  home.packages = [
    (pkgs.writeShellScriptBin "agent-root" ''
      #!/usr/bin/env bash
      set -uo pipefail
      if [[ $# -eq 0 ]]; then
        echo "usage: agent-root <command> [args...]" >&2
        exit 2
      fi
      export AGENT_ROOT_CMD="$*"
      /usr/bin/osascript -e 'do shell script (system attribute "AGENT_ROOT_CMD") & " 2>&1" with administrator privileges with prompt "Coding agent requests root access:"'
    '')
  ];
}

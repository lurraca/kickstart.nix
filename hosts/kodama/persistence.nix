{ config, lib, pkgs, ... }:
let
  cfg = config.kodama.persist;

  # "Protected" has an exact mechanical test: is the path on the same
  # filesystem as /srv? A bind mount from /srv/foo reports /srv's device, so
  # comparing device numbers catches both real subdirectories and bind mounts
  # with no path parsing and no false negatives.
  stateReport = pkgs.writeShellApplication {
    name = "state-report";
    runtimeInputs = with pkgs; [ coreutils findutils util-linux ];
    text = ''
      # Reports service state that is NOT on /srv, i.e. state that a reinstall
      # would destroy. Silent when there is nothing to report — a weekly report
      # that always prints something is a report nobody reads.

      srv_dev=$(stat -c %d /srv)
      found=0
      out=""

      # ── 1. /var/lib/<service> ────────────────────────────────────────────
      # The default nobody chose. A NixOS module or container that was never
      # pointed at /srv writes here quietly.
      for d in /var/lib/*/; do
        [ -d "$d" ] || continue
        [ "$(stat -c %d "$d")" = "$srv_dev" ] && continue   # protected
        # Skip things that are genuinely disposable. dhcpcd/NetworkManager
        # hold DHCP leases, systemd/nixos hold state rebuilt on activation —
        # none of it survives a reinstall because none of it needs to.
        case "$d" in
          /var/lib/docker/|/var/lib/systemd/|/var/lib/nixos/|/var/lib/private/) continue ;;
          /var/lib/dhcpcd/|/var/lib/NetworkManager/|/var/lib/logrotate/|/var/lib/chrony/) continue ;;
          /var/lib/machines/|/var/lib/portables/|/var/lib/udisks2/) continue ;;
          /var/lib/lastlog/|/var/lib/systemd-*/) continue ;;
        esac
        # Ignore empty directories — a module that created a dir and wrote
        # nothing is not lost state.
        [ -z "$(ls -A "$d" 2>/dev/null)" ] && continue
        sz=$(du -sh "$d" 2>/dev/null | cut -f1)
        out="$out  $sz	$d"$'\n'
        found=1
      done

      # ── 2. Docker named volumes ──────────────────────────────────────────
      # These live inside /var/lib/docker/volumes and are invisible unless you
      # go looking. The most common way to lose container state.
      if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        vols=$(docker volume ls -q 2>/dev/null || true)
        if [ -n "$vols" ]; then
          out="$out"$'\n'"  Docker NAMED volumes (not bind mounts — inside /var/lib/docker):"$'\n'
          while IFS= read -r v; do
            [ -z "$v" ] && continue
            out="$out    $v"$'\n'
            found=1
          done <<< "$vols"
        fi

        # ── 3. Container bind mounts landing outside /srv and /data ────────
        # A path typo in a compose file silently writes to the root volume.
        stray=$(docker ps -q 2>/dev/null | while read -r c; do
          docker inspect --format \
            '{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}}{{"\n"}}{{end}}{{end}}' \
            "$c" 2>/dev/null
        done | grep -Ev '^(/srv|/data|/etc|/var/run|/run|/sys|/proc)' | sort -u || true)
        if [ -n "$stray" ]; then
          out="$out"$'\n'"  Container bind mounts outside /srv and /data:"$'\n'
          while IFS= read -r m; do
            [ -z "$m" ] && continue
            out="$out    $m"$'\n'
            found=1
          done <<< "$stray"
        fi
      fi

      # The timer runs this as root; a human may run it by hand as kasasagi.
      # Writing the report is best-effort so an unprivileged run still prints
      # rather than dying on a permission error.
      report=/var/lib/state-report.txt

      if [ "$found" -eq 1 ]; then
        # Redirect stderr for the whole block: when $report is unwritable the
        # SHELL emits the error, not the commands, so an inner 2>/dev/null
        # cannot catch it.
        {
          echo "UNPROTECTED STATE — lives outside /srv, a reinstall would destroy it:"
          echo ""
          printf '%s' "$out"
          echo ""
          echo "Fix: point the service at /srv/<name>, or add it to kodama.persist."
          echo "Reminder: /srv survives a deliberate reinstall. It is NOT a backup."
        } 2>/dev/null > "$report".tmp && mv "$report".tmp "$report" 2>/dev/null || true
        cat "$report" 2>/dev/null || {
          echo "UNPROTECTED STATE — lives outside /srv:"
          printf '%s' "$out"
        }
      else
        # Same ordering trap as above: redirections are applied left to
        # right, so 2>/dev/null must come BEFORE the failing > redirect.
        : 2>/dev/null > "$report" || true
        echo "All service state accounted for on /srv."
      fi
    '';
  };
in
{
  # ── The convention ──────────────────────────────────────────────────────
  #
  # /srv/<service>/ — one directory per service, and nothing else at the top
  # level. The value is not the structure; it is that "is this protected?"
  # becomes "is it under /srv?", which is answerable mechanically instead of
  # from memory.
  #
  # Compose stacks are easy: their bind mounts already point wherever you say,
  # so it is only discipline in the compose file.
  #
  # NixOS module services often hardcode /var/lib/<name>. Two ways to redirect,
  # in order of preference:
  #
  #   1. PREFERRED — if the module exposes its own dataDir-style option, use
  #      it. No mount involved, nothing to order at boot. Check per service.
  #   2. FALLBACK — bind-mount it, via kodama.persist below.

  options.kodama.persist = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "adguardhome" "grafana" ];
    description = ''
      Service names whose /var/lib/<name> should be bind-mounted from
      /srv/<name>, so their state survives an OS reinstall.

      Use only for services with no dataDir option of their own. The point of
      declaring it here rather than mounting by hand is that
      `grep persist hosts/kodama/` then answers "what is protected?" — the
      protection is reviewable in the config instead of being an invisible
      fact about the filesystem.
    '';
  };

  config = {
    # Tailscale's node state (node key, tailnet identity) lives in
    # /var/lib/tailscale and is NOT regenerable — losing it means re-authing
    # the machine. Found by the state report on kodama's first boot, which is
    # precisely what that report exists to do.
    kodama.persist = [ "tailscale" ];

    # Create the targets. Ownership is left to the service (`-` = don't touch),
    # because many services chown their own state directory on first start and
    # DynamicUser services get an unpredictable UID.
    systemd.tmpfiles.rules =
      [ "d /srv 0755 root root -" ]
      ++ map (n: "d /srv/${n} 0750 - - -") cfg;

    # ⚠️ `nofail` is deliberate. systemd-tmpfiles runs at sysinit.target, which
    # is AFTER local filesystems mount — so the very first boot after adding a
    # name here, /srv/<name> may not exist yet and the mount would fail. With
    # nofail that degrades to "not mounted" instead of a degraded boot, and the
    # next `nixos-rebuild switch` creates the directory and mounts it.
    #
    # To avoid the one-rebuild lag entirely: `mkdir /srv/<name>` on the box
    # before adding it to kodama.persist.
    fileSystems = lib.listToAttrs (map
      (n: lib.nameValuePair "/var/lib/${n}" {
        device = "/srv/${n}";
        # fsType "none" is required for bind mounts — without it the module
        # system errors with `fsType was accessed but has no value defined`.
        fsType = "none";
        options = [ "bind" "nofail" ];
        depends = [ "/srv" ];
      })
      cfg);

    # ── The discovery report ────────────────────────────────────────────────
    # Layers 1 and 2 above are still just remembering. This is what makes
    # forgetting visible: it finds state that accumulated somewhere nobody
    # chose, which is the actual failure mode.
    environment.systemPackages = [ stateReport ];

    systemd.services.state-report = {
      description = "Report service state living outside /srv";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe stateReport;
      };
    };

    systemd.timers.state-report = {
      description = "Weekly unprotected-state report";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true; # run on next boot if the box was off
        RandomizedDelaySec = "1h";
      };
    };

    # A report nobody reads is worthless, so surface it at login — but only
    # when there is something to say.
    programs.zsh.interactiveShellInit = lib.mkAfter ''
      if [[ -s /var/lib/state-report.txt ]]; then
        printf '\n\033[33m'; cat /var/lib/state-report.txt; printf '\033[0m\n'
      fi
    '';
  };
}

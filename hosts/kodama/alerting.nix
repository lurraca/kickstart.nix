# Alerting for kodama — the piece that tells Luis when something is wrong
# WITHOUT him looking.
#
# Monitoring has existed since 18 Aug (monitoring.nix): Prometheus, Grafana,
# Loki, Alloy. All of it answers questions you think to ask. None of it taps you
# on the shoulder.
#
# 🔴 The bug that justified this: on 31 Aug the Backrest `photos` plan was found
# to have NEVER run. It pointed at a path that does not exist inside the
# container, and a disabled schedule meant it never executed and so never
# errored. Thirteen days with no photo backup, and nothing said a word —
# because a plan that never runs never fails.
#
# 🎯 Hence the design rule throughout this file: ALERT ON SILENCE, not just on
# errors. Every rule that watches a metric has a partner rule that fires when
# the metric goes missing. Without that, a broken collector is indistinguishable
# from a healthy system, which is the exact failure being fixed.
{ config, pkgs, lib, ... }:

{
  # ── Backup freshness metric ─────────────────────────────────────────────
  # Asks the restic repository directly how old the newest snapshot is, per
  # plan, and writes it where node_exporter can pick it up.
  #
  # ⚠️ DELIBERATELY NOT Backrest's own /metrics endpoint (it has one, on :9898,
  # behind auth). Backrest reporting on Backrest cannot detect Backrest being
  # broken — and "the scheduler silently did nothing" is precisely the failure
  # mode here. Querying the repo tests the thing actually cared about: is there
  # a recent snapshot in R2? That answer stays correct even if Backrest is dead.
  #
  # Snapshots are tagged `plan:<id>` by Backrest, which is what groups them.
  systemd.services.backup-metrics = {
    description = "Write restic snapshot freshness metrics for node_exporter";

    # The repo URI, password and R2 credentials all live here. Root-only, 0600,
    # never in git — same pattern as the HA bearer token in monitoring.nix.
    # ⚠️ THIS REPO IS PUBLIC.
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = "/srv/secrets/restic-r2.env";
      # Writes into a directory node_exporter reads; nothing else needs root.
      User = "root";
    };

    # ⚠️ systemd units get an almost-empty PATH. Every binary the script calls
    # must be listed — awk being absent cost a deploy cycle.
    path = [ pkgs.restic pkgs.jq pkgs.coreutils pkgs.gawk ];

    script = ''
      set -uo pipefail
      dir=/var/lib/node-exporter/textfile
      mkdir -p "$dir"
      tmp="$dir/.backup.prom.$$"

      {
        echo "# HELP backup_last_snapshot_timestamp_seconds Unix time of the newest restic snapshot for a plan."
        echo "# TYPE backup_last_snapshot_timestamp_seconds gauge"
        echo "# HELP backup_query_success Whether the restic query itself succeeded (1) or failed (0)."
        echo "# TYPE backup_query_success gauge"
        echo "# HELP backup_metrics_written_timestamp_seconds Unix time this file was last written."
        echo "# TYPE backup_metrics_written_timestamp_seconds gauge"
      } > "$tmp"

      # One restic call — each one pays the full repository-open cost, and it is
      # billed as R2 Class B operations.
      if snapshots=$(restic snapshots --json 2>/dev/null); then
        ok=1
      else
        # Repo unreachable, credentials rejected, repo damaged. Emitting the
        # flag makes the condition VISIBLE rather than letting it masquerade as
        # a merely stale timestamp.
        ok=0
      fi

      if [ "$ok" = 1 ]; then
        # ⚠️ restic emits RFC3339 WITH A NUMERIC OFFSET, e.g.
        #   2026-09-01T02:00:02.131405548+01:00
        # jq's fromdateiso8601 accepts only a "Z" suffix and fails on offsets,
        # so parsing is handed to date(1), which understands both. An earlier
        # version did this in jq, silently produced no series at all, and left
        # a contradictory success flag behind. Measured, not assumed.
        printf '%s' "$snapshots" \
          | jq -r '.[] | select(.tags != null)
                   | (.tags[] | select(startswith("plan:"))) as $t
                   | "\($t | ltrimstr("plan:"))\t\(.time)"' \
          | while IFS="$(printf '\t')" read -r plan ts; do
              epoch=$(date -d "$ts" +%s 2>/dev/null) || continue
              printf '%s %s\n' "$plan" "$epoch"
            done \
          | awk '{ if ($2 > m[$1]) m[$1] = $2 }
                 END { for (p in m)
                         printf "backup_last_snapshot_timestamp_seconds{plan=\"%s\"} %d\n", p, m[p] }' \
          >> "$tmp"
      fi

      # Exactly once, whichever branch ran.
      echo "backup_query_success $ok" >> "$tmp"

      # Lets a FROZEN collector be told apart from a genuinely stale backup —
      # without this, a timer that dies leaves a correct-looking file behind and
      # the resulting alert would blame the backup.
      echo "backup_metrics_written_timestamp_seconds $(date +%s)" >> "$tmp"

      # Atomic rename: node_exporter must never read a half-written file.
      mv "$tmp" "$dir/backup.prom"
    '';
  };

  systemd.timers.backup-metrics = {
    description = "Refresh restic snapshot freshness metrics";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Hourly is ample for a 48h threshold, and each run opens the R2 repo —
      # which costs Class B operations. No reason to poll harder than the
      # question is asked.
      OnBootSec = "10m";
      OnUnitActiveSec = "1h";
      Persistent = true;
    };
  };

  # ── Alert rules ─────────────────────────────────────────────────────────
  services.prometheus.rules = [
    (builtins.toJSON {
      groups = [{
        name = "backups";
        rules = [
          {
            alert = "BackupStale";
            expr = ''time() - backup_last_snapshot_timestamp_seconds > 48 * 3600'';
            for = "30m";
            labels.severity = "critical";
            annotations = {
              summary = "Backup plan {{ $labels.plan }} is stale";
              description = "Newest snapshot for {{ $labels.plan }} is {{ $value | humanizeDuration }} old (threshold 48h).";
            };
          }
          {
            # 🔴 THE IMPORTANT ONE. Without this, a broken collector looks
            # exactly like a healthy system — silence. This is the rule that
            # would have caught the 31 Aug bug.
            alert = "BackupMetricMissing";
            expr = ''absent(backup_last_snapshot_timestamp_seconds)'';
            for = "2h";
            labels.severity = "critical";
            annotations = {
              summary = "Backup freshness metric has disappeared";
              description = "No backup_last_snapshot_timestamp_seconds series. The timer, node_exporter's textfile collector, or the restic query has broken — backups are UNVERIFIED, not necessarily failing.";
            };
          }
          {
            # Distinguishes "the collector froze" from "the backup is stale".
            # A dead timer leaves a valid-looking file on disk, so BackupStale
            # would fire and blame the wrong thing.
            alert = "BackupMetricsCollectorStale";
            expr = ''time() - backup_metrics_written_timestamp_seconds > 3 * 3600'';
            for = "30m";
            labels.severity = "warning";
            annotations = {
              summary = "Backup metrics collector has stopped updating";
              description = "backup-metrics.timer last wrote {{ $value | humanizeDuration }} ago (runs hourly). Backup state shown by other alerts may be stale.";
            };
          }
          {
            alert = "BackupQueryFailing";
            expr = ''backup_query_success == 0'';
            for = "2h";
            labels.severity = "warning";
            annotations = {
              summary = "Cannot query the restic repository";
              description = "restic snapshots is failing — R2 unreachable, credentials rejected, or the repo is damaged. Backup state is unknown.";
            };
          }
        ];
      }];
    })
  ];

  # ── Alertmanager ────────────────────────────────────────────────────────
  # Channel decided in monitoring.md §7: Alertmanager → HA webhook →
  # notify.mobile_app_*. Email via Zoho was considered and rejected — infra
  # email is the category people train themselves to ignore.
  services.prometheus.alertmanager = {
    enable = true;
    port = 9093;
    listenAddress = "127.0.0.1"; # Prometheus is local; nothing external needs it

    configuration = {
      route = {
        receiver = "ha";
        group_by = [ "alertname" "plan" ];
        group_wait = "30s";
        group_interval = "5m";
        # Deliberately long. A backup being stale is not more actionable when
        # repeated hourly; it is just training to ignore the phone.
        repeat_interval = "12h";
      };

      receivers = [{
        name = "ha";
        webhook_configs = [{
          # ⚠️ The webhook ID is a shared secret and THIS REPO IS PUBLIC, so the
          # URL lives in a file on the box. Same pattern as the HA bearer token.
          url_file = "/srv/secrets/alertmanager-ha-webhook";
          send_resolved = true;
        }];
      }];
    };
  };

  services.prometheus.alertmanagers = [{
    static_configs = [{ targets = [ "127.0.0.1:9093" ]; }];
  }];
}

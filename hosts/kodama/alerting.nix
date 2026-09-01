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

    path = [ pkgs.restic pkgs.jq pkgs.coreutils ];

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
      } > "$tmp"

      # A single restic call; grouped per plan tag in jq rather than one call
      # per plan, because each call pays the full repository-open cost.
      if snapshots=$(restic snapshots --json 2>/dev/null); then
        echo "backup_query_success 1" >> "$tmp"
        echo "$snapshots" | jq -r '
          map(select(.tags != null))
          | map(. as $s | ($s.tags[] | select(startswith("plan:"))) as $t
                | { plan: ($t | ltrimstr("plan:")), t: ($s.time | sub("\\.[0-9]+"; "") | fromdateiso8601) })
          | group_by(.plan)
          | map({ plan: .[0].plan, newest: (map(.t) | max) })
          | .[]
          | "backup_last_snapshot_timestamp_seconds{plan=\"\(.plan)\"} \(.newest)"
        ' >> "$tmp" || echo "backup_query_success 0" >> "$tmp"
      else
        # Repo unreachable, credentials wrong, R2 down. Emit the failure flag so
        # the condition is VISIBLE rather than showing up as a stale timestamp.
        echo "backup_query_success 0" >> "$tmp"
      fi

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

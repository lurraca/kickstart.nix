{ config, lib, pkgs, ... }:
# Metrics stack for kodama — node_exporter + Prometheus + Grafana.
#
# Decisions and their reasoning live in robotina at notes/homelab/monitoring.md.
# The short version of the ones that are easy to get wrong:
#
#   * NixOS modules, not Compose — these are stable software that changes on
#     its own slow schedule (homelab decision 10: place by rate of change).
#   * 30s scrape, NOT 15s. Home Assistant only refreshes the Tapo sensors
#     every 30-60s, so a faster scrape stores duplicate samples. Set at the
#     start on purpose: changing it later leaves a discontinuity in a series
#     we intend to keep for a year.
#   * 1 year retention, so this winter's electricity can be compared with
#     next. That comparison is the single most valuable thing retained here —
#     the household figures in notes/electricity.md come from summer months
#     only and are a floor, not an estimate.
#   * Loki and Alertmanager are deliberately NOT here yet. Logs matter once
#     something breaks; Alertmanager is blocked on the HA Companion app,
#     which is the chosen push channel.
{
  # ── node_exporter ───────────────────────────────────────────────────────
  # Bound to loopback. Prometheus scrapes it from this same host, so there is
  # no reason to expose host metrics to the network at all.
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
    enabledCollectors = [ "systemd" ];
  };

  # ── Prometheus ──────────────────────────────────────────────────────────
  services.prometheus = {
    enable = true;
    port = 9090;

    # ⚠️ "syntax-only", not the default full check. NixOS runs promtool over
    # the generated config at BUILD time, in a sandbox on the build machine —
    # which is kasasagi (WSL), not kodama. The full check verifies that
    # referenced files exist, so it fails on the bearer-token file that only
    # exists on the target box:
    #
    #   FAILED: error checking authorization credentials or bearer token file
    #   "/srv/secrets/ha-prometheus-token": no such file or directory
    #
    # syntax-only keeps the config validated without asserting build-host
    # filesystem state. Any config using a secrets file will hit this.
    checkConfig = "syntax-only";
    listenAddress = "127.0.0.1"; # Grafana is local; nothing else needs it
    retentionTime = "365d";

    globalConfig.scrape_interval = "30s";

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{ targets = [ "127.0.0.1:9100" ]; }];
      }
      {
        job_name = "pihole";
        static_configs = [{ targets = [ "127.0.0.1:9666" ]; }];
      }
      {
        # Home Assistant's built-in prometheus integration. This is what makes
        # the stack worth building rather than duplicating HA: every entity
        # becomes a metric — Tapo per-outlet power, electricity_unit_rate, the
        # cost sensors, kodama_host_*, the Govee sensor — with retention HA
        # does not offer (its recorder purges at 10 days).
        job_name = "home-assistant";
        metrics_path = "/api/prometheus";
        static_configs = [{ targets = [ "127.0.0.1:8123" ]; }];
        # ⚠️ /api/prometheus requires a bearer token, and THIS REPO IS PUBLIC.
        # The token lives in a file on the box, created out of band, never in
        # git. See notes/homelab/monitoring.md for how to regenerate it.
        authorization.credentials_file = "/srv/secrets/ha-prometheus-token";
      }
    ];
  };

  # ⚠️ Prometheus is the one service here that CANNOT be pointed at /srv
  # directly: services.prometheus.stateDir is documented as "directory below
  # /var/lib" and rejects an absolute path. So it takes the bind-mount
  # fallback instead. The name must match the default stateDir — "prometheus2",
  # not "prometheus". Getting that wrong leaves the TSDB on the disposable
  # root volume while looking entirely correct in review.
  kodama.persist = [ "prometheus2" ];

  # ── Grafana ─────────────────────────────────────────────────────────────
  # Unlike Prometheus, dataDir takes an absolute path, so it goes straight to
  # /srv with no bind mount — which persistence.nix says to prefer.
  services.grafana = {
    enable = true;
    dataDir = "/srv/grafana";

    settings = {
      server = {
        http_addr = "0.0.0.0"; # reachable over the tailnet; LAN stays closed
        http_port = 3000;
        domain = "kodama";
        root_url = "http://kodama:3000/";
      };
      # ⚠️ NixOS 26.05 removed Grafana's hard-coded default secret key, so it
      # must be set explicitly. It encrypts secrets stored in Grafana's DB
      # (datasource passwords, etc). THIS REPO IS PUBLIC, so it is read from a
      # file on the box using Grafana's own $__file{} provider rather than
      # written here. Generated once with `head -c 32 /dev/urandom | base64`.
      #
      # ⚠️ Rotating it later is genuinely awkward — Grafana has no official
      # rotation path — so do not regenerate this casually once secrets exist
      # in the database.
      security.secret_key = "$__file{/srv/secrets/grafana-secret-key}";

      # Single user on a private tailnet. No sign-ups, no anonymous access.
      "auth.anonymous".enabled = false;
      users.allow_sign_up = false;
      analytics.reporting_enabled = false;
    };

    # Datasource as code. A datasource clicked into the UI lives in Grafana's
    # SQLite DB, which is not in git — same reasoning as the HA dashboard.
    provision = {
      enable = true;
      # Dashboards provisioned from JSON in git (hosts/kodama/grafana/), not
      # clicked into the UI — a clicked dashboard lives only in Grafana's DB.
      dashboards.settings = {
        apiVersion = 1;
        providers = [{
          name = "kodama";
          options.path = "/etc/grafana-dashboards";
          options.foldersFromFilesStructure = false;
        }];
      };
      datasources.settings = {
        apiVersion = 1;
        # Delete-then-recreate handles the uid migration: Grafana treats a
        # datasource uid as immutable, so adding a uid to an already-provisioned
        # datasource fails with "data source not found". Deleting by name first
        # clears the old auto-uid copy. Idempotent, safe to leave in place.
        deleteDatasources = [
          { name = "Prometheus"; orgId = 1; }
          { name = "Loki"; orgId = 1; }
        ];
        datasources = [
          {
            name = "Prometheus";
            uid = "prometheus";   # stable UID so provisioned dashboards reference it
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:9090";
            isDefault = true;
          }
          {
            # Metrics and logs on the same time axis is the actual payoff:
            # when kodama's draw spikes at 03:00, you can read what was
            # logged at 03:00 without leaving the graph.
            name = "Loki";
            uid = "loki";
            type = "loki";
            access = "proxy";
            url = "http://127.0.0.1:3100";
          }
        ];
      };
    };
  };

  # Place the provisioned dashboard JSON where Grafana's provider reads it.
  environment.etc."grafana-dashboards/energy-health.json".source =
    ./grafana/energy-health.json;
  environment.etc."grafana-dashboards/pihole.json".source =
    ./grafana/pihole.json;
  environment.etc."grafana-dashboards/fitness.json".source =
    ./grafana/fitness.json;

  # ── Loki ────────────────────────────────────────────────────────────────
  # Single-node, filesystem-backed. No object store, no external database —
  # like Prometheus and Grafana, this is a directory to protect rather than a
  # service to dump.
  #
  # dataDir takes an ABSOLUTE path, so it goes straight to /srv with no bind
  # mount. Prometheus is the odd one out there, not this.
  services.loki = {
    enable = true;
    dataDir = "/srv/loki";

    configuration = {
      auth_enabled = false;

      server = {
        http_listen_address = "127.0.0.1"; # Grafana proxies; nothing external
        http_listen_port = 3100;
        grpc_listen_port = 9096;
        log_level = "warn"; # a log system that spams its own logs is a loop
      };

      common = {
        instance_addr = "127.0.0.1";
        path_prefix = "/srv/loki";
        replication_factor = 1;
        ring.kvstore.store = "inmemory";
        storage.filesystem = {
          chunks_directory = "/srv/loki/chunks";
          rules_directory = "/srv/loki/rules";
        };
      };

      schema_config.configs = [{
        from = "2026-01-01";
        store = "tsdb";
        object_store = "filesystem";
        schema = "v13";
        index = { prefix = "index_"; period = "24h"; };
      }];

      # 30 days, decided in notes/homelab/monitoring.md. Measured journal
      # volume is ~24 MB/day, so this lands near 0.7 GB — modest. The cap
      # exists for the case that actually bites: one service starting to spew.
      limits_config = {
        retention_period = "720h";
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
        volume_enabled = true;
      };

      # ⚠️ Retention does NOT happen without the compactor. `retention_period`
      # alone is silently ignored — the compactor is what enforces it.
      compactor = {
        working_directory = "/srv/loki/compactor";
        retention_enabled = true;
        delete_request_store = "filesystem";
      };

      analytics.reporting_enabled = false;
    };
  };

  # ── Alloy — the log shipper ─────────────────────────────────────────────
  # promtail is gone: it has been REMOVED from nixpkgs entirely, so Alloy is
  # not merely the recommended agent, it is the available one.
  #
  # 🎯 One source covers everything, because Home Assistant's container uses
  # the journald log driver. So HA, Docker, sshd, tailscaled and Prometheus
  # all arrive through the same journal with no per-service configuration.
  services.alloy.enable = true;

  environment.etc."alloy/config.alloy".text = ''
    // Lift the useful journald fields into Loki labels. Without this every
    // line arrives as one undifferentiated stream and is far less queryable.
    loki.relabel "journal" {
      forward_to = []

      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }
      rule {
        source_labels = ["__journal__hostname"]
        target_label  = "host"
      }
      rule {
        source_labels = ["__journal_priority_keyword"]
        target_label  = "level"
      }
      rule {
        source_labels = ["__journal_container_name"]
        target_label  = "container"
      }
    }

    loki.source.journal "read" {
      forward_to    = [loki.write.local.receiver]
      relabel_rules = loki.relabel.journal.rules
      labels        = { job = "systemd-journal" }
      max_age       = "12h"
    }

    loki.write "local" {
      endpoint {
        url = "http://127.0.0.1:3100/loki/api/v1/push"
      }
    }
  '';

  # ⚠️ Alloy cannot read the journal without this. The unit runs as its own
  # user, and journal access is granted by GROUP membership, not by file
  # permissions — so without it Alloy starts cleanly, reports no error, and
  # ships nothing. Silent failure, which is the worst kind.
  systemd.services.alloy.serviceConfig.SupplementaryGroups = [ "systemd-journal" ];

  # ⚠️ No firewall entries. Grafana on :3000 and Prometheus on :9090 stay
  # reachable over tailscale0 ONLY, which is already a trusted interface.
  # 8123 was opened to the LAN on 18 Aug because Cast devices must fetch
  # media from HA; nothing here has that requirement, so nothing here gets
  # exposed. Adding a port to the LAN should always need a reason.
}

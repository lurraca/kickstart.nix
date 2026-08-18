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
      datasources.settings = {
        apiVersion = 1;
        datasources = [{
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:9090";
          isDefault = true;
        }];
      };
    };
  };

  # ⚠️ No firewall entries. Grafana on :3000 and Prometheus on :9090 stay
  # reachable over tailscale0 ONLY, which is already a trusted interface.
  # 8123 was opened to the LAN on 18 Aug because Cast devices must fetch
  # media from HA; nothing here has that requirement, so nothing here gets
  # exposed. Adding a port to the LAN should always need a reason.
}

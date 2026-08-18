{ config, lib, pkgs, ... }:
# Homepage — the landing page for the homelab.
#
# Declarative like everything else here: the whole dashboard is Nix, so it is
# reviewable and reproducible rather than clicked together and lost on a
# reinstall. Same reasoning as the HA dashboard and the Grafana datasource.
{
  services.homepage-dashboard = {
    enable = true;

    # ⚠️ NOT 3000 — that is Grafana. Homepage's upstream default is 3000 and
    # would collide silently.
    listenPort = 8082;

    # ⚠️ Homepage REFUSES TO START without this. It is a host allow-list, not
    # a bind address, and the error is not obvious if you have not met it.
    allowedHosts = "kodama:8082,100.70.107.61:8082,localhost:8082,127.0.0.1:8082";

    # Widget API keys live here, NOT in this file — kickstart.nix is public.
    # Referenced below as {{HOMEPAGE_VAR_*}}. Same pattern as the Grafana
    # secret key and the Prometheus bearer token.
    environmentFile = "/srv/secrets/homepage.env";

    settings = {
      title = "kodama";
      theme = "dark";
      color = "slate";
      headerStyle = "clean";
      layout = [
        { "kodama" = { style = "row"; columns = 3; }; }
        { "Media & photos" = { style = "row"; columns = 2; }; }
        { "Infrastructure" = { style = "row"; columns = 4; }; }
      ];
    };

    widgets = [
      # kodama's own vitals. disk points at /srv because that is the volume
      # whose filling would actually cost something — root is disposable.
      {
        resources = {
          label = "kodama";
          cpu = true;
          memory = true;
          disk = "/srv";
        };
      }
      {
        datetime = {
          text_size = "l";
          format = { timeStyle = "short"; dateStyle = "short"; hourCycle = "h23"; };
        };
      }
    ];

    services = [
      {
        "kodama" = [
          {
            "Home Assistant" = {
              href = "http://kodama:8123";
              description = "Automation, energy, devices";
              icon = "home-assistant.png";
              siteMonitor = "http://127.0.0.1:8123";
              # 🎯 The reason this is a dashboard and not a bookmark folder:
              # live power and the current tariff band, on the landing page.
              widget = {
                type = "homeassistant";
                url = "http://127.0.0.1:8123";
                key = "{{HOMEPAGE_VAR_HA_TOKEN}}";
                custom = [
                  { state = "sensor.kodama_current_power"; label = "kodama W"; }
                  { state = "sensor.kasasagi_current_power"; label = "kasasagi W"; }
                  { state = "sensor.electricity_unit_rate"; label = "EUR/kWh"; }
                  { state = "sensor.electricity_tariff_band"; label = "band"; }
                ];
              };
            };
          }
          {
            "Backrest" = {
              href = "http://kodama:9898";
              description = "Encrypted /srv backups to Cloudflare R2";
              icon = "backrest.png";
              siteMonitor = "http://127.0.0.1:9898/";
            };
          }
          {
            "Grafana" = {
              href = "http://kodama:3000";
              description = "Metrics and logs, beyond 24h";
              icon = "grafana.png";
              siteMonitor = "http://127.0.0.1:3000/login";
            };
          }
          {
            "Pi-hole" = {
              href = "http://kodama:8081/admin/";
              description = "DNS ad-blocking + encrypted (DoH) upstream";
              icon = "pi-hole.png";
              siteMonitor = "http://127.0.0.1:8081/admin/";
            };
          }
          {
            "Prometheus" = {
              href = "http://kodama:9090";
              description = "TSDB — 30s scrape, 365d retention";
              icon = "prometheus.png";
              # Loopback-bound, so the link only works via an SSH tunnel.
              # Listed anyway: knowing it exists is most of the value.
              siteMonitor = "http://127.0.0.1:9090/-/healthy";
            };
          }
        ];
      }
      {
        "Media & photos" = [
          {
            "Immich" = {
              href = "http://100.84.11.47:2283";
              description = "Photos — still on the gaming PC";
              icon = "immich.png";
            };
          }
          {
            "Jellyfin" = {
              href = "http://kodama:8096";
              description = "Media — media over Tailscale from kasasagi";
              icon = "jellyfin.png";
              siteMonitor = "http://127.0.0.1:8096/health";
            };
          }
        ];
      }
      {
        "Infrastructure" = [
          {
            "AMT / vPro" = {
              href = "http://192.168.1.111:16992";
              description = "Out-of-band — works with kodama powered OFF";
              icon = "mdi-server-network";
            };
          }
          {
            "Tapo strip" = {
              href = "http://192.168.1.21";
              description = "Per-outlet energy monitoring";
              icon = "mdi-power-socket-eu";
            };
          }
          {
            "Router" = {
              href = "http://192.168.1.1";
              description = "Vodafone — DHCP reservations";
              icon = "mdi-router-wireless";
            };
          }
          {
            "Tailscale" = {
              href = "https://login.tailscale.com/admin/machines";
              description = "Tailnet — how you reach any of this";
              icon = "tailscale.png";
            };
          }
        ];
      }
    ];

    bookmarks = [
      {
        "Repos" = [
          { "kickstart.nix" = [{ href = "https://github.com/lurraca/kickstart.nix"; icon = "github.png"; }]; }
          { "homelab" = [{ href = "https://github.com/lurraca/homelab"; icon = "github.png"; }]; }
        ];
      }
    ];
  };

  # ⚠️ Tailnet-only, like Grafana. Nothing here is exposed to the LAN — 8123
  # is open only because Cast devices must fetch media from HA.
}

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
    # `environmentFiles` (plural) — `environmentFile` is deprecated upstream
    # and was throwing a build-time warning on every rebuild.
    environmentFiles = [ "/srv/secrets/homepage.env" ];

    settings = {
      title = "kodama";
      theme = "dark";
      # 🎯 Was "slate" on a slate-800 body — heading/card color and page
      # background were the same hue, so everything read as one flat gray
      # slab (this is what "the design is very bad" was). "sky" gives
      # headings, hover states and icons actual contrast against the body.
      color = "sky";
      headerStyle = "boxedWidgets";
      cardBlur = "md";
      fullWidth = true;
      layout = [
        # Energia leads the page — Luis wanted the tariff data more
        # prominent than a stat buried in the Home Assistant card. One
        # card, 3 rows (night/day/peak) — well under the 4-stat cap
        # Homepage's homeassistant widget silently enforces (found by
        # deploying 5 in one card and watching the 5th vanish from the DOM).
        { "Energia" = { style = "row"; columns = 1; }; }
        # kodama: HA link (plain) + main Prometheus card (CPU/RAM/power) +
        # disk free (3 volumes) + disk %used (3 volumes) — the local
        # resources widget was removed, so disk coverage moved here fully.
        { "kodama" = { style = "row"; columns = 4; }; }
        # kasasagi: same shape as kodama — main + GPU + disk, one card each
        # (the 4-mapping cap keeps forcing a split rather than one big card).
        { "kasasagi" = { style = "row"; columns = 3; }; }
        # The remaining 4 kodama services are uniform (icon + description
        # only), so a clean 2x2 grid with no ragged trailing row.
        { "Kodama services" = { style = "row"; columns = 2; }; }
        { "Media & photos" = { style = "row"; columns = 2; }; }
        { "Infrastructure" = { style = "row"; columns = 4; }; }
      ];
    };

    # No background image — an external URL is a dependency this box
    # shouldn't have (link rot, breaks the "works with no internet" story
    # everything else here follows). The glow is a pure-CSS gradient instead,
    # paired with cardBlur above so the glass effect actually has something
    # to blur.
    customCSS = ''
      html, body {
        background: radial-gradient(circle at 12% 8%, rgba(56, 189, 248, 0.12), transparent 42%),
                    radial-gradient(circle at 88% 92%, rgba(167, 139, 250, 0.12), transparent 45%),
                    linear-gradient(160deg, #0b1120 0%, #0f172a 55%, #0b1120 100%) !important;
        background-attachment: fixed !important;
      }

      /* Homepage paints an opaque theme-color fill on #__next, on top of
         body — it fully hides the gradient above unless overridden here. */
      #__next {
        background: transparent !important;
      }

      /* fullWidth removes Homepage's max-width cap but its own margin
         utilities (m-4/m-5 sm:m-8/m-9) never scale past the sm breakpoint,
         so content ran edge-to-edge on a wide desktop window. Pad the
         single outer container instead of chasing every inner margin
         class — everything (info widgets, groups, bookmarks) nests inside
         it, so one rule insets all of it at once. */
      @media (min-width: 1280px) {
        #__next {
          padding-left: 5rem !important;
          padding-right: 5rem !important;
        }
      }

      .service-card {
        border: 1px solid rgba(148, 163, 184, 0.14) !important;
        border-radius: 0.85rem !important;
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.25) !important;
        transition: transform 0.15s ease, border-color 0.15s ease, box-shadow 0.15s ease !important;
        height: 100%;
      }

      .service-card:hover {
        transform: translateY(-2px);
        border-color: rgba(56, 189, 248, 0.5) !important;
        box-shadow: 0 8px 28px rgba(56, 189, 248, 0.15) !important;
      }

      .service-group-name {
        position: relative;
        padding-left: 0.75rem;
        letter-spacing: 0.02em;
      }

      .service-group-name::before {
        content: "";
        position: absolute;
        left: 0;
        top: 0.15em;
        bottom: 0.15em;
        width: 3px;
        border-radius: 2px;
        background: linear-gradient(180deg, #38bdf8, #a78bfa);
      }

      .services-group {
        margin-bottom: 1.5rem;
      }

      /* Cards in the same row default to their own content height, so a
         plain description card sits shorter than a neighbour carrying
         widgets. Force the row to stretch every card to match. */
      .services-list {
        align-items: stretch;
      }

      /* Bookmarks ship as a full-width flex-col stack (bare text bars) with
         no card styling — the only element on the page that doesn't match
         the service-card look. Grid them the same way and reuse the same
         border/hover treatment. */
      .bookmark-list {
        display: grid !important;
        grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
        gap: 0.75rem;
      }

      .bookmark-list .bookmark > a {
        margin-bottom: 0 !important;
        border: 1px solid rgba(148, 163, 184, 0.14) !important;
        border-radius: 0.85rem !important;
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.25) !important;
        transition: transform 0.15s ease, border-color 0.15s ease, box-shadow 0.15s ease !important;
      }

      .bookmark-list .bookmark > a:hover {
        transform: translateY(-2px);
        border-color: rgba(56, 189, 248, 0.5) !important;
        box-shadow: 0 8px 28px rgba(56, 189, 248, 0.15) !important;
      }

      /* Tagged by customJS below on whichever Energia tariff row is
         currently active. Amber/gold — deliberately NOT the sky-blue
         accent used everywhere else, so it reads as "live/hot" rather
         than blending in as just another card. */
      .service-block.tariff-now {
        background: linear-gradient(135deg, rgba(250, 204, 21, 0.28), rgba(249, 115, 22, 0.18)) !important;
        box-shadow: 0 0 0 1px rgba(250, 204, 21, 0.55), 0 0 20px rgba(250, 204, 21, 0.35) !important;
      }

      .service-block.tariff-now .font-thin {
        color: #fde047 !important;
        font-weight: 700 !important;
      }
    '';

    # Homepage re-renders its HA custom stats on every refresh (the
    # tariff sensors update live), and there's no color/threshold support
    # for the homeassistant widget's `custom` stats and no data attribute
    # to hang a CSS rule off — checked gethomepage.dev/widgets/services/
    # homeassistant. So the current-band highlight is done here: find the
    # tariff stat tile whose value text is exactly "NOW" (set by the
    # tariff_{night,day,peak}_active sensors in electricity.yaml) and tag
    # it with a class the CSS above lights up. Re-runs on DOM mutation
    # (covers Homepage's periodic refetch) plus a 5s poll as a fallback.
    customJS = ''
      (function () {
        function highlightTariff() {
          document.querySelectorAll('.service-block').forEach(function (el) {
            var value = el.querySelector('.font-thin');
            var isNow = value && value.textContent.trim() === 'NOW';
            el.classList.toggle('tariff-now', !!isNow);
          });
        }
        highlightTariff();
        new MutationObserver(highlightTariff).observe(document.body, {
          childList: true,
          subtree: true,
          characterData: true,
        });
        setInterval(highlightTariff, 5000);
      })();
    '';

    widgets = [
      # 🅿️ The local `resources` widget (kodama's own CPU/RAM/disk, via
      # /proc) was removed at Luis's request — kodama's stats are now
      # fully consolidated into the Prometheus-sourced cards below instead
      # of split across two different mechanisms (local /proc here,
      # Prometheus there). See the "kodama" and "kodama Disk*" cards.
      {
        datetime = {
          text_size = "l";
          format = { timeStyle = "short"; dateStyle = "short"; hourCycle = "h23"; };
        };
      }
    ];

    services = [
      {
        "Energia" = [
          {
            "Electricity" = {
              href = "http://kodama:8123";
              description = "3-band tariff — current band highlighted live";
              icon = "mdi-transmission-tower";
              # One row per band, hours + price baked in as static label
              # text (the contract terms don't change hourly). Each row's
              # STATE is its own live NOW/— sensor from electricity.yaml,
              # so the current band highlights itself with no client JS.
              widget = {
                type = "homeassistant";
                url = "http://127.0.0.1:8123";
                key = "{{HOMEPAGE_VAR_HA_TOKEN}}";
                custom = [
                  { state = "sensor.tariff_night_active"; label = "night 23:00–08:00 · €0.2316"; }
                  { state = "sensor.tariff_day_active"; label = "day (other hours) · €0.4213"; }
                  { state = "sensor.tariff_peak_active"; label = "peak 17:00–19:00 · €0.4731"; }
                ];
              };
            };
          }
        ];
      }
      {
        "kodama" = [
          {
            "Home Assistant" = {
              href = "http://kodama:8123";
              description = "Automation, energy, devices";
              icon = "home-assistant.png";
              siteMonitor = "http://127.0.0.1:8123";
              # Plain link now — its power stats moved to the Prometheus
              # card alongside it (below), so both machines read from the
              # same source instead of splitting HA vs Prometheus by field.
            };
          }
          {
            "kodama (Prometheus)" = {
              href = "http://kodama:3000";
              description = "CPU / RAM / power — same source as kasasagi's card";
              icon = "mdi-server";
              # Same customapi pattern as kasasagi's card. Power comes from
              # HA's own Prometheus export (`hass_sensor_power_w`, entity
              # label) rather than the homeassistant widget — one source
              # for both machines instead of splitting host stats
              # (Prometheus) from power (HA) across two different widgets.
              # 2s refresh at Luis's request — cheap for kodama itself to
              # answer since node_exporter/HA are both local.
              widget = {
                type = "customapi";
                refreshInterval = 2000;
                url = "http://127.0.0.1:9090/api/v1/query?query=label_replace%28round%28100%20-%20%28avg%28rate%28node_cpu_seconds_total%7Bmode%3D%22idle%22%7D%5B1m%5D%29%29%20%2A%20100%29%2C%200.1%29%2C%20%22metric%22%2C%20%22cpu%22%2C%20%22%22%2C%20%22%22%29%20or%20label_replace%28round%28100%20%2A%20%281%20-%20node_memory_MemAvailable_bytes%20/%20node_memory_MemTotal_bytes%29%2C%200.1%29%2C%20%22metric%22%2C%20%22ram%22%2C%20%22%22%2C%20%22%22%29%20or%20label_replace%28hass_sensor_power_w%7Bentity%3D%22sensor.kodama_current_power%22%7D%2C%20%22metric%22%2C%20%22power%22%2C%20%22%22%2C%20%22%22%29";
                mappings = [
                  { field = "data.result.0.value.1"; label = "CPU"; format = "float"; suffix = " %"; }
                  { field = "data.result.1.value.1"; label = "RAM"; format = "float"; suffix = " %"; }
                  { field = "data.result.2.value.1"; label = "Power"; format = "float"; suffix = " W"; }
                ];
              };
            };
          }
          {
            "kodama Disk Free" = {
              href = "http://kodama:3000";
              description = "GiB free, all 3 volumes — replaces the top resources widget's disk tiles";
              icon = "mdi-harddisk";
              widget = {
                type = "customapi";
                refreshInterval = 2000;
                url = "http://127.0.0.1:9090/api/v1/query?query=label_replace%28round%28node_filesystem_avail_bytes%7Bmountpoint%3D%22/%22%7D%20/%201024%20/%201024%20/%201024%2C%200.1%29%2C%20%22metric%22%2C%20%22root%22%2C%20%22%22%2C%20%22%22%29%20or%20label_replace%28round%28node_filesystem_avail_bytes%7Bmountpoint%3D%22/srv%22%7D%20/%201024%20/%201024%20/%201024%2C%200.1%29%2C%20%22metric%22%2C%20%22srv%22%2C%20%22%22%2C%20%22%22%29%20or%20label_replace%28round%28node_filesystem_avail_bytes%7Bmountpoint%3D%22/data%22%7D%20/%201024%20/%201024%20/%201024%2C%200.1%29%2C%20%22metric%22%2C%20%22data%22%2C%20%22%22%2C%20%22%22%29";
                mappings = [
                  { field = "data.result.0.value.1"; label = "/ free"; format = "float"; suffix = " GiB"; }
                  { field = "data.result.1.value.1"; label = "srv free"; format = "float"; suffix = " GiB"; }
                  { field = "data.result.2.value.1"; label = "data free"; format = "float"; suffix = " GiB"; }
                ];
              };
            };
          }
          {
            "kodama Disk %" = {
              href = "http://kodama:3000";
              description = "% used, all 3 volumes — complements the GiB-free card next to it";
              icon = "mdi-harddisk";
              # Split from the Free card above rather than one 6-stat
              # card — the 4-mapping cap (customapi drops anything past
              # the 4th, same as the homeassistant widget).
              widget = {
                type = "customapi";
                refreshInterval = 2000;
                url = "http://127.0.0.1:9090/api/v1/query?query=label_replace%28round%28100%20%2A%20%281%20-%20node_filesystem_avail_bytes%7Bmountpoint%3D%22/%22%7D%20/%20node_filesystem_size_bytes%7Bmountpoint%3D%22/%22%7D%29%2C%200.1%29%2C%20%22metric%22%2C%20%22root%22%2C%20%22%22%2C%20%22%22%29%20or%20label_replace%28round%28100%20%2A%20%281%20-%20node_filesystem_avail_bytes%7Bmountpoint%3D%22/srv%22%7D%20/%20node_filesystem_size_bytes%7Bmountpoint%3D%22/srv%22%7D%29%2C%200.1%29%2C%20%22metric%22%2C%20%22srv%22%2C%20%22%22%2C%20%22%22%29%20or%20label_replace%28round%28100%20%2A%20%281%20-%20node_filesystem_avail_bytes%7Bmountpoint%3D%22/data%22%7D%20/%20node_filesystem_size_bytes%7Bmountpoint%3D%22/data%22%7D%29%2C%200.1%29%2C%20%22metric%22%2C%20%22data%22%2C%20%22%22%2C%20%22%22%29";
                mappings = [
                  { field = "data.result.0.value.1"; label = "/ used"; format = "float"; suffix = " %"; }
                  { field = "data.result.1.value.1"; label = "srv used"; format = "float"; suffix = " %"; }
                  { field = "data.result.2.value.1"; label = "data used"; format = "float"; suffix = " %"; }
                ];
              };
            };
          }
        ];
      }
      {
        "kasasagi" = [
          {
            "kasasagi (Prometheus)" = {
              href = "http://kodama:3000";
              description = "CPU / RAM / power — no HA source for host stats, read straight from Prometheus";
              icon = "mdi-desktop-tower-monitor";
              # No dedicated Prometheus-metrics widget exists in Homepage —
              # its built-in `prometheus` widget only reports target
              # up/down counts (checked gethomepage.dev/widgets/services/
              # prometheus/), not arbitrary PromQL values. customapi is the
              # generic fallback: hit Prometheus's own query API directly
              # and pick values out of the JSON by field path. Split into
              # this + the GPU and Disk cards below rather than one big
              # card — customapi silently drops any mapping past the 4th
              # too, same as the homeassistant widget (found by deploying
              # 5 here and watching Power vanish from the DOM). Power is
              # HA's own Prometheus export (`hass_sensor_power_w`), same
              # source as kodama's card, not the homeassistant widget.
              # 2s refresh at Luis's request.
              widget = {
                type = "customapi";
                refreshInterval = 2000;
                url = "http://127.0.0.1:9090/api/v1/query?query=label_replace%28round%28100%20-%20%28avg%28rate%28windows_cpu_time_total%7Binstance%3D%22192.168.1.13%3A9182%22%2Cmode%3D%22idle%22%7D%5B5m%5D%29%29%20%2A%20100%29%2C%200.1%29%2C%20%22metric%22%2C%20%22cpu%22%2C%20%22%22%2C%20%22%22%29%20or%20label_replace%28round%28100%20%2A%20%281%20-%20windows_memory_physical_free_bytes%7Binstance%3D%22192.168.1.13%3A9182%22%7D%20/%20windows_memory_physical_total_bytes%7Binstance%3D%22192.168.1.13%3A9182%22%7D%29%2C%200.1%29%2C%20%22metric%22%2C%20%22ram%22%2C%20%22%22%2C%20%22%22%29%20or%20label_replace%28hass_sensor_power_w%7Bentity%3D%22sensor.kasasagi_current_power%22%7D%2C%20%22metric%22%2C%20%22power%22%2C%20%22%22%2C%20%22%22%29";
                mappings = [
                  { field = "data.result.0.value.1"; label = "CPU"; format = "float"; suffix = " %"; }
                  { field = "data.result.1.value.1"; label = "RAM"; format = "float"; suffix = " %"; }
                  { field = "data.result.2.value.1"; label = "Power"; format = "float"; suffix = " W"; }
                ];
              };
            };
          }
          {
            "kasasagi GPU" = {
              href = "http://kodama:3000";
              description = "RTX 3070 — utilization + temp";
              icon = "mdi-expansion-card";
              widget = {
                type = "customapi";
                refreshInterval = 2000;
                url = "http://127.0.0.1:9090/api/v1/query?query=label_replace%28round%28nvidia_smi_utilization_gpu_ratio%7Binstance%3D%22192.168.1.13%3A9835%22%7D%20%2A%20100%2C%200.1%29%2C%20%22metric%22%2C%20%22gpu%22%2C%20%22%22%2C%20%22%22%29%20or%20label_replace%28round%28nvidia_smi_temperature_gpu%7Binstance%3D%22192.168.1.13%3A9835%22%7D%2C%200.1%29%2C%20%22metric%22%2C%20%22temp%22%2C%20%22%22%2C%20%22%22%29";
                mappings = [
                  { field = "data.result.0.value.1"; label = "GPU"; format = "float"; suffix = " %"; }
                  { field = "data.result.1.value.1"; label = "GPU temp"; format = "float"; suffix = " °C"; }
                ];
              };
            };
          }
          {
            "kasasagi Disk" = {
              href = "http://kodama:3000";
              description = "C: — the other two windows_exporter volumes are tiny system-reserved partitions, not worth showing";
              icon = "mdi-harddisk";
              widget = {
                type = "customapi";
                refreshInterval = 2000;
                url = "http://127.0.0.1:9090/api/v1/query?query=label_replace%28round%28windows_logical_disk_free_bytes%7Binstance%3D%22192.168.1.13%3A9182%22%2Cvolume%3D%22C%3A%22%7D%20/%201024%20/%201024%20/%201024%2C%200.1%29%2C%20%22metric%22%2C%20%22free%22%2C%20%22%22%2C%20%22%22%29%20or%20label_replace%28round%28100%20%2A%20%281%20-%20windows_logical_disk_free_bytes%7Binstance%3D%22192.168.1.13%3A9182%22%2Cvolume%3D%22C%3A%22%7D%20/%20windows_logical_disk_size_bytes%7Binstance%3D%22192.168.1.13%3A9182%22%2Cvolume%3D%22C%3A%22%7D%29%2C%200.1%29%2C%20%22metric%22%2C%20%22used%22%2C%20%22%22%2C%20%22%22%29";
                mappings = [
                  { field = "data.result.0.value.1"; label = "Free"; format = "float"; suffix = " GiB"; }
                  { field = "data.result.1.value.1"; label = "Used"; format = "float"; suffix = " %"; }
                ];
              };
            };
          }
        ];
      }
      {
        "Kodama services" = [
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
              # 🎯 No href, deliberately — the device's own local HTTP port
              # only answers a bare protocol handshake ("200 OK", no UI),
              # and Luis didn't want the HA-dashboard redirect either. Just
              # an info card now; siteMonitor still pings the device itself
              # for live up/down status.
              description = "Per-outlet energy monitoring";
              icon = "mdi-power-socket-eu";
              siteMonitor = "http://192.168.1.21";
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

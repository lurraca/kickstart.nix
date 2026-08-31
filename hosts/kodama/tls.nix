{ config, lib, pkgs, ... }:
# Internal TLS on a real domain, so Jellyfin can cast to the Chromecast.
#
# WHY THIS EXISTS. A Chromecast does not receive a stream from your phone — the
# phone hands it a URL and the Chromecast fetches the media itself. That
# receiver is a web app served over HTTPS, so a plain-http media URL is blocked
# as mixed content and a self-signed cert is rejected outright; there is no
# "proceed anyway" on a TV. So the requirement is exact: a hostname the
# Chromecast can resolve, serving a cert from a CA it already trusts.
#
# ⚠️ NOT Tailscale certs. `tailscale serve` would hand out a valid cert on
# kodama.<tailnet>.ts.net for free, and it cannot work here: Cast devices
# cannot run a VPN client, so the Chromecast will never be on the tailnet.
# Whatever we build has to work over plain LAN.
#
# 🔴 INERT UNTIL `enabled` IS FLIPPED. This file is imported and evaluated —
# so it is type-checked and cannot rot — but defines nothing until the
# Cloudflare API token exists on the box. Enabling it before then would leave
# nginx pointing at a certificate that was never issued, and a service that
# fails to start is how this box's last three outages began.
#
# To turn on:
#   1. Cloudflare -> My Profile -> API Tokens -> Create Token
#      Permissions: Zone / DNS / Edit    Zone Resources: Include / lurraca.com
#      ⚠️ A scoped token, NOT the Global API Key. The global key can do
#      anything to every zone on the account, including the one serving
#      lurraca.com publicly.
#   2. On kodama, as root:
#        install -m 0600 /dev/null /srv/secrets/acme-cloudflare.env
#        echo 'CF_DNS_API_TOKEN=<token>' > /srv/secrets/acme-cloudflare.env
#   3. Cloudflare DNS: A record  *.home  ->  192.168.1.111
#      🔴 DNS-only (GREY cloud), not proxied. Cloudflare cannot proxy a
#      private address, and player1.lurraca.com is proxied today, so orange
#      is this zone's default and will be wrong here.
#   4. Flip `enabled` below, rebuild, and CHECK THE STAGING CERT FIRST
#      (see `server` below).
let
  domain = "home.lurraca.com";

  # 🔴 nginx binds THIS ADDRESS ONLY, never 0.0.0.0. Tailscale already holds
  # :443 on the tailnet addresses:
  #     LISTEN 100.70.107.61:443
  #     LISTEN [fd7a:115c:a1e0::b34:6b3e]:443
  # A wildcard bind therefore fails with EADDRINUSE at boot. Binding the LAN
  # address also means the proxy is reachable only from the LAN, which is the
  # intent: nothing here should ever be exposed to the internet.
  lanIp = "192.168.1.111";

  enabled = false;
in
{
  config = lib.mkIf enabled {

    # ── Certificates ────────────────────────────────────────────────────────
    security.acme = {
      acceptTerms = true;
      defaults = {
        email = "me@lurraca.com";

        # 🎯 DNS-01, not HTTP-01. HTTP-01 needs Let's Encrypt to reach port 80
        # on this host FROM THE INTERNET, which means port-forwarding — exactly
        # what this design avoids. DNS-01 proves control by writing a TXT
        # record, so nothing is exposed and it works for a host whose A record
        # is a private address.
        dnsProvider = "cloudflare";

        # Only the path is in git. THIS REPO IS PUBLIC.
        #
        # ⚠️ `environmentFile`, NOT `credentialsFile` — the latter does not
        # exist and the error only appears at build time with the module
        # enabled, which is why this file was built once with `enabled = true`
        # before being committed inert. The file holds a single line:
        #     CF_DNS_API_TOKEN=<token>
        environmentFile = "/srv/secrets/acme-cloudflare.env";

        # Ask a public resolver directly for the ACME challenge check rather
        # than going through Pi-hole. Pi-hole is this box's own resolver, and a
        # cert renewal that depends on the DNS server it is renewing the cert
        # for is the same circular dependency that took the house offline on
        # 29 Aug. Break the loop deliberately.
        dnsResolver = "1.1.1.1:53";
      };

      certs.${domain} = {
        # One wildcard covers every service, now and later, so adding a vhost
        # never means issuing another cert.
        domain = "*.${domain}";
        extraDomainNames = [ domain ];
        group = "nginx";

        # ⚠️ UNCOMMENT FOR THE FIRST RUN. Let's Encrypt production allows five
        # duplicate certificates per week; a misconfigured DNS-01 loop burns
        # that in minutes and locks the domain out for seven days. Staging has
        # no meaningful limit and issues an untrusted cert, which is fine for
        # proving the plumbing. Switch to production only once staging issues
        # cleanly.
        # server = "https://acme-staging-v02.api.letsencrypt.org/directory";
      };
    };

    # 🔴 The ACME account key and every issued certificate live here. Without
    # this line a reinstall loses both — and the account key is not something
    # you can simply re-request. Found by the same reasoning that caught
    # /var/lib/bluetooth and /var/lib/tailscale.
    kodama.persist = [ "acme" ];

    # ── Reverse proxy ───────────────────────────────────────────────────────
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      defaultListenAddresses = [ lanIp ];

      virtualHosts."jellyfin.${domain}" = {
        useACMEHost = domain;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8096";

          # Jellyfin's web UI talks over a websocket for playback state and
          # live updates. Without this the page loads and looks correct, then
          # silently stops reflecting anything — a failure that reads as "the
          # app is buggy" rather than "the proxy is wrong".
          proxyWebsockets = true;

          extraConfig = ''
            # Do not buffer video through nginx. With buffering on, nginx tries
            # to read ahead into memory and temp files on a multi-GB stream.
            proxy_buffering off;

            # Jellyfin serves large files; the default 60s can cut long seeks.
            proxy_read_timeout 300s;
          '';
        };
      };
    };

    # nginx binds only lanIp above, so nothing is listening on the tailnet or
    # any other interface — opening these ports still exposes exactly one
    # address. Kept simple deliberately rather than per-interface, since the
    # bind address is doing the real scoping.
    #
    # 80 is here for the http -> https redirect that `forceSSL` generates, NOT
    # for ACME: DNS-01 never touches port 80. Without it, typing an http:// URL
    # hangs on a blocked port instead of redirecting, which reads as "the
    # server is down".
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    # ── Is the certificate still valid? ─────────────────────────────────────
    # 🎯 The whole point. ACME renews on a systemd timer at 30 days remaining
    # and needs no help — but when it FAILS it fails silently, and you find out
    # 30 days later when browsers start refusing the site. That is precisely
    # the shape of every outage this box has produced: fine until it isn't,
    # with no signal in between.
    services.prometheus.exporters.blackbox = {
      enable = true;
      port = 9115;
      listenAddress = "127.0.0.1";
      configFile = pkgs.writeText "blackbox.yml" ''
        modules:
          tls_connect:
            prober: tcp
            timeout: 5s
            tcp:
              tls: true
              tls_config:
                insecure_skip_verify: false
      '';
    };

    services.prometheus.scrapeConfigs = [
      {
        job_name = "blackbox-tls";
        metrics_path = "/probe";
        params.module = [ "tls_connect" ];
        static_configs = [{ targets = [ "jellyfin.${domain}:443" ]; }];
        # The blackbox pattern: the target goes in as a URL PARAMETER, and the
        # scrape itself is addressed to the exporter. Without this relabelling
        # Prometheus would try to scrape the target directly and get nothing.
        relabel_configs = [
          { source_labels = [ "__address__" ]; target_label = "__param_target"; }
          { source_labels = [ "__param_target" ]; target_label = "instance"; }
          { target_label = "__address__"; replacement = "127.0.0.1:9115"; }
        ];
      }
    ];

    # Registered here rather than in monitoring.nix so the panel appears only
    # when TLS is actually enabled. A dashboard that reads "No data" forever is
    # worse than no dashboard — the permanently-red pihole-ftl-setup unit is
    # exactly how the Jellyfin outage stayed invisible for three reboots.
    environment.etc."grafana-dashboards/tls.json".source = ./grafana/tls.json;
  };
}

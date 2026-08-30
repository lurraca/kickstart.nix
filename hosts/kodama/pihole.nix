{ config, lib, pkgs, ... }:
# Pi-hole (network-wide DNS ad-blocking) + cloudflared DoH proxy.
#
# Query path:
#   client ──▶ Pi-hole :53 (block + local DNS)  ──▶  https-dns-proxy :5053 ══DoH══▶ Cloudflare
#
# So Pi-hole does the blocking and https-dns-proxy encrypts the upstream hop — the
# ISP sees one encrypted connection to Cloudflare, never the queries.
#
# ROLLOUT (Luis's choice 18 Aug): tailnet-only for now. Point devices at Pi-hole
# by setting it as the tailnet global nameserver in the Tailscale admin
# (100.70.107.61), which covers phone + laptop at home AND away with no firewall
# opening. Switch the router's DHCP DNS later to cover the whole house.
{
  # ── Diagnostics ─────────────────────────────────────────────────────────
  # Deliberately minimal — both earned their place during the 29 Aug 2026 DNS
  # outage, where their absence measurably slowed the diagnosis:
  #   dnsutils — this box IS the DNS server and had no way to query DNS.
  #              `host` returns ambiguous output (grep "has address|not found"
  #              matches either outcome), which produced a wrong conclusion.
  #              Ended up hand-building DNS packets in bash instead of `dig`.
  #   tcpdump  — needed to settle whether outbound UDP 53 was actually blocked;
  #              without it that question was never answered definitively.
  # Anything rarer: `nix shell nixpkgs#<tool>`, which is how cryptsetup was
  # obtained on the night. See [[dns-incident-2026-08-29]].
  environment.systemPackages = with pkgs; [ dnsutils tcpdump ];

  # ── DoH proxy to Cloudflare ─────────────────────────────────────────────
  # https-dns-proxy: a purpose-built DoH forwarder with a NixOS module.
  #
  # ⚠️ We originally used `cloudflared proxy-dns` — Cloudflare REMOVED that
  # subcommand in cloudflared 2026.2.0 ("dns-proxy feature is no longer
  # supported"), so it fails to start on 2026.7.3. https-dns-proxy is the
  # maintained replacement and is cleaner anyway (module, not a hand-rolled unit).
  services.https-dns-proxy = {
    enable = true;
    address = "127.0.0.1";
    port = 5053;
    # ⚠️ NOT provider.kind = "cloudflare". That preset uses
    # `-r https://cloudflare-dns.com/dns-query`, so on boot the proxy must
    # resolve that hostname via its bootstrap resolvers BEFORE it can serve
    # anything. Pi-hole's only upstream is this proxy, so if that lookup fails
    # the box has no DNS at all and cannot recover — the proxy sits in
    # "Query received before bootstrapping is completed, discarding" forever.
    #
    # Observed for real on the 29 Aug 2026 reboot: whole-house DNS stayed down
    # ~45 min. Using the IP directly removes the bootstrap step entirely —
    # Cloudflare serves DoH on 1.1.1.1 with a valid cert, so there is no
    # hostname to look up and nothing to deadlock on.
    provider = {
      kind = "custom";
      ips = [ "1.1.1.1" "1.0.0.1" ];
      url = "https://1.1.1.1/dns-query";
    };
    preferIPv4 = true;
  };

  # ── Boot ordering: the proxy MUST NOT start before the network ──────────
  # The upstream unit is ordered `After=network.target`, which only means the
  # networking *stack* is loaded — not that eno2 has an address. https_dns_proxy
  # EXITS (status 1) if it cannot reach its resolver at startup, so on a cold
  # boot it burned through 6 restarts in ~1s, hit systemd's start limiter, and
  # was left `failed` permanently:
  #
  #   https-dns-proxy.service: Start request repeated too quickly.
  #   https-dns-proxy.service: Failed with result 'start-limit-hit'.
  #
  # Observed 29 Aug 2026. The knock-on is severe and non-obvious: no DoH means
  # Pi-hole has no upstream, which means kodama has no DNS (it resolves via
  # 127.0.0.1), which means tailscaled cannot resolve controlplane.tailscale.com
  # and never joins the tailnet — so the box is unreachable over Tailscale and,
  # if the tailnet global nameserver points here, the whole tailnet loses DNS.
  #
  # network-online.target waits for an actual address. The longer restart window
  # is belt-and-braces so a transient failure can never exhaust the limiter.
  systemd.services.https-dns-proxy = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      RestartSec = "5s";
      StartLimitBurst = 0;      # never give up permanently
    };
  };

  # ── kodama resolves via its own Pi-hole ─────────────────────────────────
  # Without this, kodama has no working DNS of its own:
  #   - accept-dns=true → Tailscale sends it to 100.100.100.100, which forwards
  #     to the tailnet global nameserver = kodama itself. Circular. It works
  #     while everything is already running, and DEADLOCKS on a cold boot
  #     because Pi-hole isn't serving yet (observed 29 Aug 2026, ~45 min outage).
  #   - accept-dns=false → falls back to the router at 192.168.1.1, which does
  #     not answer DNS at all, so nothing on kodama can resolve. Backrest's R2
  #     uploads, docker pulls and nix all fail silently.
  #
  # Pointing at localhost is the canonical NixOS pattern for a host that IS the
  # resolver — nixpkgs does exactly this in dnsmasq.nix (`networking.nameservers
  # = lib.optional cfg.resolveLocalQueries "127.0.0.1"`), dnscrypt-proxy and
  # bind. services.pihole-ftl has no resolveLocalQueries equivalent, so it must
  # be set by hand.
  #
  # No loop: Pi-hole's upstream is 127.0.0.1#5053, and https-dns-proxy targets
  # https://1.1.1.1/dns-query — an IP. Nothing needs a hostname resolved in
  # order to resolve hostnames.
  #
  # ⚠️ Keep `tailscale set --accept-dns=false` on kodama. It is a runtime pref,
  # NOT captured by this config, so a reinstall must set it again.
  networking.nameservers = [ "127.0.0.1" ];

  # ── Pi-hole FTL: DNS server + blocking ──────────────────────────────────
  services.pihole-ftl = {
    enable = true;

    # State (query DB, gravity blocklist DB, DHCP leases) is not cleanly
    # regenerable → bind-mounted from /srv via kodama.persist below.
    # configDirectory (/etc/pihole, the generated pihole.toml) is reproducible
    # from this Nix file, so it stays disposable.
    openFirewallDNS = false;        # tailnet reaches :53 via the trusted
    openFirewallWebserver = false;  # tailscale0 interface — no LAN opening

    settings = {
      dns = {
        # The ONLY upstream is the local DoH proxy, so every query is encrypted.
        upstreams = [ "127.0.0.1#5053" ];
        # ALL: accept queries arriving on any interface. The firewall is the
        # real boundary here (only localhost + tailnet can reach :53), so this
        # is not the open-resolver risk it would be on a LAN-exposed box.
        listeningMode = "ALL";
      };
    };

    # Starter blocklist. Requires the web UI enabled (asserted by the module),
    # which pihole-web provides below.
    lists = [
      {
        url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts";
        type = "block";
        enabled = true;
        description = "StevenBlack unified hosts";
      }
    ];
  };

  # ── Web dashboard ───────────────────────────────────────────────────────
  # Port 8081 (80 kept free; nothing else on 8081). Tailnet-only, like Grafana.
  services.pihole-web = {
    enable = true;
    ports = [ 8081 ];
  };

  # ── Admin password — kept OUT of this public repo ───────────────────────
  # pihole.toml would embed the password hash, and kickstart.nix is public. The
  # FTLCONF_* env vars override pihole.toml at runtime, so the password is
  # injected from a root-only secret instead. File: /srv/secrets/pihole.env
  #   FTLCONF_webserver_api_password=<plaintext; FTL hashes it on startup>
  systemd.services.pihole-ftl.serviceConfig.EnvironmentFile = "/srv/secrets/pihole.env";

  # ── Persistence ─────────────────────────────────────────────────────────
  # Bind-mount /var/lib/pihole from /srv/pihole (merges with the tailscale +
  # prometheus2 entries defined in the other host modules).
  kodama.persist = [ "pihole" ];
  # ── Pi-hole → Prometheus exporter ───────────────────────────────────────
  # bazmonk/pihole6_exporter — the v6-API exporter (the popular eko one is
  # still v5/setupVars-based). A self-contained Python script; packaged here
  # as a systemd service since it is not in nixpkgs. Exposes :9666, scraped
  # by Prometheus (job added in monitoring.nix).
  systemd.services.pihole6-exporter =
    let
      rawSrc = pkgs.fetchFromGitHub {
        owner = "bazmonk";
        repo = "pihole6_exporter";
        rev = "f7ab74b84a9f9163874e37b1f753420a1e61db75";
        hash = "sha256-XB5AlosD0UmIzo32nbGRxVUgRPHYClC65qjO9Xwynu4=";
      };
      # The exporter hardcodes https://<host>:443 for the Pi-hole API. Ours is
      # HTTP on :8081, so patch the base URL at build time. Covers both the
      # auth and query URLs (same substring).
      src = pkgs.runCommand "pihole6-exporter" { } ''
        mkdir -p $out
        cp ${rawSrc}/pihole6_exporter $out/pihole6_exporter
        substituteInPlace $out/pihole6_exporter \
          --replace-fail 'https://" + self.host + ":443' 'http://" + self.host + ":8081'
      '';
      py = pkgs.python3.withPackages (ps: with ps; [ requests urllib3 prometheus-client ]);
    in {
      description = "Pi-hole v6 Prometheus exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "pihole-ftl.service" ];
      # partOf, not just after: the exporter authenticates ONCE at startup
      # (self.sid = get_sid(key) in __init__) and has no re-auth/retry logic
      # in get_api_call. If pihole-ftl restarts for any reason, that cached
      # session goes stale and every /metrics scrape throws a bare KeyError
      # forever - the process itself never crashes, so Restart=on-failure
      # below never fires either. partOf propagates pihole-ftl's restarts to
      # this unit too, so it always re-authenticates on a fresh session.
      # Found 20 Aug via the Loki logs dashboard, after a `pihole-ftl`
      # restart during unrelated DNS troubleshooting silently broke this.
      partOf = [ "pihole-ftl.service" ];
      serviceConfig = {
        # -k takes the API key as an arg. Wrapped in bash so it comes from the
        # EnvironmentFile rather than being written into the Nix store. It is
        # still visible in `ps` to root on this single-user box — acceptable;
        # an app-password would be marginally cleaner.
        EnvironmentFile = "/srv/secrets/pihole-exporter.env";
        ExecStart = "${pkgs.bash}/bin/bash -c '${py}/bin/python ${src}/pihole6_exporter -H 127.0.0.1 -p 9666 -k \"$PIHOLE_KEY\"'";
        DynamicUser = true;
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
}

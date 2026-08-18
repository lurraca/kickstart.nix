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
    provider.kind = "cloudflare";   # DoH to Cloudflare (1.1.1.1 / 1.0.0.1)
    preferIPv4 = true;
  };

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
}

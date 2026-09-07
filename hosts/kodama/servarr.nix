{ config, lib, pkgs, ... }:
# Media acquisition — Sonarr, Radarr, Prowlarr, Bazarr, Seerr.
#
# All native NixOS services, not Docker. Checked nixpkgs directly rather than
# assuming: services.misc.servarr.* (Sonarr/Radarr/Prowlarr) and
# services.bazarr are real, maintained modules. Seerr (the project formerly
# named Jellyseerr — same thing, upstream renamed) also has a real module,
# services.seerr, initially missed because module-list.nix files it under
# "seerr" not "jellyseerr".
#
# Phase 2 — qBittorrent, VPN-confined via a WireGuard network namespace.
# Same structural guarantee as Gluetun's Docker network_mode:service: trick
# (confirmed against nixpkgs source + nixos/tests/wireguard/namespaces.nix
# before building this): qBittorrent has no route out except through the
# tunnel, so if the tunnel drops, it loses connectivity entirely rather than
# falling back to kodama's normal route.
#
# Private key from NordVPN's credential-exchange API
# (POST-free GET with an access-token-generated-in-the-dashboard Basic auth,
# https://api.nordvpn.com/v1/users/services/credentials — the access token
# itself was revoked right after this one-time exchange, per the "safest is
# neither expiry option, just revoke after use" call). Server picked from
# NordVPN's public recommendations API filtered to Dublin
# (filters[country_id]=104) rather than defaulting to UK — first attempt
# picked UK on a stale assumption before actually checking NordVPN even had
# Ireland servers (it has 94, in Dublin, obviously lower latency from kodama
# than crossing to Britain).
#
# v1 scope is western content only (Shows + Movies) — Luis's Jellyfin library
# splits Anime into separate folders/providers because Sonarr/Radarr don't
# have Jellyfin's anime-aware matching. A second Sonarr instance for anime is
# a real option, deliberately deferred rather than solved in the first pass.
{
  services.sonarr = {
    enable = true;
    dataDir = "/srv/sonarr";
    # ⚠️ Sonarr's module ONLY auto-creates dataDir at the exact default path
    # (/var/lib/sonarr/.config/NzbDrone, via StateDirectory) — Radarr,
    # Prowlarr and Bazarr's modules all auto-create a custom dataDir too, but
    # Sonarr's does not, checked in nixos/modules/services/misc/servarr/
    # sonarr.nix. Hence the manual tmpfiles rule below, absent for the other
    # three.
  };

  services.radarr = {
    enable = true;
    dataDir = "/srv/radarr";
  };

  services.prowlarr = {
    enable = true;
    dataDir = "/srv/prowlarr";
  };

  # FlareSolverr — a proxy Prowlarr hands Cloudflare-protected indexers off to
  # (e.g. 1337x) so it can solve the JS challenge and get a real response.
  # Real NixOS module (nixos/modules/services/misc/flaresolverr.nix), checked
  # directly rather than assuming Docker was required — same reasoning as
  # every other service in this file. Configured as an Indexer Proxy in
  # Prowlarr's UI (Settings > Indexer Proxies), not something declarable
  # from here — Prowlarr owns that config in its own database.
  services.flaresolverr.enable = true;

  # 🔴 Prowlarr ALSO uses DynamicUser (like Seerr) — but unlike Seerr, its
  # ExecStart hardcodes -data=/var/lib/prowlarr regardless of `dataDir`;
  # the only effect `dataDir` has is redirecting what physically backs
  # that path via a bind mount the module sets up itself when dataDir is
  # non-default. That part works. What doesn't: the module's own tmpfiles
  # rule for the custom dataDir creates it as `root:root 0700` — but the
  # DynamicUser process gets its own unpredictable transient UID, which a
  # root-only 0700 directory doesn't grant ANY access to, not even
  # traversal. Confirmed on disk: files inside were UID 65534 (the classic
  # NFS overflow "nobody", from some earlier transient allocation) while
  # the live process ran as UID 61654 — neither can get past the 0700
  # parent dir, hence "unable to open database file" despite the bind
  # mount and file ownership both looking superficially fine. Overriding
  # the module's own tmpfiles rule to 0777, same reasoning as every other
  # DynamicUser directory in this file: no single owner to chown to ahead
  # of time, since the UID isn't stable or known at build time.
  systemd.tmpfiles.settings."10-prowlarr"."/srv/prowlarr".d = lib.mkForce {
    user = "root";
    group = "root";
    mode = "0777";
  };

  services.bazarr = {
    enable = true;
    dataDir = "/srv/bazarr";
  };

  # 🔴 Seerr uses DynamicUser. First attempt used kodama.persist to bind-mount
  # /var/lib/seerr from /srv/seerr — deployed, and it broke: "Failed to set
  # up special execution directory in /var/lib: Device or resource busy".
  # The module's StateDirectory="seerr" directive ALSO wants to manage
  # /var/lib/seerr internally (its own private/public bind-mount dance for
  # DynamicUser), and my externally-created bind mount got there first,
  # colliding with it. No existing kodama.persist entry had hit this before
  # — tailscale/prometheus2/pihole are all fixed-user services, not
  # DynamicUser.
  #
  # Fix: don't touch /var/lib/seerr at all. Override configDir to an
  # unrelated /srv path instead — StateDirectory still runs (creates an
  # empty, unused /var/lib/seerr, harmless since CONFIG_DIRECTORY points
  # elsewhere) but nothing tries to manage the same mountpoint twice.
  # ProtectSystem=strict means the sandbox blocks writes anywhere not
  # explicitly granted, so ReadWritePaths has to be added by hand — the
  # module doesn't add one for a custom configDir.
  services.seerr = {
    enable = true;
    configDir = "/srv/seerr";
  };

  systemd.services.seerr.serviceConfig.ReadWritePaths = [ "/srv/seerr" ];

  systemd.tmpfiles.rules = [
    "d /srv/sonarr 0700 sonarr sonarr -"
    # World-writable: DynamicUser assigns a transient UID, not a fixed one,
    # so there's no single owner to chown this to ahead of time.
    "d /srv/seerr 0777 - - -"
    # 🎯 qBittorrent's download directory, and it MUST be on the same
    # filesystem as the library. Sonarr and Radarr both set
    # copyUsingHardlinks = true, but a hardlink cannot cross a filesystem
    # boundary — so when downloads lived on /data (the NVMe) and the library
    # on /data/media (the SATA drive), that setting silently degraded to a
    # full byte-for-byte copy on every import, and every seeding file existed
    # twice on disk. No error, just slow imports and double storage.
    #
    # Moved here 2026-08-30. It sits on lv-media alongside the library but
    # OUTSIDE every library root (/data/media/{Movies,TV Shows,Anime,...}),
    # so Jellyfin never scans it and imports are now instant metadata ops.
    #
    # Group `media` + setgid so Sonarr/Radarr (also in that group) can read
    # the completed files in order to link them.
    #
    # ⚠️ The original reasoning — stage on the fast local SSD rather than
    # torrent directly over the CIFS mount — is obsolete: the library is no
    # longer a network share, it is a local disk.
    "d /data/media/downloads 2775 qbittorrent media -"
  ];

  # NordVPN's own DNS, used ONLY inside the wg-vpn namespace (bind-mounted
  # over qbittorrent's /etc/resolv.conf below) — the namespace has no other
  # interface and so no other way to resolve tracker hostnames.
  # 🔴 First attempt wrote this via a tmpfiles `f` line with an embedded
  # `\n` — only the first nameserver line actually landed on disk, the
  # tmpfiles escape didn't do what I expected. environment.etc handles a
  # real multi-line string natively, no escaping ambiguity.
  environment.etc."netns/wg-vpn/resolv.conf".text = ''
    nameserver 103.86.96.100
    nameserver 103.86.99.100
  '';

  # 🔴 Network-namespace confinement isolates MORE than just the torrent
  # traffic — it isolates qBittorrent's WebUI listening socket too, which
  # legitimately does need to be reachable from the host (Sonarr/Radarr's
  # download-client connection, and Luis checking the UI). Found by testing
  # reachability after deploy, not by reading anything — curling
  # 127.0.0.1:8080 from the host got connection-refused, because the host's
  # loopback and the namespace's loopback are two entirely separate network
  # stacks. Fix: a private veth pair between the host and the namespace,
  # used ONLY for this local WebUI hop — no default route is added via it
  # inside the namespace, so it doesn't give qBittorrent's general traffic
  # an escape route around the tunnel. The WireGuard peer's
  # allowedIPs = 0.0.0.0/0 stays the only default route inside wg-vpn.
  #
  # This also now owns namespace CREATION (moved out of the wireguard
  # interface's own preSetup) — one idempotent creation point instead of
  # two, now that something else needs to run against the namespace before
  # the WireGuard interface does.
  systemd.services.wg-vpn-netns-setup = {
    description = "Create the wg-vpn network namespace and its host-facing veth link";
    before = [ "wireguard-wg-vpn.service" ];
    wantedBy = [ "wireguard-wg-vpn.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.iproute2 ];
    script = ''
      ip netns list | grep -q "^wg-vpn" || ip netns add wg-vpn

      # veth pair: idempotent the same way — `ip link add` errors if the
      # host-side end already exists, same lesson as the netns check above.
      if ! ip link show veth-host >/dev/null 2>&1; then
        ip link add veth-host type veth peer name veth-wg
        ip link set veth-wg netns wg-vpn
        ip addr add 10.200.200.1/24 dev veth-host
        ip netns exec wg-vpn ip addr add 10.200.200.2/24 dev veth-wg
        ip netns exec wg-vpn ip link set lo up
      fi
      ip link set veth-host up
      ip netns exec wg-vpn ip link set veth-wg up
    '';
    postStop = ''
      ${pkgs.iproute2}/bin/ip link del veth-host 2>/dev/null || true
    '';
  };

  # Created via preSetup (idempotent — plain `ip netns add` errors on a
  # namespace that already exists, which preSetup would hit on every service
  # restart otherwise) rather than the interface's own module logic, which
  # only MOVES an interface into a namespace, it doesn't create one —
  # confirmed in nixos/modules/services/networking/wireguard.nix, both
  # socketNamespace and interfaceNamespace are documented as "pre-existing".
  #
  # 🔴 First version checked `ip netns list | grep -qx wg-vpn` for
  # idempotency — broke on the very first restart. `ip netns list` prints
  # "wg-vpn (id: 0)", not bare "wg-vpn", so the exact-match grep never
  # matched and it tried to re-create an already-existing namespace every
  # time, failing with "File exists".
  networking.wireguard.interfaces.wg-vpn = {
    ips = [ "10.5.0.2/32" ]; # NordVPN's fixed internal WireGuard client address — the same for every account, not derived from anything account-specific.
    privateKeyFile = "/srv/secrets/wireguard-nordvpn";
    interfaceNamespace = "wg-vpn";
    peers = [
      {
        # ie117.nordvpn.com, Dublin, 7% load at pick time (of 3 candidates
        # checked — recommendations API sorts by load already).
        publicKey = "WwpRem21dqdXwZF3qDqTe3rOxOBTPZIem8de5R17sCc=";
        endpoint = "217.138.222.235:51820";
        allowedIPs = [ "0.0.0.0/0" "::/0" ];
      }
    ];
  };

  services.qbittorrent = {
    enable = true;
    user = "qbittorrent";
    group = "qbittorrent";
    profileDir = "/srv/qbittorrent";
    webuiPort = 8080;
    serverConfig = {
      # Same filesystem as the library, so *arr imports hardlink. See the
      # tmpfiles rule above for why this matters.
      Preferences.Downloads.SavePath = "/data/media/downloads";
      # Binds on every interface inside the namespace, so it's reachable on
      # both the namespace's own loopback AND the veth-wg address
      # (10.200.200.2) — which is how the host (and Sonarr/Radarr) actually
      # reach it, per the veth setup above.
      Preferences.WebUI.Address = "*";

      # 🔴 Skip WebUI auth for the host end of the veth pair.
      #
      # Why this exists: qBittorrent had NO password set, so on every start it
      # generated a random temporary one and logged it. This file is installed
      # over /srv/qbittorrent/.../qBittorrent.conf by ExecStartPre on EVERY
      # start, so a password set through the WebUI is wiped on the next
      # restart. Sonarr's stored credentials went stale on 4 Sep 2026 when
      # qbittorrent last restarted, and every download silently stopped with
      # `downloadClientUnavailable` until 7 Sep.
      #
      # LocalHostAuth is NOT the fix: the WebUI is reached through
      # `qbittorrent-webui-proxy` (socat 8080 -> 10.200.200.2:8080), so
      # qBittorrent sees the connection arriving from the host end of the
      # veth, 10.200.200.1 — never from 127.0.0.1.
      #
      # /32, not the /24: the only legitimate client is the socat hop. The
      # WebUI is not otherwise reachable — it binds inside the namespace and
      # the host port is the only door.
      Preferences.WebUI.AuthSubnetWhitelistEnabled = true;
      Preferences.WebUI.AuthSubnetWhitelist = "10.200.200.1/32";
    };
  };

  systemd.services.qbittorrent = {
    # 🔴 Do not start before the media volume is mounted. Without this, a
    # failed LUKS unlock would leave /data/media as a bare directory on the
    # NVMe, tmpfiles would happily create downloads/ inside it, and torrents
    # would land on the wrong disk — invisibly, until the mount came back and
    # shadowed them.
    unitConfig.RequiresMountsFor = "/data/media";

    # Both directions of the killswitch: after/bindsTo means qbittorrent
    # won't start before the tunnel is up, AND stops automatically if the
    # tunnel service stops for any reason — belt-and-suspenders on top of
    # the network-namespace isolation itself, which is what actually
    # prevents a traffic leak if the interface dies without the service
    # noticing.
    after = [ "wireguard-wg-vpn.service" ];
    bindsTo = [ "wireguard-wg-vpn.service" ];
    serviceConfig = {
      NetworkNamespacePath = "/run/netns/wg-vpn";
      # NetworkNamespacePath joins the network namespace only, not the
      # mount namespace — the /etc/netns/<name> auto-substitution `ip netns
      # exec` normally provides doesn't apply here, so resolv.conf has to be
      # bind-mounted onto this unit directly instead.
      BindReadOnlyPaths = [ "/etc/netns/wg-vpn/resolv.conf:/etc/resolv.conf" ];
    };
  };

  # 🔴 The veth address (10.200.200.2) is only reachable from kodama's own
  # host network stack — Luis found this out by trying the Homepage
  # qBittorrent card from kasasagi and getting nothing, since that address
  # isn't routable from any other tailnet device. Every other servarr app
  # is reached as kodama:<port> over Tailscale; this plain TCP forward
  # (host 0.0.0.0:8080 -> the veth address) gives qBittorrent's WebUI the
  # same reachability without punching a hole in the VPN confinement
  # itself — the forward runs on the host, outside the namespace, and
  # connects out to 10.200.200.2 exactly the way Sonarr/Radarr's
  # download-client connections already do.
  systemd.services.qbittorrent-webui-proxy = {
    description = "Forward host:8080 to qBittorrent's WebUI inside the wg-vpn netns";
    after = [ "qbittorrent.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:8080,fork,reuseaddr TCP:10.200.200.2:8080";
      Restart = "always";
    };
  };

  # openFirewall left false (the default) on every service above —
  # trustedInterfaces = [ "tailscale0" ] in configuration.nix already makes
  # them reachable over the tailnet with no explicit firewall opening,
  # same pattern as Prometheus/Grafana/Pi-hole.
}

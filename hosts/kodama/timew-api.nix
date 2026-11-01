# timew-api: timewarrior over HTTP (a JSON API plus a web page), reachable from
# any browser through a Cloudflare Tunnel with Cloudflare Access in front.
# Code: github.com/lurraca/timew-api.
#
# Nothing identifying is in this file, because this repo is PUBLIC. The
# hostname and the Access policy live in the Cloudflare dashboard; the values
# the service needs live in /srv/secrets, which is not in git:
#
#   /srv/secrets/timew-api.env         (0600 root:root; systemd reads it as root)
#     TIMEW_API_CF_TEAM_DOMAIN=<team>.cloudflareaccess.com
#     TIMEW_API_CF_AUD=<Access application AUD tag>
#     TIMEW_API_PROJECT=<label for the weekly report>
#
#   /srv/secrets/cloudflared-kodama.token   (0600 root:root)
#     the tunnel token from Zero Trust → Networks → Tunnels → kodama
#
# The tunnel's public hostname points at http://localhost:8097. It is a
# separate tunnel from splice's: that one runs inside splice's Compose stack
# on an isolated network and can only reach splice.
#
# The database is in /srv/timew, so the nightly restic run to R2 covers it.
{ inputs, pkgs, ... }:
{
  imports = [ inputs.timew-api.nixosModules.default ];

  services.timew-api = {
    enable = true;
    port = 8097;
    dataDir = "/srv/timew";
    environmentFile = "/srv/secrets/timew-api.env";
  };

  # Cloudflare Tunnel for services that run on the host rather than in Compose.
  # The token is read through a systemd credential, so the unit needs no access
  # to /srv/secrets itself, and runs as a throwaway user.
  systemd.services.cloudflared-kodama = {
    description = "Cloudflare Tunnel for kodama host services";
    after = [ "network-online.target" "timew-api.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token-file %d/token";
      LoadCredential = "token:/srv/secrets/cloudflared-kodama.token";
      DynamicUser = true;
      Restart = "on-failure";
      RestartSec = 10;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
      CapabilityBoundingSet = "";
      LockPersonality = true;
      SystemCallArchitectures = "native";
    };
  };
}

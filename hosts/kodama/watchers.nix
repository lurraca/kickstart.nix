# Generic RSS keyword watcher → ntfy push.
#
# Polls an Atom/RSS feed, matches entry titles against a regex, and pushes
# anything new to an ntfy topic. One alert per entry, ever.
#
# 🔴 WHAT IT WATCHES IS NOT IN THIS FILE, AND MUST NOT BE.
# This repo is PUBLIC. The feed URL, the match pattern and the ntfy topic all
# live in /srv/secrets/feed-watch.env, which is not in git:
#
#   FEED=https://example.com/feed.rss
#   PATTERN='alpha|beta'
#   NTFY=https://ntfy.sh/<topic>
#
# Two separate reasons, both real:
#   1. The pattern says what this box is interested in. That is nobody's
#      business but Luis's, and a public repo is a permanent record.
#   2. 🔑 The ntfy topic IS a bearer credential in URL form — ntfy has no
#      auth on a public topic, so anyone who reads the topic name can both
#      subscribe to every alert and publish fake ones. Same rule already
#      applied to the Alertmanager and Seerr webhook IDs.
#
# Changing what is watched is now an edit to the env file plus a service
# restart — no rebuild, and nothing to leak.
#
# State is a dedupe log of seen entry IDs; losing it costs one duplicate
# alert, so it lives in StateDirectory rather than /srv.
{ pkgs, ... }:
{
  systemd.services.feed-watch = {
    description = "RSS keyword watch → ntfy";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.curl pkgs.gnugrep pkgs.gnused pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "feed-watch";
      # Fails the unit if absent, which is what we want: a watcher running
      # with no pattern would silently alert on nothing.
      EnvironmentFile = "/srv/secrets/feed-watch.env";
      ExecStart = pkgs.writeShellScript "feed-watch" ''
        set -u
        UA="kodama-feed-watch/1.0 (homelab)"

        : "''${FEED:?FEED not set in /srv/secrets/feed-watch.env}"
        : "''${PATTERN:?PATTERN not set in /srv/secrets/feed-watch.env}"
        : "''${NTFY:?NTFY not set in /srv/secrets/feed-watch.env}"

        feed=$(curl -s --max-time 30 -A "$UA" "$FEED") || { echo "feed fetch failed"; exit 0; }
        [ -z "$feed" ] && exit 0

        echo "$feed" | tr '\n' ' ' | sed 's/<entry>/\n<entry>/g' | while IFS= read -r entry; do
          case "$entry" in "<entry>"*) ;; *) continue ;; esac
          title=$(printf '%s' "$entry" | sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p')
          [ -z "$title" ] && continue
          link=$(printf '%s' "$entry" | grep -oE '<link[^>]*href="[^"]*"' | head -1 | sed 's/.*href="//;s/"$//')
          printf '%s' "$title" | grep -qiE "$PATTERN" || continue
          id=$(printf '%s' "$link" | md5sum | cut -d' ' -f1)
          if [ -f "$STATE_DIRECTORY/seen" ] && grep -qxF "$id" "$STATE_DIRECTORY/seen"; then continue; fi
          echo "$id" >> "$STATE_DIRECTORY/seen"
          msg=$(printf '%s' "$title" | sed -e 's/&amp;/\&/g' -e 's/&quot;/"/g')
          curl -s --max-time 15 \
            -H "Title: Feed watch" -H "Tags: satellite" -H "Priority: high" \
            -d "$msg
$link" "$NTFY" >/dev/null
          echo "alerted: $msg"
        done

        # Keep the dedupe log bounded.
        if [ -f "$STATE_DIRECTORY/seen" ]; then
          tail -n 500 "$STATE_DIRECTORY/seen" > "$STATE_DIRECTORY/seen.tmp" \
            && mv "$STATE_DIRECTORY/seen.tmp" "$STATE_DIRECTORY/seen"
        fi
      '';
    };
  };

  systemd.timers.feed-watch = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      RandomizedDelaySec = "2h";
      Persistent = true; # a missed run (reboot) fires on next boot
    };
  };
}

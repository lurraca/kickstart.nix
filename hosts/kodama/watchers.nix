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

  # ── UCD JLPT registration watch ──────────────────────────────────────────
  #
  # Exam is Sun 6 Dec 2026. UCD registration "historically opens ~August and
  # fills fast", and as of 7 Sep nothing had been announced — no email, and the
  # page still showing its dormant holding text. Missing the window costs the
  # July 2027 sitting, 44 weeks later.
  #
  # 🔴 WHY THIS SCOPES TO ONE COMPONENT, AND DOES NOT HASH THE PAGE.
  # A previous version of this (a Cloudflare Worker) hashed the whole page and
  # produced constant false positives. Cause, confirmed 7 Sep: ucd.ie's CMS
  # emits sequential nav ids site-wide —
  #     id="explore-collapse-627629" … 627633
  # — which increment when ANY page on ucd.ie is republished. So every unrelated
  # UCD edit fired the alert.
  #
  # The CMS wraps real content in component comments, and on this page component
  # 18 is the ONLY content component (~220 chars). Hash that and the churn is
  # gone, because the nav is not in it.
  #
  # 🎯 Two signals, deliberately different strengths:
  #   HIGH — a <form> or a book/apply/register link appears inside component 18.
  #          That is registration actually opening: a positive assertion, which
  #          survives wording changes and says WHAT happened.
  #   LOW  — component 18's text merely changed. Worth a look, not an emergency.
  #
  # ⏱️ Every 15 min, 07:00-21:45. Sixty requests/day to a public page is less
  # than one visitor. No overnight polling: UCD publishes in office hours and
  # nobody can act at 3am.
  #
  # ⬜ TURN THIS OFF once registered, or after 6 Dec 2026. A watcher for an event
  # that has passed is pure noise, and noise is what hides the next real alert.
  systemd.services.jlpt-watch = {
    description = "Watch UCD JLPT booking page for registration opening";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.curl pkgs.gnugrep pkgs.gnused pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "jlpt-watch";
      # Only NTFY is read from here; the URL below is not a secret.
      EnvironmentFile = "/srv/secrets/feed-watch.env";
      ExecStart = pkgs.writeShellScript "jlpt-watch" ''
        set -u
        URL="https://www.ucd.ie/japan/exams/bookajlptexamination/"
        UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"
        : "''${NTFY:?NTFY not set in /srv/secrets/feed-watch.env}"

        page=$(curl -s --max-time 30 -A "$UA" "$URL") || { echo "fetch failed"; exit 0; }
        [ -z "$page" ] && { echo "empty response"; exit 0; }

        # Component 18 only — see the note above about nav ids.
        comp=$(printf "%s" "$page" | tr "\n" " " \
          | sed -n "s|.*ucdcanc-InsidePanelFullWidth - component 18 -->\(.*\)<!--/ucdcanc-InsidePanelFullWidth.*|\1|p")
        if [ -z "$comp" ]; then
          # The component vanished or was renamed — that is itself a change worth
          # knowing about, and means every later run would silently compare "".
          curl -s --max-time 15 -H "Title: JLPT watch needs attention" -H "Tags: warning" \
            -H "Priority: high" \
            -d "Component 18 not found on the UCD booking page. The page structure changed; the watcher is blind until it is updated.
        $URL" "$NTFY" >/dev/null
          exit 0
        fi

        text=$(printf "%s" "$comp" | sed "s|<[^>]*>| |g" | tr -s " \t" " ")
        hash=$(printf "%s" "$text" | md5sum | cut -d" " -f1)
        signal=$(printf "%s" "$comp" | grep -ciE "<form|href=\"[^\"]*(book|apply|register|eventbrite|ticket)" || true)

        prev=""
        [ -f "$STATE_DIRECTORY/hash" ] && prev=$(cat "$STATE_DIRECTORY/hash")
        printf "%s" "$hash" > "$STATE_DIRECTORY/hash"
        printf "%s" "$text" > "$STATE_DIRECTORY/last-text"

        if [ "$signal" -gt 0 ]; then
          curl -s --max-time 15 -H "Title: JLPT REGISTRATION MAY BE OPEN" -H "Tags: rotating_light" \
            -H "Priority: max" \
            -d "A form or booking link has appeared on the UCD JLPT page. Exam: Sun 6 Dec 2026. Places fill fast.
        $URL" "$NTFY" >/dev/null
          echo "HIGH: booking signal found"
          exit 0
        fi

        if [ -n "$prev" ] && [ "$prev" != "$hash" ]; then
          curl -s --max-time 15 -H "Title: UCD JLPT page changed" -H "Tags: eyes" \
            -H "Priority: default" \
            -d "$text
        $URL" "$NTFY" >/dev/null
          echo "LOW: text changed"
          exit 0
        fi

        echo "no change"
      '';
    };
  };

  systemd.timers.jlpt-watch = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 07..21:00/15:00";
      RandomizedDelaySec = "2m";
      Persistent = true;
    };
  };
}

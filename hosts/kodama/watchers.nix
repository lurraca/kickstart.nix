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

  # ── PC parts deal watch (r/IrelandGaming) ────────────────────────────────
  #
  # Why this exists, with a measured example. On 8 Sep a SanDisk SN7100 2TB
  # appeared on Amazon.ie at €127 — €63.50/TB against the €98/TB of the drive
  # actually on the shortlist. It was gone in UNDER TEN MINUTES and went back
  # to €332.89. Nobody in the thread got one:
  #     "I saw this post when it was '2m' old, clicked the link and it was
  #      already gone."
  #     "The last day a 4tb for 280 last less than 24 hours before it went
  #      back to 600€."
  # A deal measured in minutes cannot be caught by checking a site now and
  # then. It can be caught by a push the moment someone posts it.
  #
  # 🎯 WHY REDDIT AND NOT THE SHOPS.
  # The sub aggregates deals across every retailer — Amazon, Currys, Komplett,
  # Lenovo — so one feed covers them all, and humans filter for "actually good"
  # before posting. Polling individual Amazon ASINs would have missed the
  # SN7100 entirely: it was never on the shortlist.
  #
  # 🔴 r/gamingireland IS DEAD — 4 subscribers, two posts, both Feb 2022. The
  # live sub is r/IrelandGaming, ~24.8k subscribers since 2017. Easy to get
  # wrong; the dead one will never produce a signal and looks identical.
  #
  # ⚠️ REDDIT RATE-LIMITS THIS HARD, AND NOT ON A FIXED INTERVAL. The JSON API
  # 403s outright from here. The Atom feed at /new/.rss is the only endpoint
  # that answers — but measured on 8 Sep at a steady 90-second gap it went
  # 200 → 429 → 200, so the limiter is stochastic, not a simple rate. Expect
  # the occasional refusal even at 20 minutes.
  #
  # 🎯 A SKIPPED RUN IS HARMLESS, AND THAT IS BY DESIGN, NOT LUCK. The feed
  # carries the newest 25 posts and this sub runs ~4-5 posts/day, so the window
  # is roughly FIVE DAYS deep. A 429 costs nothing: the next successful poll
  # still sees every post the failed one would have. So the script exits quietly
  # on any non-200 rather than retrying — do not add a retry loop, and do not
  # tighten the cadence to "compensate" for the misses. Both trade a harmless
  # skip for a harder rate-limit.
  #
  # Unlike feed-watch, the URL and patterns are in the clear here on purpose.
  # Wanting a cheap SSD is not sensitive, and a visible pattern is one that can
  # be reviewed and tuned. Only NTFY comes from the env file, because the topic
  # is a bearer credential in URL form.
  systemd.services.parts-watch = {
    description = "Watch r/IrelandGaming for PC parts deals → ntfy";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.curl pkgs.gnugrep pkgs.gnused pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "parts-watch";
      EnvironmentFile = "/srv/secrets/feed-watch.env";
      ExecStart = pkgs.writeShellScript "parts-watch" ''
        set -u
        FEED="https://www.reddit.com/r/IrelandGaming/new/.rss"
        UA="kodama-parts-watch/1.0 (homelab)"
        : "''${NTFY:?NTFY not set in /srv/secrets/feed-watch.env}"

        # A part must be named AND the title must look like a price/offer.
        # Both are required: "RX 7800XT" alone is someone asking what to pay.
        PARTS='nvme|ssd|m\.2|\bgpu\b|rtx|radeon|\brx ?[0-9]{4}|ryzen|\bcpu\b|ddr[45]|\bram\b|motherboard|\bmobo\b|\bpsu\b|monitor|[0-9]+ ?tb\b'
        DEAL='€|eur|quid|sale|deal|price|% ?off|discount|reduced|amazon|currys|komplett|scan\.|overclockers|ebuyer|argos|harvey ?norman|lenovo|lidl|aldi'
        # Questions and sales-by-owner, which match PARTS+DEAL but are not deals.
        SKIP='valuation|what.?s it worth|how much|recommend|advice|help me|should i|selling my|\bwtb\b|looking (for|to buy)|opinions|is this .{0,20}good|where to (get|buy|find)|worth it\?|thoughts on'

        feed=$(curl -s --max-time 30 -A "$UA" -w '\n%{http_code}' "$FEED") || { echo "fetch failed"; exit 0; }
        code=$(printf '%s' "$feed" | tail -n1)
        body=$(printf '%s' "$feed" | sed '$d')
        if [ "$code" != "200" ]; then echo "reddit returned $code (rate limit?) — skipping"; exit 0; fi
        [ -z "$body" ] && exit 0

        # 🔴 FIRST RUN PRIMES, IT DOES NOT ALERT.
        # The feed carries the last ~25 posts. With an empty dedupe log every
        # matching one of them is "new", so a fresh deploy (or a lost state
        # dir) would fire a burst of alerts for deals that are days old and
        # long dead — training you to ignore the notification that matters.
        # So: record what is already there, say nothing, start watching.
        prime=0
        if [ ! -f "$STATE_DIRECTORY/seen" ]; then
          prime=1
          # Create it NOW, not inside the loop. The loop runs in a subshell and
          # only writes when something matches — so a priming run that matched
          # nothing would leave no file, prime again next time, and swallow a
          # real deal that arrived in between.
          : > "$STATE_DIRECTORY/seen"
        fi

        printf '%s' "$body" | tr '\n' ' ' | sed 's|<entry>|\n<entry>|g' | while IFS= read -r entry; do
          case "$entry" in "<entry>"*) ;; *) continue ;; esac
          title=$(printf '%s' "$entry" | sed -n 's|.*<title>\(.*\)</title>.*|\1|p' | head -1)
          [ -z "$title" ] && continue
          link=$(printf '%s' "$entry" | grep -oE '<link[^>]*href="[^"]*"' | head -1 | sed 's/.*href="//;s/"$//')
          id=$(printf '%s' "$entry" | sed -n 's|.*<id>\(.*\)</id>.*|\1|p' | head -1)
          [ -z "$id" ] && id="$link"

          printf '%s' "$title" | grep -qiE "$PARTS" || continue
          printf '%s' "$title" | grep -qiE "$DEAL"  || continue
          printf '%s' "$title" | grep -qiE "$SKIP"  && continue

          key=$(printf '%s' "$id" | md5sum | cut -d' ' -f1)
          if [ -f "$STATE_DIRECTORY/seen" ] && grep -qxF "$key" "$STATE_DIRECTORY/seen"; then continue; fi
          echo "$key" >> "$STATE_DIRECTORY/seen"
          if [ "$prime" = "1" ]; then echo "primed (no alert): $title"; continue; fi

          msg=$(printf '%s' "$title" | sed -e 's/&amp;/\&/g' -e 's/&quot;/"/g' -e "s/&#39;/'/g" -e 's/&lt;/</g' -e 's/&gt;/>/g')
          curl -s --max-time 15 \
            -H "Title: PC parts deal" -H "Tags: computer,moneybag" -H "Priority: high" \
            -d "$msg
        $link" "$NTFY" >/dev/null
          echo "alerted: $msg"
        done

        if [ -f "$STATE_DIRECTORY/seen" ]; then
          tail -n 500 "$STATE_DIRECTORY/seen" > "$STATE_DIRECTORY/seen.tmp" \
            && mv "$STATE_DIRECTORY/seen.tmp" "$STATE_DIRECTORY/seen"
        fi
      '';
    };
  };

  systemd.timers.parts-watch = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # 20 min, 08:00-23:40. Reddit 429s a tighter cadence, and a flash deal
      # posted at 04:00 is not catchable by a human anyway.
      OnCalendar = "*-*-* 08..23:00/20:00";
      RandomizedDelaySec = "90";
      Persistent = true;
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

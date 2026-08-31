{ config, lib, pkgs, ... }:
# The 2 TB Samsung 860 EVO: bulk storage for media and photos.
#
#   /dev/sda1  LUKS2                     ← keyfile slot 0, passphrase slot 1
#     └─ vgmedia (LVM)
#          ├─ lv-media   800G → /data/media    disposable, *arr churn
#          ├─ lv-photos  300G → /data/photos   irreplaceable, backed to R2
#          └─ ~763G unallocated pool
#
# WHY LVM: sizes are guesses today. `lvextend -r` grows a volume online, and a
# future service (nextcloud, paperless-bulk) gets its own LV from the pool
# without repartitioning. Same reasoning recorded for the NVMe in [[homelab]]:
# "Neither fixed partition would have been resizable... LVM growth is online".
#
# WHY SEPARATE VOLUMES, not one filesystem with two directories: the *arr stack
# filled /data to 100% on 20 Aug 2026. Seeding limits are a policy control and
# policy controls fail. Separate LVs make media hit its own wall without taking
# Immich's writes down with it — the disposable thing should be the thing that
# breaks.
#
# WHY ENCRYPTED: this is a second-hand drive with 63,853 power-on hours. Its
# likely end is sudden failure, and you cannot secure-erase a dead disk — it
# gets binned with 16,000 photos still readable. LUKS makes that a non-event.
# It protects the drive leaving the machine; it does NOT protect a running
# system or theft of the whole box (the keyfile sits on the NVMe beside it).
{
  environment.systemPackages = [ pkgs.cryptsetup ];

  # ── Unlock ──────────────────────────────────────────────────────────────
  # NOT boot.initrd.luks — that is for the root device. This unlocks during
  # normal boot via systemd-cryptsetup, generated from /etc/crypttab.
  #
  # 🔴 THE ORDERING TRAP: the keyfile lives on /srv, which is its own LV and is
  # NOT mounted when systemd-cryptsetup would otherwise run. Without
  # RequiresMountsFor the unlock fails on a cold boot with "keyfile not found",
  # and every mount and container behind it fails too. Same shape as the
  # https-dns-proxy failure on 29 Aug: a boot-order assumption that holds while
  # running and breaks from cold.
  environment.etc.crypttab.text = ''
    media UUID=37e2f991-1aec-4cb9-b10a-712bfee4c939 /srv/secrets/media.key luks,nofail
  '';

  # ⚠️ MUST be a drop-in, not a unit definition. `systemd.services."systemd-
  # cryptsetup@media"` makes NixOS emit a COMPLETE unit file that shadows the
  # one systemd-cryptsetup-generator builds from /etc/crypttab — leaving it with
  # no ExecStart, which systemd rejects outright:
  #   "Service has no ExecStart=, ExecStop=, or SuccessAction=. Refusing."
  # overrideStrategy = "asDropin" adds to the generated unit instead of
  # replacing it.
  systemd.units."systemd-cryptsetup@media.service" = {
    overrideStrategy = "asDropin";
    text = ''
      [Unit]
      RequiresMountsFor=/srv/secrets
      After=srv.mount
      Requires=srv.mount
    '';
  };

  # ── Ownership ───────────────────────────────────────────────────────────
  # The CIFS mount faked this: uid=0,gid=0,file_mode=0666,dir_mode=0777 meant
  # everything looked root-owned and world-writable, so nothing needed a real
  # permissions model. A real filesystem has no such fiction.
  #
  # Who touches these paths:
  #   jellyfin  — official image, no `user:` directive, so runs as ROOT and
  #               mounts /data/media read-only. Reads anything; needs nothing.
  #   sonarr    — uid 274, imports downloads
  #   radarr    — uid 275, imports downloads
  #   bazarr    — uid 991, writes subtitles alongside the media
#   qbittorrent — owns /data/media/downloads; the *arr need group read on
#               its completed files to hardlink them into the library
  #
  # A shared `media` group covers the three writers. Directories are setgid
  # (2775) so files THEY create inherit the group — without that, sonarr's
  # imports would be group `sonarr` and bazarr could not write subtitles next
  # to them.
  users.groups.media = { };
  users.users.sonarr.extraGroups = [ "media" ];
  users.users.radarr.extraGroups = [ "media" ];
  users.users.bazarr.extraGroups = [ "media" ];
  users.users.qbittorrent.extraGroups = [ "media" ];

  # 🔴 UMask 0002, not systemd's default 0022. Group membership alone is NOT
  # enough to make the shared group work, and the failure is silent.
  #
  # The kernel runs with `fs.protected_hardlinks = 1`, which permits a hardlink
  # only to a file the user OWNS, or has read AND WRITE on. At the default
  # umask qBittorrent creates completed downloads as 0644 — group-readable but
  # not group-writable — so Sonarr, despite being in `media`, is refused the
  # link. Sonarr and Radarr both set copyUsingHardlinks = true, and that
  # setting does not error when the link is denied: it quietly falls back to a
  # full byte-for-byte copy. The symptom is slow imports and every seeding file
  # stored twice, with nothing in any log to explain it.
  #
  # Measured on kodama 2026-08-30: 0644 → link refused; 0664 → link succeeds,
  # inode link count 2. This one line is the difference.
  # mkForce because the nixpkgs servarr modules set UMask = "0022" themselves,
  # in servarr/{sonarr,radarr}.nix — which is precisely why this trap is easy
  # to fall into on NixOS: the restrictive default is not systemd's, it is the
  # module's, and overriding it needs an explicit priority bump.
  systemd.services.qbittorrent.serviceConfig.UMask = lib.mkForce "0002";
  systemd.services.sonarr.serviceConfig.UMask = lib.mkForce "0002";
  systemd.services.radarr.serviceConfig.UMask = lib.mkForce "0002";
  systemd.services.bazarr.serviceConfig.UMask = lib.mkForce "0002";

  systemd.tmpfiles.rules = [
    # 🔴 /srv/secrets holds every service credential on the box, and it was
    # UNDECLARED manual state until this rule existed. That cost an outage.
    #
    # Adding media.key here on 2026-08-29 came with a hand-run `chmod 0700`
    # on the directory, to protect the LUKS keyfile. Nothing broke at the
    # time, because every service that reads a secret was already running and
    # had already opened its file. The damage only appeared at the next
    # reboot: grafana died with "stat /srv/secrets/grafana-secret-key:
    # permission denied", restarted five times in under a second, and hit
    # systemd's start limit. Its own file was fine (0640 root:grafana) — it
    # could not TRAVERSE the parent to reach it.
    #
    # 0711 is the fix, and the distinction is the point: +x grants traversal
    # to a known path, +r grants listing. Services open a path they already
    # know, so they need only the former. `ls /srv/secrets` stays root-only,
    # and what actually protects each secret is its own mode — media.key is
    # 0400 root:root and remains unreadable to every non-root user here.
    "d /srv/secrets 0711 root root - -"

    "d /data/media  2775 root media - -"
    "d /data/photos 2775 root media - -"

    # Immich, migrating here from kasasagi (WSL2/Docker Desktop).
    # Two locations on purpose, each so an EXISTING Backrest plan covers it
    # with no new backup config:
    #   /data/photos/immich  -> the library, on the encrypted SATA drive,
    #                           already inside the `photos` plan.
    #   /srv/immich          -> Postgres, on the NVMe for random I/O, already
    #                           inside the `srv` plan.
    # Declared here rather than mkdir'd, because undeclared manual state under
    # /srv is precisely what killed Grafana on 29 Aug — see the note above.
    # ⚠️ A restic snapshot of a LIVE Postgres data directory is not a
    # consistent backup; /srv/immich/dump is where a nightly pg_dumpall lands
    # and is the copy that can actually be trusted for restore.
    "d /srv/immich         0755 root root - -"
    "d /srv/immich/dump    0750 root root - -"
  ];

  # ── Filesystems ─────────────────────────────────────────────────────────
  # by-label, not by-uuid: if a volume is ever rebuilt the label is reapplied,
  # so the config keeps working without editing a UUID in here.
  # MIGRATED 2026-08-29. This volume now IS the media library — it took over
  # /data/media from the CIFS share on kasasagi, per the pattern in [[homelab]]
  # ("rsync -> mount the HDD at /data -> lvremove. No re-index, no
  # reconfiguration"). Staged at /mnt/media-new during the copy because
  # media.nix still owned /data/media as the *source*; that mount is now
  # retired and the path is free.
  #
  # 369.7 GB across 485 files verified identical by a metadata dry-run. One
  # file did not come across — Spider-Man Far From Home's mp4, unreadable
  # even as root on the source share. See media.nix for the re-copy path.
  #
  # Jellyfin only ever knew /data/media, so it never noticed the swap.
  fileSystems."/data/media" = {
    device = "/dev/disk/by-label/media";
    fsType = "ext4";
    options = [ "defaults" "nofail" "x-systemd.device-timeout=30s" ];
  };

  fileSystems."/data/photos" = {
    device = "/dev/disk/by-label/photos";
    fsType = "ext4";
    options = [ "defaults" "nofail" "x-systemd.device-timeout=30s" ];
  };

  # ⚠️ `nofail` is deliberate. A failed unlock must not drop the box to an
  # emergency shell — it is headless and the AMT KVM keyboard is unreliable.
  # Better: boot degraded, stay reachable over SSH, fix it remotely.
}

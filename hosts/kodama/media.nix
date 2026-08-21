{ config, lib, pkgs, ... }:
# Media share from kasasagi (the Windows gaming PC), mounted over Tailscale.
#
# WHY THIS PATH: /data/media is where the 6 TB external drive will eventually
# mount. Jellyfin only ever knows /data/media, so when the drive arrives the
# migration is "copy files, swap what is mounted here" — no library re-scan, no
# lost watch history. Same trick immich-setup.md uses for UPLOAD_LOCATION.
{
  # cifs-utils provides mount.cifs, which the kernel calls to negotiate SMB.
  # Without it the mount fails with "unknown filesystem type".
  environment.systemPackages = [ pkgs.cifs-utils ];

  fileSystems."/data/media" = {
    # Tailnet IP, not the MagicDNS name, and not the LAN IP:
    #   - tailnet IPs are permanently assigned per node, so this is stable
    #     without needing a DHCP reservation on the Windows box
    #   - using the IP avoids depending on DNS resolution at mount time,
    #     which is awkward inside an automount unit
    device = "//100.97.61.16/Media";
    fsType = "cifs";

    options = [
      # Credentials in a root-only file, so the password never appears in
      # /proc/mounts or in the output of `ps`.
      "credentials=/srv/secrets/smb-kasasagi"

      # Read-only. Jellyfin writes metadata into its own config dir, never
      # alongside the media, so it has no reason to hold write access.
      "ro"

      # 🎯 THE IMPORTANT ONE. Without automount, systemd tries to mount this
      # at boot and blocks waiting for a PC that is usually switched off —
      # a slow boot at best, a degraded one at worst. With it, the mount
      # happens lazily on first access and simply fails cleanly when the PC
      # is off, which is the normal state here.
      "x-systemd.automount"
      "noauto"

      # Drop the mount after 10 min idle, so a sleeping PC does not leave a
      # stale handle behind.
      "x-systemd.idle-timeout=600"

      # Fail fast rather than hanging for the default 90s when the PC is off.
      "x-systemd.device-timeout=10s"
      "x-systemd.mount-timeout=10s"
      "nofail"

      # CIFS has no Unix permissions, so they are synthesised at mount time.
      # World-readable is fine for a read-only media share and avoids having
      # to match whatever UID the Jellyfin container runs as.
      "file_mode=0444"
      "dir_mode=0555"

      # Filenames contain Japanese characters; without this they arrive mangled.
      "iocharset=utf8"

      # SMB 3.0: encrypted and modern. SMB1 is off on Windows 11 anyway.
      "vers=3.0"

      # Windows inode numbers are not stable across reconnects, which can make
      # Jellyfin think files changed. Let the client generate them instead.
      "noserverino"
    ];
  };

  # A SEPARATE read-write mount to the same share, for Sonarr/Radarr's final
  # import step (servarr.nix) — deliberately not just dropping "ro" from the
  # mount above. Jellyfin's mount stays exactly as reasoned and untouched;
  # this is a second, independent mount instance instead of loosening an
  # existing guarantee.
  fileSystems."/data/media-rw" = {
    device = "//100.97.61.16/Media";
    fsType = "cifs";

    options = [
      "credentials=/srv/secrets/smb-kasasagi"

      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=600"
      "x-systemd.device-timeout=10s"
      "x-systemd.mount-timeout=10s"
      "nofail"

      # World-writable, not scoped to one UID: Sonarr and Radarr run as
      # different service users, and CIFS only supports one uid/gid pairing
      # per mount (no per-file ownership mapping like a real POSIX
      # filesystem) — same reasoning the read-only mount above already uses
      # for world-readable, just the write-side mirror of it. Only local,
      # trusted services on kodama ever touch this path.
      "file_mode=0666"
      "dir_mode=0777"

      "iocharset=utf8"
      "vers=3.0"
      "noserverino"
    ];
  };
}

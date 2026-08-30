{ config, lib, pkgs, ... }:
# The old home of the media library: a CIFS share on kasasagi (the Windows
# gaming PC), mounted over Tailscale.
#
# 🔴 NO LONGER IMPORTED (removed from flake.nix on 2026-08-30). Kept on disk as
# the historical record of how the media was served before it moved; delete it
# whenever you want. It is not built, so nothing here affects the system.
#
# Why it was dropped rather than kept: the one file it existed to re-copy —
# Spider-Man Far From Home — was recovered directly from Windows (readable
# locally; only the SMB share ACL denied the `jellyfin` user), and C:\Media was
# then deleted. The share now points at a directory that does not exist, so the
# mount unit failed on the next boot. Purpose spent.
#
# ⚠️ RETIRED as the library's location on 2026-08-29. The library now lives on
# kodama's own encrypted 2 TB SATA drive — see storage.nix, which owns
# /data/media and /data/photos. The migration was exactly the swap this file's
# original comment predicted: copy the files, change what is mounted at
# /data/media, and Jellyfin never noticed.
#
# WHAT SURVIVES, AND WHY. One read-only mount, at a neutral path, kept for
# one-off pulls from the gaming PC — the source library is still there, and
# one file never made it across: Spider-Man Far From Home's mp4 is unreadable
# even as root over CIFS (the NTFS ACL denies it; the 0444 mode CIFS reports
# is synthesised from the mount options, not real). If that gets fixed on the
# Windows side, this is the path to re-copy it from.
#
# It costs nothing at boot: `noauto` + `x-systemd.automount` means it is only
# touched on first access, and fails cleanly when the PC is off, which is its
# normal state. Delete this file and its flake import when the gaming PC no
# longer holds anything worth pulling.
{
  # cifs-utils provides mount.cifs, which the kernel calls to negotiate SMB.
  # Without it the mount fails with "unknown filesystem type".
  environment.systemPackages = [ pkgs.cifs-utils ];

  fileSystems."/mnt/kasasagi-media" = {
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

      # Read-only, and now permanently so: this is a source to pull FROM.
      # Nothing on kodama should ever write back to the gaming PC.
      "ro"

      # Lazy mount. Without automount, systemd tries to mount this at boot and
      # blocks waiting for a PC that is usually switched off — a slow boot at
      # best, a degraded one at worst.
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
      "file_mode=0444"
      "dir_mode=0555"

      # Filenames contain Japanese characters; without this they arrive mangled.
      "iocharset=utf8"

      # SMB 3.0: encrypted and modern. SMB1 is off on Windows 11 anyway.
      "vers=3.0"

      # Windows inode numbers are not stable across reconnects. Let the client
      # generate them instead.
      "noserverino"
    ];
  };
}

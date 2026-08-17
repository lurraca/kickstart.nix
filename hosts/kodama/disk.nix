{ ... }:
{
  # Declarative disk layout for kodama (disko).
  #
  # Single source of truth for partitioning. `disko --mode destroy,format,mount`
  # creates exactly this, and the same file then supplies the running system's
  # `fileSystems` — so there is no hand-written UUID to keep in sync and no
  # `nixos-generate-config` output to copy back.
  #
  # ┌─ p1    2 GiB   ESP                /boot
  # └─ p2  ~236 GiB  LVM volume group "vg"
  #         ├─ root    55 GiB   /       OS, nix store, Docker images
  #         ├─ srv     45 GiB   /srv    state that must survive a reinstall
  #         ├─ data   100 GiB   /data   TEMPORARY Immich library
  #         └─ ~36 GiB unallocated      grow whichever fills first
  #
  # Why LVM. Two drivers, both discovered after an initial fixed-partition
  # design turned out not to survive contact with the actual plan:
  #
  #   1. With plain partitions the last one takes 100% to the end of the disk,
  #      so NEITHER partition can be resized without relocating data offline.
  #      On a headless box that means booting a live image over AMT/IDE-R.
  #      LVM makes growth a bookkeeping change: online, seconds, no data moved.
  #   2. The Immich library lives here only until the external 6 TB drive
  #      arrives. As an LV it can be REMOVED afterwards and its ~125 GiB
  #      returned to the pool. As a partition that space would be stranded.
  disko.devices = {
    disk.main = {
      type = "disk";

      # ⚠️ by-id, NOT /dev/nvme0n1 — this path contains the drive's serial, so
      # disko cannot format a different disk if enumeration order changes.
      # Serial S4Y6NF0N912710 is the PM991 recorded in robotina
      # notes/homelab/inventory.md, read from AMT firmware.
      #
      # Verify from the installer before the first run:
      #   ls -l /dev/disk/by-id/ | grep S4Y6NF0N912710
      # Vendor strings vary in punctuation; correct this line if it differs.
      device = "/dev/disk/by-id/nvme-SAMSUNG_MZVLQ256HAJD-00000_S4Y6NF0N912710";

      content = {
        type = "gpt";
        partitions = {
          # 2 GiB from measurement, not habit: this system's initrd is 42 MB
          # and kernel 13 MB = 55 MB per generation, and systemd-boot keeps
          # configurationLimit (20) of them here => ~1.1 GB. A 1 GiB ESP
          # overflows and breaks the *next* rebuild with a confusing ENOSPC.
          ESP = {
            priority = 1;
            name = "ESP";
            size = "2G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              # Keeps the bootloader dir non-world-readable, silencing the
              # systemd-boot permissions warning on every rebuild.
              mountOptions = [ "umask=0077" ];
            };
          };

          # Everything else becomes one LVM physical volume.
          pv = {
            size = "100%";
            content = {
              type = "lvm_pv";
              vg = "vg";
            };
          };
        };
      };
    };

    lvm_vg.vg = {
      type = "lvm_vg";

      # ⚠️ These do NOT add up to the full ~236 GiB, and that is deliberate.
      # ~36 GiB is left unallocated as a shared buffer — it is far easier to
      # grow an LV into free space than to shrink one (growth is online,
      # shrinking needs an unmount and an offline resize2fs).
      lvs = {
        # ── Disposable ────────────────────────────────────────────────────
        # OS, nix store, Docker images, and regenerable service data.
        # Everything here is either in git or reproducible.
        root = {
          size = "55G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };

        # ── Must survive an OS reinstall ─────────────────────────────────
        # State that cannot be regenerated: Immich's Postgres (albums, faces,
        # metadata edits), Home Assistant config + recorder history, AdGuard
        # config. Sized at 45G rather than the ~10G today's services need,
        # because the growth here is monitoring — a Prometheus TSDB or an HA
        # recorder with real retention runs 10-30 GiB, and historical time
        # series are exactly the "impossible to regenerate" category.
        #
        # ⚠️ THIS IS NOT A BACKUP. It survives a *deliberate* reinstall, not a
        # mistake, a dead drive, or a fat-fingered mkfs. The real protection is
        # the nightly pg_dump written to the EXTERNAL drive — a different
        # physical device.
        srv = {
          size = "45G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/srv";
          };
        };

        # ── Temporary: the Immich library, pending the 6 TB external ─────
        # Immich's UPLOAD_LOCATION points at /data/immich and NEVER CHANGES.
        # Migration is a mount swap, not a reconfiguration:
        #   1. rsync /data/immich -> the external drive
        #   2. unmount this LV, mount the HDD at /data
        #   3. lvremove vg/data   <- returns ~125 GiB to the pool
        # Immich never learns anything moved and there is no re-index.
        #
        # Starts at 100G against a pruned target of ~120 GB (~112 GiB) plus
        # ~8 GiB of thumbnails. Grow it from the pool as the import actually
        # progresses rather than committing the space up front:
        #   lvextend -L +25G /dev/vg/data --resizefs
        data = {
          size = "100G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/data";
          };
        };
      };
    };
  };

  # No swap volume — zramSwap is enabled in configuration.nix. 24 GB of RAM is
  # ample for the planned services, and a swapfile can be added in one line if
  # that turns out to be wrong.
}

# PXE netboot server — boot an installer on kasasagi over the network.
#
# Built 10 Sep 2026 for the Omarchy install (ROB-120). Luis has no USB stick,
# and kodama itself was installed entirely over AMT with no USB stick, so the
# same reflex applies. Reusable afterwards for memtest86, GParted, a rescue
# shell, and the reinstall the Omarchy ladder anticipates.
#
#   kasasagi UEFI PXE → dnsmasq proxy-DHCP (kodama) → ipxe.efi over TFTP
#                     → iPXE fetches boot.ipxe over HTTP
#                     → kernel + initramfs + archiso_http_srv
#
# ── The three things that will break this ────────────────────────────────────
#
# 1. 🔴 pihole-FTL OWNS PORT 53. dnsmasq is the standard PXE tool and wants 53
#    too. `port = 0` turns its DNS off entirely. Getting this wrong takes DNS
#    down for the whole house — the 29 Aug outage, again, on purpose.
#
# 2. 🔴 PROXY-DHCP, NOT DHCP. The router at 192.168.1.1 keeps handing out
#    addresses; dnsmasq only adds the boot options. Never run a second real
#    DHCP server on this LAN.
#
# 3. 🔴 OMARCHY'S OWN PXE PATH IS SYSLINUX = LEGACY BIOS ONLY. Using it would
#    mean enabling CSM on kasasagi. iPXE chainloaded over UEFI instead, loading
#    kernel + initrd directly.
#
# ── Facts measured off the real ISO on 10 Sep, not assumed ───────────────────
#
# The plan in notes/homelab/pxe-netboot.md guessed the ISO layout. Two guesses
# were wrong and both would have failed at boot:
#
#   * The kernel is `vmlinuz-linux-t2`, not `vmlinuz-linux`, and the initramfs
#     is `initramfs-linux-t2.img`. Omarchy ships the t2 kernel variant as its
#     only kernel.
#   * The ISO's own PXE config appends `cms_verify=y`, and that is WRONG for
#     this image: `arch/x86_64/` contains `airootfs.sha512` and NO
#     `airootfs.sfs.cms.sig`. Signature verification would fail with nothing to
#     verify against. `checksum=y` uses the sha512 that is actually there.
#
# Port 8090 was checked against kodama's live listeners on 10 Sep — 22, 53,
# 2283, 3000, 5055, 6767, 8080, 8081, 8082, 8096, 8123, 8191, 9093, 9100, 9115,
# 9666, 9696 were in use; 8090 was free. Check again before adding a service.
{ config, pkgs, lib, ... }:

let
  lanIp = "192.168.1.111";
  httpPort = 8090;

  # NOT /srv. /srv is in the Backrest "srv" plan and goes to Cloudflare R2
  # nightly; a 6 GB ISO tree that can be re-downloaded in 64 seconds has no
  # business in an off-site backup. /data is local-only and has the room.
  root = "/data/netboot";

  # Served at ${base}/ — archiso fetches ${base}/arch/x86_64/airootfs.sfs from
  # it, so this must be the directory that CONTAINS `arch/`.
  bootScript = pkgs.writeText "boot.ipxe" ''
    #!ipxe
    set base http://${lanIp}:${toString httpPort}/omarchy
    echo Booting Omarchy from ''${base}
    kernel ''${base}/arch/boot/x86_64/vmlinuz-linux-t2 archisobasedir=arch archiso_http_srv=''${base}/ checksum=y initramfs_async=0 ip=dhcp
    initrd ''${base}/arch/boot/x86_64/initramfs-linux-t2.img
    boot
  '';
in
{
  services.dnsmasq = {
    enable = true;
    settings = {
      # 🔴 DNS OFF. pihole-FTL owns 53. See note 1 above.
      port = 0;

      interface = "eno2";
      bind-interfaces = true;

      # Proxy mode: advertise boot options, hand out no addresses. See note 2.
      dhcp-range = [ "192.168.1.0,proxy" ];

      enable-tftp = true;
      tftp-root = "${root}/tftp";

      # Break the chainload loop. Without this, ipxe.efi boots, asks again, is
      # told to load ipxe.efi, and loops forever. iPXE identifies itself with
      # DHCP option 175, so: no tag → send the binary; tagged → send the script.
      dhcp-match = [ "set:ipxe,175" ];
      pxe-service = [ ''tag:!ipxe,x86-64_EFI,"Netboot (iPXE)",ipxe'' ];
      dhcp-boot = [ "tag:ipxe,http://${lanIp}:${toString httpPort}/boot.ipxe" ];
    };
  };

  # nginx is already enabled in tls.nix as the reverse proxy; this adds one
  # plain-HTTP vhost. TLS is pointless here — iPXE would need a CA bundle and
  # the payload is a public ISO on the LAN.
  services.nginx.virtualHosts."netboot" = {
    listen = [ { addr = lanIp; port = httpPort; } ];
    root = "${root}/http";
    extraConfig = ''
      autoindex on;
      # airootfs.sfs is 5.9 GB. sendfile keeps it out of nginx's memory.
      sendfile on;
      tcp_nopush on;
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${root}        0755 root root -"
    "d ${root}/tftp   0755 root root -"
    "d ${root}/http   0755 root root -"
    # iPXE from nixpkgs rather than a downloaded binary — reproducible, and it
    # updates with the channel instead of rotting in a directory.
    "L+ ${root}/tftp/ipxe.efi  - - - - ${pkgs.ipxe}/ipxe.efi"
    "L+ ${root}/http/boot.ipxe - - - - ${bootScript}"
  ];

  networking.firewall = {
    # 67 proxy-DHCP · 69 TFTP · 4011 PXE (proxy-DHCP replies to the client's
    # second request on 4011, and leaving it closed is a classic silent hang).
    allowedUDPPorts = [ 67 69 4011 ];
    allowedTCPPorts = [ httpPort ];
  };
}

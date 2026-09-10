# PXE netboot server — boot an installer on kasasagi over the network.
#
# Built 10 Sep 2026 for the Omarchy install (ROB-120). Luis has no USB stick,
# and kodama itself was installed entirely over AMT with no USB stick, so the
# same reflex applies. Reusable afterwards for memtest86, GParted, a rescue
# shell, and the reinstall the Omarchy ladder anticipates.
#
#   kasasagi UEFI PXE → pixiecore proxy-DHCP (kodama) → its own iPXE over TFTP
#                     → iPXE fetches kernel + initrd from pixiecore over HTTP
#                     → initramfs pulls airootfs.sfs from nginx (5.9 GB)
#
# ── The three things that will break this ────────────────────────────────────
#
# 1. 🔴 dnsmasq CANNOT BE USED ON THIS HOST AT ALL — and `port = 0` does not
#    save it. The plan assumed turning dnsmasq's DNS off would let it coexist
#    with pihole-FTL. It does not: nixpkgs carries a build-time assertion,
#    `pihole-ftl conflicts with dnsmasq. Please disable one of them.`, which
#    fires during evaluation regardless of any runtime setting. Discovered by
#    the rebuild failing on 10 Sep.
#
#    🎯 Pixiecore instead — a single binary that does proxy-DHCP, TFTP and HTTP
#    and never binds 53, so the whole class of "PXE took down the house's DNS"
#    disappears rather than being carefully avoided.
#
# 2. 🔴 PROXY-DHCP, NOT DHCP. The router at 192.168.1.1 keeps handing out
#    addresses; pixiecore only adds the boot options. Never run a second real
#    DHCP server on this LAN — pixiecore's boot mode is proxy-only by design.
#
# 3. 🔴 OMARCHY'S OWN PXE PATH IS SYSLINUX = LEGACY BIOS ONLY. Using it would
#    mean enabling CSM on kasasagi. Pixiecore chainloads its own iPXE over
#    UEFI and loads kernel + initrd directly.
#
# 4. ⬜ TURN THIS OFF AFTER THE INSTALL. Proxy-DHCP answers *any* machine on the
#    LAN that PXE-boots, and it will hand every one of them an Omarchy
#    installer. One PC on this network makes that harmless today; it is not a
#    thing to leave running for months. `services.pixiecore.enable = false;`
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
  httpPort = 8090;    # nginx, serves the 5.9 GB squashfs
  pxePort = 8091;     # pixiecore's own HTTP, serves kernel + initrd

  # NOT /srv. /srv is in the Backrest "srv" plan and goes to Cloudflare R2
  # nightly; a 6 GB ISO tree that can be re-downloaded in 64 seconds has no
  # business in an off-site backup. /data is local-only and has the room.
  root = "/data/netboot";
  iso = "${root}/http/omarchy";
in
{
  services.pixiecore = {
    enable = true;
    openFirewall = true;
    mode = "boot";
    port = pxePort;

    kernel = "${iso}/arch/boot/x86_64/vmlinuz-linux-t2";
    initrd = "${iso}/arch/boot/x86_64/initramfs-linux-t2.img";

    # archiso_http_srv must be the directory CONTAINING `arch/` — the initramfs
    # fetches ${"\${archiso_http_srv}"}arch/x86_64/airootfs.sfs from it. Served by nginx
    # below rather than by pixiecore, because it is 5.9 GB.
    cmdLine = "archisobasedir=arch archiso_http_srv=http://${lanIp}:${toString httpPort}/omarchy/ checksum=y initramfs_async=0";
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
    "d ${root}      0755 root root -"
    "d ${root}/http 0755 root root -"
  ];

  # pixiecore's openFirewall covers 67/69/4011 and its own HTTP port. This is
  # just nginx's netboot vhost.
  networking.firewall.allowedTCPPorts = [ httpPort ];
}

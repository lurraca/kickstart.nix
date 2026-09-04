{ pkgs, lib, ... }:
{
  imports = [ ./hardware.nix ];

  # ── Boot ────────────────────────────────────────────────────────────────
  # M920q is UEFI. systemd-boot over GRUB: simpler, and it surfaces the
  # generation list at the boot menu, which is the rollback story that made
  # NixOS worth choosing for an always-on box.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 20;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Identity ────────────────────────────────────────────────────────────
  networking.hostName = "kodama";
  time.timeZone = "Europe/Dublin";
  i18n.defaultLocale = "en_IE.UTF-8";

  # ── Networking ──────────────────────────────────────────────────────────
  # DHCP: the router holds a reservation for 192.168.1.111 against the NIC's
  # MAC, so the address is stable without hard-coding it in two places.
  networking.useDHCP = lib.mkDefault true;

  # Wake-on-LAN. The BIOS setting is already on and the NIC already reports
  # `Wake-on: g`, but that is the driver's default rather than anything asked
  # for — a driver update or a config change could silently drop it, and the
  # failure would only show up the one time it is needed. Declaring it makes
  # the arming durable and visible.
  #
  # ⚠️ LAN-only by nature: a magic packet is a broadcast and does not route, so
  # this works from the phone on home WiFi and NOT over Tailscale. For remote
  # power-on, AMT on :16992 is the answer and already works with the machine
  # fully powered off.
  #
  # ⚠️ Home Assistant cannot be the sender for THIS machine — HA runs on kodama,
  # so it is off whenever the packet would be needed. (It is the right tool for
  # waking kasasagi, which is a different problem.)
  networking.interfaces.eno2.wakeOnLan.enable = true;

  networking.firewall = {
    enable = true;

    # 8123 is Home Assistant. Opened on the LAN on 2026-08-18, deliberately,
    # for Google Cast. A Cast device is not sent audio — it is handed a URL
    # and fetches the media itself, so TTS announcements ("the washing machine
    # has finished") fail unless the speakers can reach HA directly. Control
    # alone works without this; anything HA *serves* does not.
    #
    # ⚠️ This is plain HTTP, so credentials and long-lived tokens cross the
    # LAN unencrypted. The realistic threat is not a person, it is a
    # compromised IoT device already on the network. Accepted because the
    # alternative — a paid cloud relay or a public HTTPS endpoint — is worse
    # on every axis that matters here. Still NAT'd: nothing is exposed to the
    # internet, there is no port forward and no DDNS.
    #
    # Note the previous tailnet-only behaviour was never a decision, just the
    # default of listing one port. Revisit if TLS is ever added (see the AMT
    # note on 16993 in notes/homelab/inventory.md — same unencrypted-on-LAN
    # trade-off, accepted for the same reason).
    #
    # 8096 is Jellyfin. Opened on the LAN for the same reason as 8123: the
    # devices that consume it — Samsung TV, Chromecast, Nest Hub — are not on
    # the tailnet and cannot be. Tailscale covers phones and laptops; a TV app
    # has no way to join a tailnet, so LAN is the only path.
    #
    # Unlike 8123 this is not a credential-carrying admin surface by default,
    # but it IS a login page on plain HTTP, so the same caveat applies: the
    # realistic threat is a compromised device already on the network.
    allowedTCPPorts = [ 22 8123 8096 ];

    # mDNS. Required twice over: Cast discovery, and Matter commissioning if
    # the Matter bridge route is taken later. Without it HA never hears the
    # speakers announce themselves — the devices were reachable on TCP 8009
    # the whole time while discovery found nothing.
    #
    # 7359 is Jellyfin's own client auto-discovery broadcast — without it the
    # TV and phone apps cannot find the server by themselves and every client
    # has to be pointed at the address by hand.
    allowedUDPPorts = [ 5353 7359 ];

    # Tailscale traffic bypasses the port list entirely.
    trustedInterfaces = [ "tailscale0" ];
    checkReversePath = "loose"; # required for Tailscale exit-node/subnet use
  };

  services.tailscale.enable = true;

  # ── Remote access ───────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # ── Users ───────────────────────────────────────────────────────────────
  # Same username as the WSL box on purpose: paths, dotfiles and scp commands
  # stay identical across machines.
  users.users.kasasagi = {
    isNormalUser = true;
    description = "Luis Urraca";
    extraGroups = [ "wheel" "docker" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILQ8dCAsB8WDDR9lqR99WHzSgCbTOZJoPD1g5Jf12CIP kasasagi@wsl"
    ];
  };
  programs.zsh.enable = true;

  # Passwordless sudo for wheel: this box is administered over SSH with a key,
  # so a sudo password adds friction to `nixos-rebuild --target-host` without
  # adding security — anyone holding the key can already run as the user.
  security.sudo.wheelNeedsPassword = false;

  # ── Containers ──────────────────────────────────────────────────────────
  # Immich and Home Assistant run as Compose stacks from ~/code/homelab.
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    autoPrune.dates = "weekly";
  };

  # docker.service and tailscaled.service have no ordering relationship by
  # default, but searxng binds the tailnet IP explicitly (127.0.0.1:8888 +
  # 100.70.107.61:8888 — see /srv/compose/searxng/docker-compose.yml). If
  # dockerd starts containers before tailscaled has configured tailscale0,
  # that bind fails and the container restart-loops until the IP appears.
  # Order docker after tailscaled and wait for the IP explicitly — bounded
  # and non-fatal: a broken tailscaled delays dockerd by at most 30s instead
  # of blocking boot, and the containers' unless-stopped policy covers the
  # remainder. If tailscaled is ever removed from this host, remove this too,
  # or every boot gains a pointless 30s stall.
  systemd.services.docker = {
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    serviceConfig.ExecStartPre = [
      (pkgs.writeShellScript "docker-wait-for-tailnet-ip" ''
        n=0
        until ${pkgs.iproute2}/bin/ip -4 addr show tailscale0 2>/dev/null |
              ${pkgs.gnugrep}/bin/grep -qF '100.70.107.61'; do
          n=$((n + 1))
          if [ "$n" -ge 60 ]; then
            echo "docker: tailnet IP not up after 30s; starting anyway" >&2
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 0.5
        done
      '')
    ];
  };

  # ── Always-on behaviour ─────────────────────────────────────────────────
  # A server that suspends is not a server. AMT can power it back on, but
  # every service would still have been down in the meantime.
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
  # Lid/power-button presses must not stop the machine either.
  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
    HandleLidSwitch = "ignore";
  };

  # Compressed RAM swap instead of a swap partition: 24 GB is plenty for the
  # planned services, the boot SSD is endurance-limited QLC, and this keeps
  # the partition layout to two entries.
  zramSwap.enable = true;

  hardware.cpu.intel.updateMicrocode = true;

  # Firmware updates from LVFS. Lenovo publishes BIOS and Management Engine
  # updates for many ThinkCentre models here, so `fwupdmgr update` replaces
  # the Windows-only .exe or a bootable USB — which matters on a headless box
  # with no Windows installed.
  #
  # ⚠️ ME firmware updates are the reason to care: AMT listens on the LAN and
  # has a real history of remotely exploitable flaws (e.g. CVE-2017-5689), so
  # a machine with AMT enabled is one where firmware currency is a security
  # property, not just housekeeping.
  services.fwupd.enable = true;

  # Bluetooth — the M920q has an Intel 9560 (Jefferson Peak) on the WiFi card.
  # Home Assistant uses it for BLE sensors and presence detection, and it
  # reaches the adapter over the host D-Bus socket bind-mounted into the
  # container. Without this the adapter shows as hci0 but bluetooth.service is
  # `not-found`, so HA discovers Bluetooth and then cannot use it.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # 🔴 Pairing keys are NOT regenerable. /var/lib/bluetooth holds the link keys
  # negotiated with each paired device; lose them and every device has to be
  # re-paired, which on a headless box in a cupboard means physically getting
  # at it. Found by the weekly state report, which is what it exists for.
  # (The `cache/` subdirectory under the adapter is just scan results and is
  # disposable — it is the per-device `info` files that matter.)
  kodama.persist = [ "bluetooth" ];

  # UHD 630 iGPU — QSV/VAAPI for Immich video transcoding once the library
  # moves here off the RTX 3070. See notes/homelab/homelab.md decision 10.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };

  # ── Base tooling ────────────────────────────────────────────────────────
  # Deliberately thin. Anything user-facing belongs in home/kodama.nix;
  # this list is what a root shell needs when something is broken.
  environment.systemPackages = with pkgs; [
    git
    vim
    smartmontools # `smartctl -a /dev/nvme0n1` — the PM991 numbers AMT can't read
    pciutils
    usbutils
    lm_sensors
  ];

  # ── Nix ─────────────────────────────────────────────────────────────────
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "kasasagi" ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nixpkgs.config.allowUnfree = true;

  # First install release. Do NOT bump this on upgrade — it pins stateful
  # defaults (database versions, service layouts) to what was set up here.
  system.stateVersion = "26.05";
}

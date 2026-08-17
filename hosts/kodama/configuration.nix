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

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
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

  # Bluetooth — the M920q has an Intel 9560 (Jefferson Peak) on the WiFi card.
  # Home Assistant uses it for BLE sensors and presence detection, and it
  # reaches the adapter over the host D-Bus socket bind-mounted into the
  # container. Without this the adapter shows as hci0 but bluetooth.service is
  # `not-found`, so HA discovers Bluetooth and then cannot use it.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

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

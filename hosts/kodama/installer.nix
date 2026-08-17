{ pkgs, modulesPath, ... }:
{
  # Custom NixOS installer image for installing kodama entirely over AMT.
  #
  # Why not the stock ISO: the stock installer gives you a local console and
  # nothing else, so the install depends on a keyboard. kodama's AMT KVM
  # keyboard is unreliable, which would make that install miserable.
  #
  # This image starts sshd with the key already authorised, so the sequence is:
  #   1. IDE-R this ISO from MeshCommander  (media, no USB stick)
  #   2. AMT remote boot → CD               (already proven working on this box)
  #   3. ssh root@<installer-ip> from kasasagi
  #   4. run the install in a real terminal
  #
  # The KVM is then only needed to read one DHCP address off the screen — and
  # reading is exactly the part of KVM that does work.
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  # ── The point of the whole image ────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILQ8dCAsB8WDDR9lqR99WHzSgCbTOZJoPD1g5Jf12CIP kasasagi@wsl"
  ];

  # No `networking.useDHCP` here on purpose: the installer image already
  # enables NetworkManager, which sets useDHCP = false and does DHCP itself.
  # Setting it produced a hard option conflict, not an override.
  # Fixed name makes it findable without hunting for the address, when mDNS works.
  networking.hostName = "kodama-installer";

  # ── Belt and braces: serial console on top of SSH ───────────────────────
  # If networking somehow fails, AMT Serial-over-LAN still gives a usable
  # text console. SOL is a plain serial stream rather than the emulated
  # USB-HID path that KVM uses, so its keyboard is not affected by the KVM
  # problem. 115200 8N1 matches the M920q BIOS console-redirection default.
  boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty0" ];

  # ⚠️ REQUIRED, and not on by default in the stock installer image.
  # Both install steps are flake-based — building disko's script from the
  # locked input, and `nixos-install --flake` — so without this the install
  # fails at the point where it is most annoying to discover.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # This image ships NO nixpkgs channel (unlike the official release ISO,
  # which includes one for offline installs). Nothing here needs it — the
  # flake is copied over by rsync and the box has network — but `nix-shell -p`
  # will not work, so put anything needed during the install in the list below.
  # Tools wanted during the install itself.
  environment.systemPackages = with pkgs; [
    parted
    gptfdisk
    smartmontools
    pciutils
    tmux # so a dropped SSH session doesn't kill nixos-install
    git
  ];

  # Not strictly needed to install, but makes the installer reachable from
  # anywhere if the LAN side misbehaves. Requires `tailscale up` by hand.
  services.tailscale.enable = true;

  # ISO metadata. `image.fileName`, not the old `isoImage.isoName` — that
  # option is renamed in current nixpkgs and silently left the file named
  # nixos-minimal-*.iso.
  image.fileName = "nixos-kodama-installer.iso";
  isoImage.volumeID = "KODAMA_INST";
}

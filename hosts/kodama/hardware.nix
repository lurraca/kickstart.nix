{ config, lib, modulesPath, ... }:
{
  # Hand-written hardware config for the ThinkCentre M920q.
  #
  # There is no `nixos-generate-config` output to copy back and no
  # `fileSystems` block here — **disko owns the filesystems** (see disk.nix),
  # which is what removed the fake-UUID placeholder this file used to be.
  #
  # What remains is only what a hardware scan would have contributed: which
  # drivers the initrd needs to find the root device.
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # xhci_pci: USB3 controller. nvme: the PM991 root device. ahci/sd_mod/
  # usb_storage: kept so a USB disk or an AMT IDE-R virtual CD is reachable
  # from the initrd during recovery.
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ]; # i7-9700T — VT-x for future VMs
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
}

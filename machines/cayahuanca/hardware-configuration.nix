{ config, lib, pkgs, nixos-hardware, ... }:

{
  imports = [
    nixos-hardware.nixosModules.lenovo-thinkpad-t15-gen1
  ];

  boot.initrd.availableKernelModules =
    [ "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  networking.useDHCP = lib.mkDefault true;

  hardware.enableRedistributableFirmware = true;

  # TODO: tlp, powertop
  # tlp: stop charge at 80
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";


  # https://www.kernel.org/doc/html/v5.4/admin-guide/laptops/thinkpad-acpi.html
  # https://ibm-acpi.sourceforge.net/

  # TODO: aliases for `/proc/acpi/ibm/led`
  #   -  0: power button
  #   -  7: ???
  #   - 10: thinkpad "i" lid light
  #   - 12: ???
  #
  # or maybe a setuid binary that toggles the leds
}

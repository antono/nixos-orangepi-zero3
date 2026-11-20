# Hardware support for the Orange Pi Zero3 (Allwinner H618).
#
# Everything here is mainline: the board's device tree has been in Linux since
# 6.6, and nixpkgs ships U-Boot with `orangepi_zero3_defconfig` plus the H616
# TF-A (the H618 needs no extra TF-A support). Optional extras that are not
# mainline live in ./expansion-board.nix and ./wireless.nix; CPU frequency
# scaling is opt-in in ./cpufreq.nix.
{ lib, pkgs, ... }:
{
  imports = [
    ./cpufreq.nix
    ./expansion-board.nix
    ./wireless.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # U-Boot picks the DTB itself (fdtfile=allwinner/sun50i-h618-orangepi-zero3.dtb);
  # naming it here lets NixOS apply device tree overlays to the right file.
  hardware.deviceTree.name = "allwinner/sun50i-h618-orangepi-zero3.dtb";
  hardware.deviceTree.filter = "sun50i-h618-orangepi-zero3.dtb";

  hardware.deviceTree.overlays = [
    {
      # U-Boot leaves the USB-A port's load switch (PC16) off, so keep its
      # VBUS regulator on permanently instead of relying on the PHY driver.
      name = "orangepi-zero3-usb1-vbus";
      dtsText = ''
        /dts-v1/;
        /plugin/;
        / { compatible = "xunlong,orangepi-zero3"; };
        &reg_usb1_vbus { regulator-always-on; };
      '';
    }
  ];

  # The debug UART is the 3-pin header next to the USB-C port.
  boot.kernelParams = [
    "console=ttyS0,115200n8"
    "console=tty0"
  ];

  # The microSD controller (sunxi-mmc) is built into the kernel.
  boot.initrd.availableKernelModules = [
    "usb_storage"
    "uas"
  ];

  # The U-Boot build used by the SD image module and for re-flashing
  # (see README). Exposed as an option so it can be swapped or patched.
  system.build.uboot = pkgs.ubootOrangePiZero3;

  # The board has no RTC battery and 1-4 GiB of RAM: keep the defaults lean.
  services.timesyncd.enable = lib.mkDefault true;
  zramSwap.enable = lib.mkDefault true;
}

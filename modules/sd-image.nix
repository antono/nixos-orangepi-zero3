# Bootable microSD image for the Orange Pi Zero3.
#
# Allwinner's boot ROM loads the SPL from a fixed offset of 8 KiB on the card,
# so U-Boot is written into the gap before the first partition. The FAT
# "firmware" partition that the generic sd-image module creates is unused on
# this board (no Raspberry Pi firmware) and is kept tiny.
{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [ "${modulesPath}/installer/sd-card/sd-image.nix" ];

  image.baseName = "nixos-orangepi-zero3";

  # The generic sd-image module targets "any ARM board": it pulls in every
  # initrd driver and all of linux-firmware (~800 MiB). This image is for one
  # board whose needed drivers are listed in orangepi-zero3.nix and which uses
  # no firmware blobs.
  hardware.enableAllHardware = lib.mkForce false;

  sdImage = {
    firmwareSize = lib.mkDefault 16;
    populateFirmwareCommands = "";
    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
    '';
    postBuildCommands = ''
      dd if=${config.system.build.uboot}/u-boot-sunxi-with-spl.bin of=$img bs=1024 seek=8 conv=notrunc
    '';
  };
}

# NixOS on the Orange Pi Zero3

A small flake that builds a bootable NixOS microSD image for the
[Orange Pi Zero3](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/details/Orange-Pi-Zero-3.html)
(Allwinner H618), using **only upstream components**:

- Linux from nixpkgs (the board's device tree has been in mainline since 6.6)
- U-Boot from nixpkgs (`ubootOrangePiZero3`, `orangepi_zero3_defconfig`)
- TF-A for the H616 (the H618 needs no extra TF-A support)

No vendor kernel, no patches, so almost everything comes from
`cache.nixos.org`.

## Status

| Feature                  | Status                                          |
| ------------------------ | ----------------------------------------------- |
| Boot from microSD        | Image builds and is laid out correctly; **not yet booted on hardware** |
| Serial console (ttyS0)   | Enabled, 115200 8N1                             |
| Ethernet                 | Mainline driver (emac + Motorcomm YT8531 PHY)   |
| USB                      | Mainline                                        |
| Wi-Fi / Bluetooth        | **Not supported**: Unisoc UWE5622 has no mainline driver |
| HDMI                     | Not tested                                      |

## Build the image

You need an `aarch64-linux` builder: a native ARM machine, or an x86_64
NixOS host with `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];`, used
directly or as a remote builder.

```bash
nix build github:<owner>/nixos-orangepi-zero3#packages.aarch64-linux.sdImage
```

The result is `result/sd-image/nixos-orangepi-zero3-*.img.zst`.

## Flash

```bash
zstdcat result/sd-image/*.img.zst | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

U-Boot is written at an offset of 8 KiB, before the first partition, as the
Allwinner boot ROM expects. The root partition grows to fill the card on first
boot.

## First boot

- The `nixos` user has no password and is logged in automatically on the
  console (serial or HDMI), the same as the official installer images.
- SSH is on, but key-only. Since the `nixos` user has no key yet, either log in
  on the serial console first, or build your own image with your key (below).
- Ethernet uses DHCP; the board announces itself as `orangepi-zero3.local`.

## Use it from your own flake

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.orangepi-zero3.url = "github:<owner>/nixos-orangepi-zero3";
  inputs.orangepi-zero3.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, orangepi-zero3, ... }: {
    nixosConfigurations.my-board = nixpkgs.lib.nixosSystem {
      modules = [
        orangepi-zero3.nixosModules.orangepi-zero3 # board support
        orangepi-zero3.nixosModules.sd-image       # only to build an image
        {
          networking.hostName = "my-board";
          services.openssh.enable = true;
          users.users.me = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];
          };
          system.stateVersion = "26.05";
        }
      ];
    };
  };
}
```

Then build `nixosConfigurations.my-board.config.system.build.sdImage`. Once
the board runs, deploy updates with `nixos-rebuild switch --flake .#my-board
--target-host me@my-board` from a faster machine, instead of building on the
board itself.

## Updating U-Boot on a running board

```bash
nix build .#packages.aarch64-linux.uboot
sudo dd if=result/u-boot-sunxi-with-spl.bin of=/dev/mmcblk0 bs=1024 seek=8 conv=notrunc,fsync
```

## Outputs

| Output                                   | What it is                               |
| ---------------------------------------- | ---------------------------------------- |
| `nixosModules.orangepi-zero3` (default)  | Board support: bootloader, DTB, console  |
| `nixosModules.sd-image`                  | SD image with U-Boot embedded            |
| `nixosConfigurations.orangepi-zero3`     | Minimal headless first-boot system       |
| `packages.aarch64-linux.sdImage`         | The image above                          |
| `packages.aarch64-linux.uboot`           | U-Boot used in the image                 |

## License

MIT

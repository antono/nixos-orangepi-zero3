# NixOS on the Orange Pi Zero3

A small flake that builds a bootable NixOS microSD image for the
[Orange Pi Zero3](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/details/Orange-Pi-Zero-3.html)
(Allwinner H618). The base system uses **only upstream components**:

- Linux from nixpkgs (the board's device tree has been in mainline since 6.6)
- U-Boot from nixpkgs (`ubootOrangePiZero3`, `orangepi_zero3_defconfig`)
- TF-A for the H616 (the H618 needs no extra TF-A support)

No vendor kernel and no kernel patches, so almost everything comes from
`cache.nixos.org`. On-board Wi-Fi and Bluetooth have no mainline driver; they
are optional and use out-of-tree modules plus device tree overlays (see
[Wi-Fi and Bluetooth](#wi-fi-and-bluetooth)).

## Status

| Feature                  | Status                                          |
| ------------------------ | ----------------------------------------------- |
| Boot from microSD        | Boots on hardware (Orange Pi Zero3)             |
| Serial console (ttyS0)   | Enabled, 115200 8N1                             |
| Ethernet                 | Mainline driver (emac + Motorcomm YT8531 PHY); works on hardware |
| USB (Type-A, Type-C OTG) | Mainline                                        |
| CPU frequency scaling    | Mainline, up to 1.5 GHz                         |
| Thermal sensors          | Mainline                                        |
| GPU (Mali-G31, Panfrost) | Mainline                                        |
| Analog audio             | Mainline                                        |
| Wi-Fi / Bluetooth        | Out-of-tree driver, **off by default** in the image. On hardware the chip probes and joins a WPA2 network, but **the board then hard-hangs within seconds to minutes**; needs further investigation (see [Wi-Fi and Bluetooth](#wi-fi-and-bluetooth)) |
| Expansion board (USB, IR) | Opt-in overlay; **not yet tested on hardware** |
| HDMI                     | **Not supported**: the H616 HDMI patches are not in mainline yet |
| Hardware video decoding  | Not supported (Cedrus is not enabled for the H616) |

## Build the image

You need an `aarch64-linux` builder: a native ARM machine, or an x86_64
NixOS host with `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];`, used
directly or as a remote builder.

```bash
nix build github:antono/nixos-orangepi-zero3#packages.aarch64-linux.sdImage
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
  serial console, the same as the official installer images.
- SSH is on, but key-only. Since the `nixos` user has no key yet, either log in
  on the serial console first, or build your own image with your key (below).
- Ethernet uses DHCP; the board announces itself as `orangepi-zero3.local`.

## Wi-Fi and Bluetooth

The on-board chip is a Unisoc UWE5622 (also sold as AW859A) on SDIO. It has
no mainline driver, so `hardware.orangepi-zero3.wifi.enable` and
`hardware.orangepi-zero3.bluetooth.enable` add:

- the out-of-tree [uwe5622-ng](https://github.com/LinuxMint-User/uwe5622-ng)
  modules (SDIO transport, Wi-Fi, Bluetooth tty, MAC address helper), built
  against the system's kernel;
- a device tree overlay with the SDIO slot, its supplies and power sequence,
  from [orangepi-zero-3-dtb-neo](https://github.com/LinuxMint-User/orangepi-zero-3-dtb-neo);
- the firmware from [Orange Pi](https://github.com/orangepi-xunlong/firmware),
  with the Bluetooth `feature_set` fix the driver's README asks for;
- `hciattach_opi`, built from Orange Pi's sources, as the
  `uwe5622-bluetooth` service that brings up `hci0`.

The firmware is unfree, so allow it in your configuration:

```nix
nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "uwe5622-firmware";
```

**Known issue:** on hardware the chip probes and joins a WPA2 network, but the
board then hard-hangs within seconds to minutes. The cause is not found yet and
**needs further investigation**: the journal shows no oops or panic before the
hang, so the next step is to capture the kernel log on the serial console
(ttyS0, 115200) while it happens. Help is welcome. So the prebuilt image ships with Wi-Fi and Bluetooth **off**. To try them,
build your own image with:

```nix
hardware.orangepi-zero3.wifi.enable = true;
hardware.orangepi-zero3.bluetooth.enable = true;
networking.wireless.enable = true;
```

`wpa_supplicant` then runs with no networks. To join one:

```bash
sudo wpa_cli add_network
sudo wpa_cli set_network 0 ssid '"MyNetwork"'
sudo wpa_cli set_network 0 psk '"password"'
sudo wpa_cli enable_network 0
sudo wpa_cli save_config
```

## Expansion board

The 13-pin expansion board adds two USB 2.0 ports and an IR receiver, which
are described but disabled in the mainline device tree. Enable them with:

```nix
hardware.orangepi-zero3.expansionBoard.enable = true;
```

## Use it from your own flake

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.orangepi-zero3.url = "github:antono/nixos-orangepi-zero3";
  inputs.orangepi-zero3.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, orangepi-zero3, ... }: {
    nixosConfigurations.my-board = nixpkgs.lib.nixosSystem {
      modules = [
        orangepi-zero3.nixosModules.orangepi-zero3 # board support
        orangepi-zero3.nixosModules.sd-image       # only to build an image
        ({ lib, ... }: {
          networking.hostName = "my-board";
          hardware.orangepi-zero3.wifi.enable = true;
          nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "uwe5622-firmware";
          services.openssh.enable = true;
          users.users.me = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];
          };
          system.stateVersion = "26.05";
        })
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
| `nixosModules.orangepi-zero3` (default)  | Board support: bootloader, DTB, console, optional Wi-Fi/BT and expansion board |
| `nixosModules.sd-image`                  | SD image with U-Boot embedded            |
| `nixosConfigurations.orangepi-zero3`     | Minimal headless first-boot system       |
| `packages.aarch64-linux.sdImage`         | The image above                          |
| `packages.aarch64-linux.uboot`           | U-Boot used in the image                 |
| `packages.aarch64-linux.uwe5622-ng`      | Wi-Fi/BT kernel modules for the image's kernel |
| `packages.aarch64-linux.uwe5622-firmware` | Wi-Fi/BT firmware (unfree)              |
| `packages.aarch64-linux.hciattach-opi`   | Bluetooth attach tool                    |

## License

MIT for this repository. The packaged driver and `hciattach_opi` are GPL;
the UWE5622 firmware is proprietary and redistributed as Orange Pi and Armbian
do.

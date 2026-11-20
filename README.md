# NixOS on the Orange Pi Zero3

A bootable NixOS microSD image and a NixOS module for the
[Orange Pi Zero3](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/details/Orange-Pi-Zero-3.html)
(Allwinner H618).

Mainline Linux and U-Boot from nixpkgs, no vendor kernel, no patches, so
almost everything comes from `cache.nixos.org`.

## Status

**Works on hardware**

- Boot from microSD (U-Boot from nixpkgs, root grows to fill the card)
- Ethernet with DHCP
- SSH

**Mainline, not tested on hardware yet**

- Serial console (ttyS0, 115200 8N1)
- USB (Type-A, Type-C OTG)
- Thermal sensors, GPU (Mali-G31, Panfrost), analog audio
- Expansion board (2× USB, IR), opt-in
- Bluetooth, opt-in

**Does not work**

- **Wi-Fi.** The chip joins a network, then the board hard-hangs within
  seconds to minutes. Off by default. [Needs investigation](#wi-fi-and-bluetooth).
- **CPU frequency scaling.** A frequency switch oopsed after ~13 h and
  stalled all microSD I/O. Off by default: the CPU stays at the clock U-Boot
  sets. Opt in with `hardware.orangepi-zero3.cpufreq.enable`;
  details in [`modules/cpufreq.nix`](modules/cpufreq.nix). Needs investigation.
- **HDMI.** The H616 HDMI patches are not in mainline yet.
- **Hardware video decoding.** Cedrus is not enabled for the H616.

## Install

### 1. Build the image

Needs an `aarch64-linux` builder: an ARM machine, or an x86_64 NixOS host
with `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];`.

```bash
nix build github:antono/nixos-orangepi-zero3#packages.aarch64-linux.sdImage
```

The image is `result/sd-image/nixos-orangepi-zero3-*.img.zst`.

### 2. Flash it

Unmount every partition of the card first, then:

```bash
zstdcat result/sd-image/*.img.zst | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

### 3. Boot

- Plug in Ethernet and power. The board takes an address over DHCP and
  announces itself as `orangepi-zero3.local`.
- The `nixos` user has no password and is logged in automatically on the
  serial console.
- SSH is key-only, and the prebuilt image has no key. Log in on the serial
  console, or build your own image with your key (next section).

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

Build the image:

```bash
nix build .#nixosConfigurations.my-board.config.system.build.sdImage
```

Once the board runs, deploy updates from a faster machine instead of building
on the board:

```bash
nixos-rebuild switch --flake .#my-board --target-host me@my-board --sudo
```

## Wi-Fi and Bluetooth

The on-board Unisoc UWE5622 has no mainline driver. The module adds the
out-of-tree [uwe5622-ng](https://github.com/LinuxMint-User/uwe5622-ng)
driver, a device tree overlay, the vendor firmware and `hciattach_opi`.

**Known issue.** On hardware the chip probes and joins a WPA2 network, but the
board then hard-hangs within seconds to minutes. The journal shows no oops or
panic before the hang. The next step is to capture the kernel log on the
serial console while it happens. Help is welcome.

To try it anyway:

```nix
{ lib, ... }: {
  hardware.orangepi-zero3.wifi.enable = true;
  hardware.orangepi-zero3.bluetooth.enable = true;
  networking.wireless.enable = true;
  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "uwe5622-firmware";
}
```

## Expansion board

The 13-pin expansion board adds two USB 2.0 ports and an IR receiver:

```nix
hardware.orangepi-zero3.expansionBoard.enable = true;
```

## Update U-Boot on a running board

```bash
nix build .#packages.aarch64-linux.uboot
sudo dd if=result/u-boot-sunxi-with-spl.bin of=/dev/mmcblk0 bs=1024 seek=8 conv=notrunc,fsync
```

## Outputs

| Output                                    | What it is                          |
| ----------------------------------------- | ----------------------------------- |
| `nixosModules.orangepi-zero3` (default)   | Board support                       |
| `nixosModules.sd-image`                   | SD image with U-Boot embedded       |
| `nixosConfigurations.orangepi-zero3`      | Minimal headless first-boot system  |
| `packages.aarch64-linux.sdImage`          | The prebuilt image (default)        |
| `packages.aarch64-linux.uboot`            | U-Boot                              |
| `packages.aarch64-linux.uwe5622-ng`       | Wi-Fi/BT kernel modules             |
| `packages.aarch64-linux.uwe5622-firmware` | Wi-Fi/BT firmware (unfree)          |
| `packages.aarch64-linux.hciattach-opi`    | Bluetooth attach tool               |

## License

MIT. The packaged driver and `hciattach_opi` are GPL; the UWE5622 firmware is
proprietary and redistributed as Orange Pi and Armbian do.

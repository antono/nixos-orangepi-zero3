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
- Wi-Fi (UWE5622), opt-in: joined a WPA2 network and ran 35+ minutes of
  continuous downloads (about 12 MB/s, 16 GB) without a hang, with CPU
  frequency scaling off. See [Wi-Fi and Bluetooth](#wi-fi-and-bluetooth).

**Detected on hardware, function not exercised** (checked on a running board,
2026-11-21; nothing was plugged in or listened to)

- Serial console: `ttyS0` is a 16550A at 115200 8N1 and `serial-getty` runs on
  it. Output on the 3-pin header itself was not looked at.
- USB: the EHCI/OHCI host controllers come up (480 Mbit/s and 12 Mbit/s root
  hubs) and the Type-C OTG controller registers a UDC. No device was attached,
  so no enumeration or data transfer was tried.
- Thermal sensors: four zones (cpu, gpu, ve, ddr) report about 48 °C idle.
- Analog audio: ALSA shows the `sun4i-codec` card with one playback device. No
  sound was played.
- GPU (Mali-G31, Panfrost): **flaky**. The driver bound (`mali-g31 id 0x7093`,
  `/dev/dri/renderD128`) on 2 of the last 7 boots and failed with `error -110`
  on the other 5. Rendering was not tried. Cause not established.

**Mainline, not tested on hardware at all**

- Expansion board (2× USB, IR), opt-in: not attached.
- Bluetooth, opt-in.

**Does not work**

- **CPU frequency scaling.** A frequency switch oopsed after ~13 h and
  stalled all microSD I/O. Off by default: the CPU stays at the clock U-Boot
  sets (1.008 GHz in the clock tree). Opt in with `hardware.orangepi-zero3.cpufreq.enable`;
  details in [`modules/cpufreq.nix`](modules/cpufreq.nix). The earlier Wi-Fi
  hangs were probably this (see below). Needs investigation.
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

**Status.** With CPU frequency scaling off (the default), Wi-Fi was stable on
hardware: associated, got a DHCP lease, and ran a 25 minute loop of 100 MB
downloads on top of 10 minutes of use, 16 GB in total, with no disconnect,
oops or hang, and the kernel log (sent over netconsole) was clean. Before that,
the board hard-hung within seconds to minutes of joining a network, with no
oops or panic in the journal, and cpufreq was on. A cpufreq oops on a frequency
switch is also what froze the board later (see [`modules/cpufreq.nix`](modules/cpufreq.nix)),
and network load drives frequency switches, so the two were probably the same
problem. **Not proven**: the check that would prove it, Wi-Fi with cpufreq on
again, was not run because it can freeze the board. Wi-Fi stays off by default
in this repo's modules; the board this was developed on runs with it on.

Notes from testing:

- The first association attempt after boot was rejected by the access point
  (status 1); the second succeeded. Cause not established.
- Not tested: Bluetooth, WPA3 (the driver has no SAE support), long uptimes
  beyond the 35 minutes above.
- With both Ethernet and Wi-Fi up, the NixOS reverse-path filter drops replies
  that arrive on the interface that is not the default route, so
  `ping -I wlan0 <internet host>` fails even though Wi-Fi works. To test
  Wi-Fi, make its route the preferred one (`ip route add default via <gw> dev
  wlan0 metric 100`).
- To try Wi-Fi without risking a boot loop, put it in a NixOS `specialisation`:
  it becomes a separate extlinux entry and the default entry stays without
  Wi-Fi. The hardware watchdog (`systemd.settings.Manager.RuntimeWatchdogSec`)
  resets a frozen board on its own.

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

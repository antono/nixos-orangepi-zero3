# Out-of-tree kernel modules for the Unisoc UWE5622 Wi-Fi/Bluetooth chip:
# SDIO transport and firmware loader, Wi-Fi (cfg80211), Bluetooth H4 tty and
# the MAC address helper. Call with `linuxPackages.callPackage`.
{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
  kernelModuleMakeFlags,
  uwe5622-firmware,
}:
stdenv.mkDerivation {
  pname = "uwe5622-ng";
  version = "0-unstable-2026-10-29-${kernel.version}";

  src = fetchFromGitHub {
    owner = "LinuxMint-User";
    repo = "uwe5622-ng";
    rev = "aa6879b7a5db65b34aa49de630f2725a6a7b5d57";
    hash = "sha256-c0+wURYzqxj9ABSnDDIdWzJi8ozcUwqk3CichDtEi7A=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;
  hardeningDisable = [
    "pic"
    "format"
  ];

  makeFlags = kernelModuleMakeFlags ++ [
    "-C"
    "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "CROSS_COMPILE=${stdenv.cc.targetPrefix}"
  ];

  # Switches the top-level Makefile normally exports to the per-directory
  # Kbuild files. CONFIG_AW_BIND_VERIFY stays unset: it needs vendor crypto
  # patches that mainline does not have.
  env = {
    CONFIG_AW_WIFI_DEVICE_UWE5622 = "y";
    CONFIG_TTY_OVERY_SDIO = "m";
    CONFIG_SUNXI_ADDR_MGT = "m";
    # The Wi-Fi driver opens its board .ini by path instead of through
    # request_firmware(). NixOS has no /lib/firmware, and the files under
    # /run/current-system/firmware may be zstd-compressed, so point it at the
    # package itself. (wcnmodem.bin does go through request_firmware().)
    UNISOC_WIFI_CUS_CONFIG = "${uwe5622-firmware}/lib/firmware";
  };

  # Upstream builds each directory separately with modpost in "warn only"
  # mode. Build them in dependency order instead and feed each one the
  # symbols exported by the previous ones, so missing symbols stay errors.
  buildPhase = ''
    runHook preBuild
    export UNISOC_BSP_INCLUDE=$PWD/unisocwcn/include
    extra=
    for d in unisocwcn addr_mgt unisocwifi tty-sdio; do
      make $makeFlags -j$NIX_BUILD_CORES M=$PWD/$d \
        KBUILD_EXTRA_SYMBOLS="$extra" modules
      extra="$extra $PWD/$d/Module.symvers"
    done
    runHook postBuild
  '';

  dontPatchELF = true; # kernel modules, not executables

  installPhase = ''
    runHook preInstall
    dest=$out/lib/modules/${kernel.modDirVersion}/extra/uwe5622
    mkdir -p $dest
    for m in unisocwcn/uwe5622_bsp_sdio unisocwifi/sprdwl_ng tty-sdio/sprdbt_tty addr_mgt/sunxi_addr; do
      install -m 644 $m.ko $dest/
    done
    runHook postInstall
  '';

  meta = {
    description = "Out-of-tree Unisoc UWE5622 Wi-Fi/Bluetooth driver for mainline Linux";
    homepage = "https://github.com/LinuxMint-User/uwe5622-ng";
    license = lib.licenses.gpl2Only;
    platforms = [ "aarch64-linux" ];
  };
}

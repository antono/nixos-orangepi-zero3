# `hciattach_opi`: BlueZ's hciattach with Orange Pi's Unisoc ("sprd") support.
# It loads the Bluetooth configuration into the UWE5622 and attaches the
# /dev/ttyBT0 channel exposed by the sprdbt_tty module as hci0.
{
  lib,
  stdenv,
  fetchgit,
  uwe5622-firmware,
}:
stdenv.mkDerivation {
  pname = "hciattach-opi";
  version = "5.10-unstable-2026-11-06";

  src = fetchgit {
    name = "hcitools-source";
    url = "https://github.com/orangepi-xunlong/orangepi-build";
    rev = "7f24222b928eab94780f2af03289ce527e07241e";
    sparseCheckout = [ "external/cache/sources/hcitools" ];
    hash = "sha256-uxp+AhdhuaADhoAsuaCmi24zR+S/vM3iFSwr+tokUCY=";
  };
  sourceRoot = "hcitools-source/external/cache/sources/hcitools";

  postPatch = ''
    # The Bluetooth .ini files are read by path. NixOS has no /lib/firmware,
    # and /run/current-system/firmware may hold zstd-compressed copies.
    substituteInPlace hciattach_sprd.c \
      --replace-fail '"/lib/firmware"' '"${uwe5622-firmware}/lib/firmware"'
    # The sprd entry passes NULL as the protocol number; HCI_UART_H4 is the
    # same 0, and GCC 14+ rejects the pointer-to-int conversion.
    substituteInPlace hciattach.c --replace-fail \
      '"sprd",      0x0000, 0x0000, NULL,' '"sprd",      0x0000, 0x0000, HCI_UART_H4,'
    substituteInPlace rule.mk --replace-fail 'CC := gcc' 'CC := ${stdenv.cc.targetPrefix}cc'
  '';

  # Old vendor C: missing includes and loose pointer types that GCC 14+
  # turned into errors.
  env.NIX_CFLAGS_COMPILE = toString [
    "-Wno-error=implicit-function-declaration"
    "-Wno-error=incompatible-pointer-types"
    "-Wno-error=int-conversion"
  ];

  # rule.mk builds BINDIR as "$(cd $(pwd))/<abs path>", i.e. "//build/...",
  # which the linker wrapper rejects as an impure path.
  makeFlags = [ "BINDIR=output" ];

  buildFlags = [ "hciattach_opi" ];

  installPhase = ''
    runHook preInstall
    install -Dm755 output/hciattach_opi $out/bin/hciattach_opi
    runHook postInstall
  '';

  meta = {
    description = "hciattach with Unisoc UWE5622 support, from Orange Pi's build system";
    homepage = "https://github.com/orangepi-xunlong/orangepi-build";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
    mainProgram = "hciattach_opi";
  };
}

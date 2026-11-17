# Firmware and calibration files for the Unisoc UWE5622 Wi-Fi/Bluetooth chip,
# taken from Orange Pi's own firmware repository (the same files their images
# ship; Armbian carries identical copies of the Wi-Fi ones).
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  rev = "dc163b0ed2e0272d9ee31977a0e0a04884f0ae61";
  file =
    name: hash:
    fetchurl {
      url = "https://raw.githubusercontent.com/orangepi-xunlong/firmware/${rev}/${name}";
      inherit name hash;
    };
in
stdenvNoCC.mkDerivation {
  pname = "uwe5622-firmware";
  version = "0-unstable-2026-11-17";

  srcs = [
    (file "wcnmodem.bin" "sha256-EZuHzjCHVzSmdGL3KT+4/oWs8ycP6LeMl4riS+dxWoA=")
    (file "wifi_2355b001_1ant.ini" "sha256-HzxA7CRajQuZrRwjcGWX1t1QCKuAzvt7zBlW78TpOPc=")
    (file "bt_configure_pskey.ini" "sha256-WnofY/1okWIBAx1LJKEdxnrkX2zWlZULwyX7akh60Kw=")
    (file "bt_configure_rf.ini" "sha256-QEQlK679+g6IS2HUxC9NB/dKjzEhuhkj54KWjQE9YX0=")
  ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/firmware
    for f in $srcs; do
      cp $f $out/lib/firmware/$(stripHash $f)
    done

    # Stop the controller from advertising "park state" support. Otherwise
    # the kernel's Write_Default_Link_Policy fails with 0x12 and hci0 never
    # leaves HCI_SETUP (see the uwe5622-ng README).
    substituteInPlace $out/lib/firmware/bt_configure_pskey.ini \
      --replace-fail "feature_set = 0xBF, 0xFF," "feature_set = 0xBF, 0xFE,"
    runHook postInstall
  '';

  meta = {
    description = "Firmware for the Unisoc UWE5622 Wi-Fi/Bluetooth chip";
    homepage = "https://github.com/orangepi-xunlong/firmware";
    license = lib.licenses.unfreeRedistributableFirmware;
    platforms = lib.platforms.linux;
  };
}

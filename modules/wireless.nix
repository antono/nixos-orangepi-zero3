# On-board Wi-Fi and Bluetooth: Unisoc UWE5622 (sold as AW859A) on SDIO.
#
# There is no mainline driver, so this uses the out-of-tree uwe5622-ng modules,
# Orange Pi's firmware, and `hciattach_opi` for Bluetooth. The mainline device
# tree does not describe the SDIO Wi-Fi slot at all; the overlay below adds it,
# following https://github.com/LinuxMint-User/orangepi-zero-3-dtb-neo.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.orangepi-zero3;

  firmware = pkgs.callPackage ../pkgs/uwe5622-firmware.nix { };
  driver = config.boot.kernelPackages.callPackage ../pkgs/uwe5622-ng.nix {
    uwe5622-firmware = firmware;
  };
  hciattach = pkgs.callPackage ../pkgs/hciattach-opi.nix { uwe5622-firmware = firmware; };
in
{
  options.hardware.orangepi-zero3 = {
    wifi.enable = lib.mkEnableOption ''
      on-board Wi-Fi (UWE5622) through the out-of-tree uwe5622-ng driver.
      Needs unfree firmware: allow the `uwe5622-firmware` package'';
    bluetooth.enable = lib.mkEnableOption ''
      on-board Bluetooth (UWE5622). Implies `wifi.enable`, which provides the
      SDIO transport and firmware'';
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.bluetooth.enable { hardware.orangepi-zero3.wifi.enable = true; })

    (lib.mkIf cfg.wifi.enable {
      boot.extraModulePackages = [ driver ];
      # sunxi_addr loads from the device tree; the SDIO transport has no
      # device node to match, so load it and the Wi-Fi driver explicitly.
      boot.kernelModules = [
        "uwe5622_bsp_sdio"
        "sprdwl_ng"
      ];
      hardware.firmware = [ firmware ];

      hardware.deviceTree.overlays = [
        {
          name = "orangepi-zero3-uwe5622";
          dtsText = ''
            /dts-v1/;
            /plugin/;

            / { compatible = "xunlong,orangepi-zero3"; };

            &{/} {
              reg_vcc33_wifi: vcc33-wifi {
                compatible = "regulator-fixed";
                regulator-name = "vcc33-wifi";
                regulator-min-microvolt = <3300000>;
                regulator-max-microvolt = <3300000>;
                regulator-always-on;
                vin-supply = <&reg_vcc5v>;
              };

              reg_vcc_wifi_io: vcc-wifi-io {
                compatible = "regulator-fixed";
                regulator-name = "vcc-wifi-io";
                regulator-min-microvolt = <1800000>;
                regulator-max-microvolt = <1800000>;
                regulator-always-on;
                vin-supply = <&reg_vcc33_wifi>;
              };

              wifi_pwrseq: wifi-pwrseq {
                compatible = "mmc-pwrseq-simple";
                clocks = <&rtc 1>;
                clock-names = "osc32k-out";
                reset-gpios = <&pio 6 18 1>; /* PG18, GPIO_ACTIVE_LOW */
                post-power-on-delay-ms = <200>;
              };

              /* MAC addresses derived from the SoC serial number. */
              addr-mgt {
                compatible = "allwinner,sunxi-addr_mgt";
                type_addr_wifi = <0x2>;
                type_addr_bt = <0x2>;
                type_addr_eth = <0x2>;
                status = "okay";
              };
            };

            &mmc1 {
              vmmc-supply = <&reg_vcc33_wifi>;
              vqmmc-supply = <&reg_vcc_wifi_io>;
              mmc-pwrseq = <&wifi_pwrseq>;
              bus-width = <4>;
              non-removable;
              mmc-ddr-1_8v;
              status = "okay";
            };
          '';
        }
      ];
    })

    (lib.mkIf cfg.bluetooth.enable {
      boot.kernelModules = [ "sprdbt_tty" ];
      hardware.bluetooth.enable = lib.mkDefault true;
      environment.systemPackages = [ hciattach ];

      # Loads the Bluetooth configuration into the chip and attaches the
      # /dev/ttyBT0 channel from sprdbt_tty as hci0.
      systemd.services.uwe5622-bluetooth = {
        description = "Attach UWE5622 Bluetooth (hciattach_opi)";
        bindsTo = [ "dev-ttyBT0.device" ];
        after = [ "dev-ttyBT0.device" ];
        before = [ "bluetooth.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${lib.getExe hciattach} -n -s 1500000 /dev/ttyBT0 sprd";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    })
  ];
}

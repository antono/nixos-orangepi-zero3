# The 13-pin expansion board (sold with the Zero3) adds two USB 2.0 ports, an
# IR receiver and analog audio/microphone. Its USB host controllers and the IR
# receiver are described in the mainline device tree but disabled, since the
# board is optional. Analog audio is on the base board and already enabled.
{ config, lib, ... }:
let
  cfg = config.hardware.orangepi-zero3.expansionBoard;
in
{
  options.hardware.orangepi-zero3.expansionBoard.enable =
    lib.mkEnableOption "the 13-pin expansion board (USB2/USB3 ports and IR receiver)";

  config = lib.mkIf cfg.enable {
    hardware.deviceTree.overlays = [
      {
        name = "orangepi-zero3-expansion-board";
        dtsText = ''
          /dts-v1/;
          /plugin/;
          / { compatible = "xunlong,orangepi-zero3"; };
          &ehci2 { status = "okay"; };
          &ohci2 { status = "okay"; };
          &ehci3 { status = "okay"; };
          &ohci3 { status = "okay"; };
          &ir { status = "okay"; };
        '';
      }
    ];
  };
}

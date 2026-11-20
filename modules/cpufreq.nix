# CPU frequency scaling, opt-in.
#
# Off by default. On hardware (Linux 6.18.63, schedutil governor) a frequency
# switch oopsed after ~13 h of uptime:
#
#   Internal error: Oops: 0000000086000005 [#1] SMP
#   CPU: 3 PID: 322 Comm: sugov:0
#   pc : 0x80b94680        <- the kernel address with its top bits lost
#   lr : ccu_helper_wait_for_lock.part.0+0x38/0xc0
#    ccu_pll_notifier_cb <- clk_change_rate <- clk_set_rate <- dev_pm_opp_set_rate
#
# The dying thread held the clock framework's lock, so the microSD controller
# (which also changes clocks) stalled next, all I/O stopped and the board hung
# without the watchdog firing. The root cause (PLL relock, CPU voltage at the
# new operating point, or a driver bug) is not established.
#
# Without the driver the CPU stays at the clock U-Boot set.
{ config, lib, ... }:
{
  options.hardware.orangepi-zero3.cpufreq.enable =
    lib.mkEnableOption "CPU frequency scaling (sun50i-cpufreq-nvmem); known to oops on hardware, see modules/cpufreq.nix";

  # The driver matches the SoC by the machine's root compatible, not by a
  # device node, so udev never loads it on its own.
  config = lib.mkIf config.hardware.orangepi-zero3.cpufreq.enable {
    boot.kernelModules = [ "sun50i-cpufreq-nvmem" ];
  };
}

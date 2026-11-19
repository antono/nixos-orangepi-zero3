# A minimal, headless first-boot system: enough to log in over the serial
# console or the network and then switch to your own configuration.
#
# Override any of this from your own flake (see README).
{ lib, pkgs, ... }:
{
  networking.hostName = lib.mkDefault "orangepi-zero3";

  # Wired Ethernet comes up via DHCP.
  networking.useDHCP = lib.mkDefault true;

  # On-board Wi-Fi and Bluetooth through the out-of-tree driver (see
  # wireless.nix). Off by default: on hardware the board hard-hangs within
  # seconds to minutes after the driver loads, cause not found yet (see
  # README). Set these and `networking.wireless.enable` to true to try it.
  # Its firmware is unfree.
  hardware.orangepi-zero3.wifi.enable = lib.mkDefault false;
  hardware.orangepi-zero3.bluetooth.enable = lib.mkDefault false;
  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "uwe5622-firmware";

  # wpa_supplicant with no networks configured: join one at runtime with
  # `wpa_cli` (add_network / set_network / enable_network / save_config).
  networking.wireless = {
    enable = lib.mkDefault false;
    userControlled = true;
    allowAuxiliaryImperativeNetworks = true;
  };

  # Key-only SSH. Add your key with `users.users.nixos.openssh.authorizedKeys.keys`.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "no";
  };

  # Same convention as the official NixOS installer images: a passwordless
  # `nixos` user with sudo, auto-logged in on the console only.
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialHashedPassword = "";
  };
  security.sudo.wheelNeedsPassword = false;
  services.getty.autologinUser = lib.mkDefault "nixos";

  # Announce the board as orangepi-zero3.local.
  services.avahi = {
    enable = lib.mkDefault true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = with pkgs; [
    git
    htop
    vim
  ];

  # Skip ZFS: it is not needed for an SD card and slows down image builds.
  boot.supportedFilesystems.zfs = lib.mkForce false;

  documentation.nixos.enable = false;

  system.stateVersion = "26.05";
}

# A minimal, headless first-boot system: enough to log in over the serial
# console or the network and then switch to your own configuration.
#
# Override any of this from your own flake (see README).
{ lib, pkgs, ... }:
{
  networking.hostName = lib.mkDefault "orangepi-zero3";

  # Wired Ethernet comes up via DHCP. On-board Wi-Fi (Unisoc UWE5622) has no
  # mainline driver, so it is not supported here.
  networking.useDHCP = lib.mkDefault true;

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

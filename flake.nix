{
  description = "NixOS for the Orange Pi Zero3 (Allwinner H618), mainline kernel and U-Boot";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      system = "aarch64-linux";
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      nixosModules = {
        # Board support only: bootloader, device tree, console, kernel modules.
        orangepi-zero3 = ./modules/orangepi-zero3.nix;
        # Builds `config.system.build.sdImage` with U-Boot embedded.
        sd-image = ./modules/sd-image.nix;
        default = self.nixosModules.orangepi-zero3;
      };

      nixosConfigurations.orangepi-zero3 = nixpkgs.lib.nixosSystem {
        modules = [
          self.nixosModules.orangepi-zero3
          self.nixosModules.sd-image
          ./modules/first-boot.nix
        ];
      };

      packages.${system} =
        let
          inherit (self.nixosConfigurations.orangepi-zero3) config pkgs;
          uwe5622-firmware = pkgs.callPackage ./pkgs/uwe5622-firmware.nix { };
        in
        {
          sdImage = config.system.build.sdImage;
          uboot = config.system.build.uboot;
          inherit uwe5622-firmware;
          uwe5622-ng = config.boot.kernelPackages.callPackage ./pkgs/uwe5622-ng.nix {
            inherit uwe5622-firmware;
          };
          hciattach-opi = pkgs.callPackage ./pkgs/hciattach-opi.nix { inherit uwe5622-firmware; };
          default = self.packages.${system}.sdImage;
        };

      formatter = forAllSystems (s: nixpkgs.legacyPackages.${s}.nixfmt);
    };
}

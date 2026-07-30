{
  lib,
  config,
  pkgs,
  ...
}: let
  # $ uuidgen
  rootPartitionUUID = "7a684895-6ef1-4586-98d9-2d2013e98286";
in {
  imports = ["${pkgs.path}/nixos/modules/installer/sd-card/sd-image.nix"];

  boot = {
    kernelPackages = pkgs.linuxPackages;
    kernelModules = [
      "nf_tables"
      "raid1"
      "vxlan"
      "iscsi_tcp"
      "cifs"
    ];

    # Deliberately no root=/rootfstype= here. NixOS derives the root file
    # system from `fileSystems."/"`, and systemd stage 1 (the default since
    # 25.11) turns that into sysroot.mount itself. Passing root= as well makes
    # systemd-fstab-generator build sysroot.mount twice, and it rejects the
    # second definition with "Failed to create unit file
    # '/run/systemd/generator/sysroot.mount', as it already exists", which
    # fails initrd-switch-root.service and drops the machine into emergency
    # mode. See boot.initrd.systemd.root, which documents that NixOS does not
    # support naming the root file system on the kernel command line.
    kernelParams = lib.mkForce [
      "console=ttyS0,115200"
      "loglevel=7"
    ];

    loader = {
      grub.enable = lib.mkForce false;
      generic-extlinux-compatible.enable = lib.mkForce true;
    };

    supportedFilesystems = lib.mkForce [
      "vfat"
      "fat32"
      "exfat"
      "ext4"
      "btrfs"
    ];

    initrd.includeDefaultModules = lib.mkForce false;
    initrd.availableKernelModules = lib.mkForce [
      # NVMe
      "nvme"
      # SD cards and internal eMMC drives.
      "mmc_block"
    ];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };

  hardware = {
    deviceTree = {
      name = "rockchip/rk3588-turing-rk1.dtb";
      overlays = [];
    };

    firmware = [];
  };

  sdImage = {
    inherit rootPartitionUUID;
    compressImage = false;

    firmwarePartitionOffset = 16;
    firmwareSize = 10;
    populateFirmwareCommands = "";

    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
    '';

    postBuildCommands = ''
      dd if=${pkgs.ubootTuringRK1}/u-boot-rockchip.bin of=$img seek=1 bs=32k conv=notrunc
    '';
  };
}

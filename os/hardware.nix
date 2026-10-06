{
  pkgs,
  inputs,
  ...
}:
let
  monitors = builtins.toFile "monitors.xml" ''
    <monitors version="2">
      <configuration>
        <layoutmode>logical</layoutmode>
        <logicalmonitor>
          <x>0</x>
          <y>0</y>
          <scale>2</scale>
          <primary>yes</primary>
          <monitor>
            <monitorspec>
              <connector>eDP-1</connector>
              <vendor>SDC</vendor>
              <product>ATNA53JB01-0 </product>
              <serial>0x00000000</serial>
            </monitorspec>
            <mode>
              <width>2880</width>
              <height>1800</height>
              <rate>120.000</rate>
              <!-- <ratemode>variable</ratemode> -->
            </mode>
          </monitor>
        </logicalmonitor>
      </configuration>
    </monitors>
  '';
in
{
  imports = [ inputs.disko.nixosModules.default ];

  nixpkgs.hostPlatform = "x86_64-linux";

  fileSystems."/data".neededForBoot = true;
  disko.devices = {
    disk.main = {
      device = "/dev/disk/by-id/nvme-WD_PC_SN740_SDDQMQD-512G-1201_250260800158_1";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            type = "EF00";
            size = "2G";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          swap = {
            size = "63228M";
            content = {
              type = "swap";
              discardPolicy = "both";
              resumeDevice = true;
            };
          };
          data = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/data";
            };
          };
        };
      };
    };
  };

  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "vmd"
        "nvme"
        "usb_storage"
        "sd_mod"
      ];
      kernelModules = [ "xe" ];
    };
    kernelModules = [ "kvm-intel" ];
    kernelParams = [ "i915.enable_guc=3" ];
  };

  hardware = {
    cpu.intel.updateMicrocode = true;
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver # VA-API (iHD) userspace
        vpl-gpu-rt # oneVPL (QSV) runtime
        intel-compute-runtime # OpenCL (NEO) + Level Zero for Arc/Xe
      ];
      enable32Bit = true;
      extraPackages32 = with pkgs.pkgsi686Linux; [
        intel-media-driver
      ];
    };
    ipu6 = {
      enable = true;
      platform = "ipu6";
    };
  };

  services.fprintd.enable = true;

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD"; # Prefer the modern iHD backend
  };

  home-manager.sharedModules = [ { home.file.".config/monitors.xml".source = monitors; } ];
  systemd.tmpfiles.rules = [ "L+ /run/gdm/.config/monitors.xml - - - - ${monitors}" ];
}

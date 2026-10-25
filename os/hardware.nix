{
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    inputs.disko.nixosModules.default
  ];

  disko.devices = {
    disk.main = {
      device = "/dev/disk/by-path/pci-0000:04:00.0-nvme-1";
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
              # Only for hibernation; zram handles everyday swapping
              mountOptions = [ "noauto" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };

  environment.etc."xdg/monitors.xml".text = ''
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
            </mode>
          </monitor>
        </logicalmonitor>
      </configuration>
    </monitors>
  '';

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
  };

  hardware = {
    cpu.intel.updateMicrocode = true;
    graphics = {
      extraPackages = with pkgs; [
        intel-media-driver # VA-API (iHD) userspace
        vpl-gpu-rt # oneVPL (QSV) runtime
        intel-compute-runtime # OpenCL (NEO) + Level Zero for Arc/Xe
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        intel-media-driver
      ];
    };
    sensor.iio.enable = true;
    # The ISH rejects Intel's generic firmware and needs Lenovo's signed one.
    # linux-firmware links that under a product_family CRC this machine doesn't
    # match, so also offer it under the vendor-only name the kernel tries next
    firmware = [
      (pkgs.runCommand "ish-firmware-lenovo-x9-15" { } ''
        mkdir -p $out/lib/firmware/intel/ish
        cp -L ${pkgs.linux-firmware}/lib/firmware/LENOVO/ish/ish_lnlm_lenovo_x9-15_2025_5.8.0.7720.bin \
          $out/lib/firmware/intel/ish/ish_lnlm_53c4ffad.bin
      '')
    ];
  };

  # Turn the disk swap on just for hibernating, and off again on resume
  systemd.services.hibernate-swap =
    let
      device = config.disko.devices.disk.main.content.partitions.swap.content.device;
      units = [
        "systemd-hibernate.service"
        "systemd-hybrid-sleep.service"
        "systemd-suspend-then-hibernate.service"
      ];
    in
    {
      description = "Disk swap for hibernation";
      wantedBy = units;
      before = units;
      unitConfig.StopWhenUnneeded = true;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.util-linux}/bin/swapon ${device}";
        ExecStop = "${pkgs.util-linux}/bin/swapoff ${device}";
      };
    };
  # logind refuses hibernation while no swap is active, so skip its check;
  # the swap partition is twice the size of RAM, and systemd-sleep still has to
  # find it active before it hibernates
  systemd.services.systemd-logind.environment.SYSTEMD_BYPASS_HIBERNATION_MEMORY_CHECK = "1";

  services.fprintd.enable = true;
}

{
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

  # libcamera has no tuning for the webcam, so it shows the sensor's colours
  # uncorrected, which look grey. This is its generic tuning plus a colour
  # matrix that raises saturation by 1.5x, rows summing to 1 so greys stay grey
  systemd.user.services =
    let
      environment.LIBCAMERA_SIMPLE_TUNING_FILE = toString (
        pkgs.writeText "imx471.yaml" ''
          %YAML 1.1
          ---
          version: 1
          algorithms:
            - BlackLevel:
            - Awb:
            - Ccm:
                ccms:
                  - ct: 6500
                    ccm: [  1.3505, -0.2935, -0.057,
                           -0.1495,  1.2065, -0.057,
                           -0.1495, -0.2935,  1.443 ]
            - Adjust:
            - Agc:
          ...
        ''
      );
    in
    {
      pipewire = { inherit environment; };
      wireplumber = { inherit environment; };
    };

  services.fprintd.enable = true;
  # The lock screen gives up on the fingerprint after 3 tries or 30 seconds
  security.pam.services.gdm-fingerprint.rules.auth.fprintd.settings = {
    max-tries = 10;
    timeout = 60;
  };
}

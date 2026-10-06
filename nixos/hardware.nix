{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  hardware = config.hardware.facter.report.hardware;
in
with builtins;
{
  imports = [ inputs.disko.nixosModules.default ];
}
// lib.mkMerge [
  (lib.mkIf ((elemAt hardware.monitor 0).device.hex == "4206") (
    let
      monitors = toFile "monitors.xml" ''
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
      home-manager.sharedModules = [ { home.file.".config/monitors.xml".source = monitors; } ];
      systemd.tmpfiles.rules = [ "L+ /run/gdm/.config/monitors.xml - - - - ${monitors}" ];
    }
  ))
  (lib.mkIf ((elemAt hardware.graphics_card 0).driver == "xe") {
    hardware.graphics = {
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

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "iHD"; # Prefer the modern iHD backend
    };

    boot.kernelParams = [ "i915.enable_guc=3" ];
  })
  (lib.mkIf
    (builtins.any (
      d:
      d ? driver_module
      && builtins.elem d.driver_module [
        "intel_ipu7"
      ]
    ) hardware.pci)
    {
      hardware.ipu6.enable = true;
      hardware.ipu6.platform = "ipu6";
    }
  )
]

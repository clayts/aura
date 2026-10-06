set -euo pipefail
report=$(sudo nixos-facter | jq '.hardware.disk |= map(select(.class_list | contains(["usb"]) | not))')
disk=$(echo "$report" | jq -r '
	[ .hardware.disk[].unix_device_names
	    | map(select(contains("/dev/disk/by-id/")))
	    | max_by(length) // empty ]
	| if length == 1 then .[0] else "" end
')
swap=$(free -m | awk '/^Mem:/{print $2 * 2}')M
cat <<-EOF
{ ... }:
{
  fileSystems."/data".neededForBoot = true;
  disko.devices = {
    disk.main = {
      device = "$disk";
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
            size = "$swap";
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
  hardware.facter.reportPath = builtins.toFile "hardware.json" ''
    $report
  '';
}
EOF

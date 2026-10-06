set -ueo pipefail
name="$1"
clear
toilet -f future "Welcome to the Universe"
toilet -f future --gay "$name"
set -x
hardware=$(mktemp)
scan > "$hardware"
sudo nix run --experimental-features "nix-command flakes" github:nix-community/disko/latest -- --mode destroy,format,mount "$hardware"
sudo mkdir -p /mnt/data/etc/nixos/passwords
mkpasswd | sudo tee /mnt/data/etc/nixos/passwords/root > /dev/null
mkpasswd | sudo tee /mnt/data/etc/nixos/passwords/user > /dev/null
mkpasswd | sudo tee /mnt/data/etc/nixos/passwords/guest > /dev/null
sudo tee /mnt/data/etc/nixos/flake.nix > /dev/null <<-EOF
{
  inputs.universe.url = "github:clayts/universe";
  outputs = inputs: inputs.universe.nixosSystem {
    name = "$name";
    foundation = {
      system = "$systemRelease";
      homes = "$homeRelease";
    };
    hardware = ./hardware.nix;
  };
}
EOF
cat "$hardware" | sudo tee /mnt/data/etc/nixos/hardware.nix > /dev/null
sudo mkdir /mnt/nix
sudo mkdir /mnt/data/nix
sudo mount --bind /mnt/data/nix /mnt/nix
sudo nix --experimental-features "nix-command flakes" flake update --flake /mnt/data/etc/nixos
sudo nixos-install --no-channel-copy --no-root-password --flake /mnt/data/etc/nixos#"$name"
sudo mkdir -p /mnt/data/etc/NetworkManager
sudo cp -r /etc/NetworkManager/system-connections /mnt/data/etc/NetworkManager/

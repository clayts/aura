set -ueo pipefail
clear
toilet -f future "Welcome to"
toilet -f future --gay "aura"
set -x
sudo disko --mode destroy,format,mount --flake "$flake#aura"
sudo git clone https://github.com/clayts/aura /mnt/data/etc/nixos
sudo mkdir /mnt/data/etc/nixos/passwords
mkpasswd | sudo tee /mnt/data/etc/nixos/passwords/root > /dev/null
mkpasswd | sudo tee /mnt/data/etc/nixos/passwords/user > /dev/null
mkpasswd | sudo tee /mnt/data/etc/nixos/passwords/guest > /dev/null
sudo mkdir /mnt/nix
sudo mkdir /mnt/data/nix
sudo mount --bind /mnt/data/nix /mnt/nix
sudo nixos-install --no-channel-copy --no-root-password --flake /mnt/data/etc/nixos#aura
# Hand the flake to user (uid 1000, group users) only after installing:
# nix refuses to read a git repository owned by someone else, and root does
# the install. The password hashes stay with root.
sudo chown -R 1000:100 /mnt/data/etc/nixos
sudo chown -R 0:0 /mnt/data/etc/nixos/passwords
sudo mkdir -p /mnt/data/etc/NetworkManager
sudo cp -r /etc/NetworkManager/system-connections /mnt/data/etc/NetworkManager/

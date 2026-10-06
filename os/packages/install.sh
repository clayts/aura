set -ueo pipefail
clear
toilet -f future "Welcome to"
toilet -f future --gay "aura"
set -x
sudo disko --mode destroy,format,mount --flake "$flake#aura"
sudo git clone https://github.com/clayts/aura /mnt/data/etc/nixos
sudo mkdir -m 700 /mnt/data/etc/passwords
for name in root user guest; do
    echo "Password for $name"
    mkpasswd | sudo tee "/mnt/data/etc/passwords/$name" > /dev/null
done
sudo mkdir /mnt/nix
sudo mkdir /mnt/data/nix
sudo mount --bind /mnt/data/nix /mnt/nix
sudo nixos-install --no-channel-copy --no-root-password --flake /mnt/data/etc/nixos#aura
# Hand the flake to user (uid 1000, group users) only after installing:
# nix refuses to read a git repository owned by someone else, and root does
# the install.
sudo chown -R 1000:100 /mnt/data/etc/nixos
sudo mkdir -p /mnt/data/etc/NetworkManager
sudo cp -r /etc/NetworkManager/system-connections /mnt/data/etc/NetworkManager/

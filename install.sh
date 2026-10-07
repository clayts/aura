host="aura"
url="https://github.com/clayts/$host"

clear
toilet -f future "Installing..."
toilet -f future --gay "$host"

# Ask for every password before anything touches the disk
declare -A hashes
for name in root user guest; do
    while true; do
        IFS= read -rsp "Password for $name: " password && echo
        IFS= read -rsp "Confirm password for $name: " confirm && echo
        [[ $password == "$confirm" ]] && break
        echo "Passwords do not match, try again" >&2
    done
    hashes[$name]=$(mkpasswd --stdin <<<"$password")
done
unset password confirm

set -x
sudo disko --mode destroy,format,mount --flake "$flake#$host"
sudo install -d -m 700 /mnt/etc/passwords
for name in "${!hashes[@]}"; do
    sudo install -m 600 /dev/stdin "/mnt/etc/passwords/$name" <<<"${hashes[$name]}"
done
sudo nixos-install --no-channel-copy --no-root-password --flake "$flake#$host"
sudo git clone $url /mnt/etc/nixos
sudo chown -R 1000:100 /mnt/etc/nixos
sudo mkdir -p /mnt/etc/NetworkManager
sudo cp -r /etc/NetworkManager/system-connections /mnt/etc/NetworkManager/

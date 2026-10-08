host="aura"
url="https://github.com/clayts/$host"

clear
toilet -f future "Installing..."
toilet -f future --gay "$host"
set -x
# shellcheck disable=SC2154 # flake is set via runtimeEnv in flake.nix
sudo disko --mode destroy,format,mount --flake "$flake#$host"
sudo install -d -m 700 /mnt/etc/passwords
set +x # Tracing would echo the passwords
for name in root user guest; do
    while true; do
        IFS= read -rsp "Password for $name: " password && echo
        IFS= read -rsp "Confirm password for $name: " confirm && echo
        [[ $password == "$confirm" ]] && break
        echo "Passwords do not match, try again" >&2
    done
    mkpasswd --stdin <<<"$password" | sudo install -m 600 /dev/stdin "/mnt/etc/passwords/$name"
done
unset password confirm
set -x
# shellcheck disable=SC2154 # flake is set via runtimeEnv in flake.nix
sudo nixos-install --no-channel-copy --no-root-password --flake "$flake#$host"
sudo git clone $url /mnt/etc/nixos
sudo chown -R 1000:100 /mnt/etc/nixos
sudo mkdir -p /mnt/etc/NetworkManager
sudo cp -r /etc/NetworkManager/system-connections /mnt/etc/NetworkManager/

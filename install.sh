host="aura"
url="https://github.com/clayts/$host"
: "${flake:?}" # Set by runtimeEnv in flake.nix

clear
toilet -f future "Installing..."
toilet -f future --gay "$host"
set -x
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
sudo nixos-install --no-channel-copy --no-root-password --flake "$flake#$host"
# The repo is private, so clone with the GitHub login made before running this (see readme.md)
sudo install -d -o "$(id -u)" /mnt/etc/nixos
git -c credential.helper='!gh auth git-credential' clone "$url" /mnt/etc/nixos
sudo chown -R 1000:100 /mnt/etc/nixos
# Carry over that login, so the installed system can pull and push straight away
# (home-manager's programs.gh makes gh git's credential helper there)
if [[ -f ~/.config/gh/hosts.yml ]]; then
    sudo install -d -o 1000 -g 100 -m 700 /mnt/home/user
    sudo install -d -o 1000 -g 100 /mnt/home/user/.config /mnt/home/user/.config/gh
    sudo install -o 1000 -g 100 -m 600 ~/.config/gh/hosts.yml /mnt/home/user/.config/gh/hosts.yml
fi
# Carry over Wi-Fi connections made in the installer; there are none on a wired install
if [[ -d /etc/NetworkManager/system-connections ]]; then
    sudo mkdir -p /mnt/etc/NetworkManager
    sudo cp -r /etc/NetworkManager/system-connections /mnt/etc/NetworkManager/
fi

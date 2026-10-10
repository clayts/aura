host="aura"
url="https://github.com/clayts/$host"
# Set by runtimeEnv in flake.nix
: "${flake:?}" "${rev?}" "${disk:?}" "${diskPassword:?}" "${tpmKey:?}" "${installedTpmKey:?}" "${pkiBundle:?}" "${esp:?}"

efivar() {
    # A variable's 4 attribute bytes are followed by its value
    od -An -tu1 -j4 -N1 "/sys/firmware/efi/efivars/$1-8be4df61-93ca-11d2-aa0d-00e098032b8c" 2>/dev/null | tr -d ' '
}

# Sets $password
ask_password() {
    local confirm
    while true; do
        IFS= read -rsp "Password for $1: " password && echo
        IFS= read -rsp "Confirm password for $1: " confirm && echo
        [[ $password == "$confirm" ]] && return
        echo "Passwords do not match, try again" >&2
    done
}

clear
toilet -f future "Installing..."
toilet -f future --gay "$host"

if [[ ! -d /sys/firmware/efi ]]; then
    echo "Boot the installer in UEFI mode" >&2
    exit 1
fi
if [[ ! -b $disk ]]; then
    echo "$disk not found" >&2
    exit 1
fi
if [[ ! -e /dev/tpmrm0 ]]; then
    echo "No TPM found, so the disk will ask for its password at every boot" >&2
fi
# The install's Secure Boot keys can only be enrolled while the firmware is in Setup Mode
if [[ $(efivar SetupMode) != 1 ]]; then
    echo "The firmware isn't in Secure Boot Setup Mode. In its settings, set a supervisor password,"
    echo "turn Secure Boot on and reset it to Setup Mode, then run this again."
    read -rp "Reboot into the firmware settings? Answer n to install anyway and set up Secure Boot later [Y/n] " answer
    if [[ $answer != [nN]* ]]; then
        systemctl reboot --firmware-setup
        exit
    fi
fi

read -rp "This erases everything on $disk. Type 'yes' to continue: " answer
[[ $answer == yes ]] || exit 1

sudo install -d -m 700 "$(dirname "$diskPassword")" "$(dirname "$tpmKey")"
trap 'sudo rm -f "$diskPassword" "$tpmKey"' EXIT

# A drive keeps the OPAL admin password it was first set up with until it's
# factory reset, so a reinstall keeps the previous install's disk password,
# which is that admin password
password=""
mapfile -t devices < <(lsblk -lnpo NAME "$disk")
for device in "${devices[@]}"; do
    header=$(sudo cryptsetup luksDump "$device" 2>/dev/null) || continue
    [[ $header == *"HW OPAL"* ]] || continue
    echo "$disk holds a previous install encrypted by the drive, whose disk password the new install keeps."
    while true; do
        IFS= read -rsp "Its disk password, or nothing to factory reset the drive with the PSID on its label: " password && echo
        if [[ -n $password ]]; then
            # Checks the password while erasing the previous install
            sudo cryptsetup erase -q "$device" <<<"$password" && break
        else
            IFS= read -rp "PSID: " psid
            sudo cryptsetup erase -q --hw-opal-factory-reset "$device" <<<"$psid" && break
        fi
        echo "That didn't work, try again" >&2
    done
    break
done
[[ -n $password ]] || ask_password "the disk"
printf '%s' "$password" | sudo install -m 600 /dev/stdin "$diskPassword"
declare -A hashes
for name in root user guest; do
    ask_password "$name"
    hashes[$name]=$(mkpasswd --stdin <<<"$password")
done
unset password

head -c 64 /dev/urandom | sudo install -m 600 /dev/stdin "$tpmKey"
set -x
# Reuses any keys this installer session already made, and maybe enrolled
sudo sbctl create-keys
if ! sudo disko --mode destroy,format,mount --yes-wipe-all-disks --flake "$flake#$host"; then
    echo "Formatting failed. A drive set up for hardware encryption by something else needs a factory reset first:" >&2
    echo "  sudo cryptsetup erase --hw-opal-factory-reset $disk" >&2
    echo "That asks for the PSID on the drive's label. Some drives then need a power cycle." >&2
    exit 1
fi
sudo install -d -m 700 /mnt/etc/passwords "/mnt$(dirname "$installedTpmKey")"
sudo install -m 400 "$tpmKey" "/mnt$installedTpmKey"
sudo mkdir -p "/mnt$pkiBundle" "/mnt$esp/loader/keys/auto"
sudo cp -a /var/lib/sbctl/. "/mnt$pkiBundle"
# systemd-boot enrolls these whenever the firmware is in Setup Mode
sudo env -C "/mnt$esp/loader/keys/auto" sbctl enroll-keys --microsoft --export auth
set +x # Tracing would echo the password hashes
for name in root user guest; do
    sudo install -m 600 /dev/stdin "/mnt/etc/passwords/$name" <<<"${hashes[$name]}"
done
set -x
sudo nixos-install --no-channel-copy --no-root-password --flake "$flake#$host"
sudo git clone "$url" /mnt/etc/nixos
if [[ -n $rev ]] && sudo git -C /mnt/etc/nixos cat-file -e "$rev^{commit}"; then
    # Check out the branch the installed commit is the tip of, if there is one
    branch=$(sudo git -C /mnt/etc/nixos for-each-ref --count=1 --points-at "$rev" \
        --exclude=refs/remotes/origin/HEAD --format='%(refname:lstrip=3)' refs/remotes/origin)
    sudo git -C /mnt/etc/nixos checkout -q "${branch:-$rev}"
else
    echo "/etc/nixos has the default branch, which may differ from what was installed" >&2
fi
sudo chown -R 1000:100 /mnt/etc/nixos
# Carry over Wi-Fi connections made in the installer; there are none on a wired install
if [[ -d /etc/NetworkManager/system-connections ]]; then
    sudo mkdir -p /mnt/etc/NetworkManager
    sudo cp -r /etc/NetworkManager/system-connections /mnt/etc/NetworkManager/
fi
# Last, since the firmware won't boot the installer once Secure Boot enforces these keys
if [[ $(efivar SetupMode) == 1 ]] && sudo sbctl enroll-keys --microsoft; then
    set +x
    echo "Installed. The disk asks for its password at the first boot; after that the TPM unlocks it."
else
    set +x
    echo "Installed, but Secure Boot isn't set up, so the disk asks for its password at every boot."
    echo "Reset Secure Boot to Setup Mode in the firmware settings and systemd-boot enrolls this"
    echo "install's keys; after that the TPM unlocks the disk."
fi
read -rp "Reboot now? [Y/n] " answer
[[ $answer == [nN]* ]] || systemctl reboot

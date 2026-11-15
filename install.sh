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

# Taking ownership of the drive, which the install does once, needs the firmware
# not to block it (Block SID). It blocks it at every boot unless asked to skip
# the next one, which needs the TPM. Takes the systemctl verb that ends this
# boot, and the question offering it
skip_block_sid() {
    if ! echo 97 | sudo tee /sys/class/tpm/tpm0/ppi/request >/dev/null; then
        echo "Turn Security Chip on in the firmware settings, so the firmware can be asked to allow it." >&2
        exit 1
    fi
    # Come back to this installer on the next boot
    current=$(efibootmgr 2>/dev/null | sed -n 's/^BootCurrent: //p') || true
    [[ -z $current ]] || sudo efibootmgr --quiet --bootnext "$current" || true
    echo "The firmware will allow it on the next boot, which should start this installer again."
    echo "Confirm the firmware's prompt, then run this again. If another system starts, choose this"
    echo "installer with F12, but don't go through the firmware settings, which would block it again."
    read -rp "$2 [Y/n] " answer
    [[ $answer == [nN]* ]] || systemctl "$1"
    exit
}
factory_reset() {
    while true; do
        IFS= read -rp "PSID from the drive's label: " psid
        sudo cryptsetup erase -q --hw-opal-factory-reset "$disk" <<<"$psid" && break
        echo "That didn't work, try again" >&2
    done
    echo "The drive is factory reset. Setting it up again needs a power cycle, and the firmware to allow taking ownership of it."
    skip_block_sid poweroff "Power off now? Power on again yourself afterwards."
}

controller=$(realpath "$disk")
controller=${controller%n[0-9]*}
opal=$(sudo sedutil-cli --query "$controller" 2>/dev/null) || true
if [[ $opal != *"Locking function"* ]]; then
    echo "$disk doesn't report OPAL hardware encryption" >&2
    exit 1
fi
if [[ $opal == *"LockingEnabled = N"* && $opal == *"BlockSIDState = Y"* ]]; then
    echo "The firmware blocks taking ownership of the drive, which the install has to do once."
    skip_block_sid reboot "Reboot now?"
fi

read -rp "This erases everything on $disk. Type 'yes' to continue: " answer
[[ $answer == yes ]] || exit 1

sudo install -d -m 700 "$(dirname "$diskPassword")" "$(dirname "$tpmKey")"
trap 'sudo rm -f "$diskPassword" "$tpmKey"' EXIT

# A drive keeps the OPAL admin password it was first set up with until it's
# factory reset, so a reinstall keeps the previous install's disk password,
# which is that admin password
password=""
previous=""
mapfile -t devices < <(lsblk -lnpo NAME "$disk")
for device in "${devices[@]}"; do
    header=$(sudo cryptsetup luksDump "$device" 2>/dev/null) || continue
    if [[ $header == *"HW OPAL"* ]]; then
        previous=$device
        break
    fi
done
if [[ -n $previous ]]; then
    echo "$disk holds a previous install encrypted by the drive, whose disk password the new install keeps."
    while true; do
        IFS= read -rsp "Its disk password, or nothing to factory reset the drive instead: " password && echo
        [[ -n $password ]] || factory_reset
        # Checks the password while erasing the previous install
        sudo cryptsetup erase -q "$previous" <<<"$password" && break
        echo "That didn't work, try again" >&2
    done
elif [[ $opal == *"LockingEnabled = Y"* ]]; then
    echo "Something else set up $disk's hardware encryption, so it needs a factory reset."
    factory_reset
fi
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
    echo "Formatting failed. If the firmware blocked taking ownership of the drive, ask it to allow that" >&2
    echo "with 'echo 97 | sudo tee /sys/class/tpm/tpm0/ppi/request', reboot, confirm its prompt and run this again." >&2
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
if [[ $rev == "$(sudo git -C /mnt/etc/nixos rev-parse HEAD)" ]]; then
    : # Installed from the default branch
elif [[ -n $rev ]] && sudo git -C /mnt/etc/nixos cat-file -e "$rev^{commit}"; then
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

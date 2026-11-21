# cloud: the Cloud folder on Google Drive, mounted with rclone.
#
#   cloud setup     sign in to Google, and find Cloud in My Drive, or make it
#                   if there's none; once set up, signs in again, e.g. if
#                   access has expired
#   cloud mount     mount Cloud, printing where
#   cloud unmount   unmount it
#   cloud status    whether it's mounted, what's uploading, downloading or
#                   waiting to upload, and rclone's latest notices
#
# Cloud is mounted at /run/media/$USER/user/cloud, which Nautilus lists in its
# sidebar. /run/media/$USER/user is the user's own folder for mounts
# (os/users.nix); cloud in it is made here, as needed. Ejecting it in Nautilus
# unmounts it too.
#
# Files are cached in ~/.cache/rclone, so they open like local ones, and edits
# upload in the background a few seconds after they're closed. Any not
# uploaded by unmounting are uploaded the next time Cloud is mounted. rclone's
# notices, such as failed uploads, go to ~/.local/state/cloud.log.
#
# Files in Google's own formats (Docs, Sheets, Slides and so on) are left out,
# as rclone can only download copies of them and can't upload edits back. Edit
# them on Drive. A folder holding any can't be deleted from here: Drive keeps it.
#
# The sign-in is in ~/.config/cloud.conf, as gdrive, which is Drive rooted at
# Cloud by its ID, so it's still found if renamed. It has Google's full drive
# scope, so rclone sees files added to Cloud on Drive's website or phone app
# too; it can therefore read and change all of your Drive, not just Cloud.
#
# To remove everything cloud has set up on this computer, unmount, then:
#   rm -rf ~/.config/cloud.conf ~/.local/state/cloud.log ~/.cache/rclone
# and, if wanted, remove rclone's access at
# https://myaccount.google.com/connections and delete the OAuth client in the
# Google Cloud console.

export RCLONE_CONFIG=~/.config/cloud.conf
export RCLONE_DRIVE_SKIP_GDOCS=true # leave out Google Docs and so on (see above)
mount=/run/media/$(id -un)/user/cloud
log=~/.local/state/cloud.log
# The mount's remote control, through which status asks about transfers; in
# the user's runtime folder, so that only they can use it
socket=/run/user/$(id -u)/cloud.sock

die() { echo "cloud: $*" >&2; exit 1; }

# Asks the mount's rclone something, printing its answer as JSON
ask() { rclone rc --unix-socket "$socket" "$@" 2>/dev/null; }

# Prints a heading and the lines under it, unless there are none
list() { [[ -z $2 ]] || printf '%s\n' "$1" "$2"; }

# Prints the IDs of the folders called Cloud at the top of My Drive
find_folder() {
    rclone lsjson gdrive: --dirs-only --no-modtime --no-mimetype |
        jq -r '.[] | select(.Name == "Cloud") | .ID'
}

setup() {
    local id secret ids
    if [[ -e $RCLONE_CONFIG ]]; then
        # rclone opens a browser to sign in to Google
        rclone config reconnect gdrive: --auto-confirm
        return
    fi
    # rclone's own shared client is being retired during 2026
    echo "This needs your own Google OAuth client. To make one:"
    echo "  https://rclone.org/drive/#making-your-own-client-id"
    read -rp "Client ID: " id
    read -rsp "Client secret: " secret && echo
    [[ -n $id && -n $secret ]] || die "the client ID and secret can't be empty"
    # So that a failed setup can just be run again
    trap 'rm -f "$RCLONE_CONFIG"' ERR
    rclone config create gdrive drive scope=drive client_id="$id" client_secret="$secret" \
        --no-output
    ids=$(find_folder)
    if [[ -z $ids ]]; then
        rclone mkdir gdrive:Cloud
        ids=$(find_folder)
        echo "Made Cloud in My Drive."
    fi
    [[ -n $ids && $ids != *$'\n'* ]] || {
        rm -f "$RCLONE_CONFIG"
        die "My Drive has several folders called Cloud; rename or delete the extra ones"
    }
    # Root gdrive: at Cloud. config_refresh_token=false keeps the sign-in
    rclone config update gdrive root_folder_id="$ids" config_refresh_token=false --no-output
    echo "Set up with https://drive.google.com/drive/folders/$ids"
}

mount() {
    local net
    [[ -e $RCLONE_CONFIG ]] || die "not set up yet; run: cloud setup"
    ! mountpoint -q "$mount" || die "already mounted at $mount"
    # Offline, rclone would retry for minutes before failing
    net=$(nmcli -t networking connectivity check || true)
    [[ $net == full ]] || die "no internet connection (NetworkManager says: ${net:-nothing})"
    mkdir -p "$mount" ~/.local/state
    rm -f "$socket" # left by a mount that wasn't unmounted
    # --daemon returns once the mount is ready
    rclone mount gdrive: "$mount" --daemon --vfs-cache-mode full \
        --rc --rc-addr "unix://$socket" --rc-no-auth \
        --log-file "$log" || {
        rmdir "$mount"
        exit 1
    }
    echo "$mount"
}

unmount() {
    mountpoint -q "$mount" || die "not mounted"
    /run/wrappers/bin/fusermount3 -u "$mount" # NixOS's setuid wrapper
    rmdir "$mount"
}

status() {
    local stats queue transfers waiting
    [[ -e $RCLONE_CONFIG ]] || die "not set up yet; run: cloud setup"
    echo "Drive folder: https://drive.google.com/drive/folders/$(
        sed -n 's/^root_folder_id = //p' "$RCLONE_CONFIG")"
    if ! mountpoint -q "$mount"; then
        echo "Not mounted. Any files not uploaded yet are uploaded when it's next mounted."
    elif ! stats=$(ask core/stats) || ! queue=$(ask vfs/queue); then
        echo "Mounted at $mount, but rclone isn't answering, so what it's doing is unknown."
    else
        echo "Mounted at $mount"
        # Uploads and downloads alike
        transfers=$(jq -r '.transferring[]? |
            "  " + ("  \(.percentage)" | .[-3:]) + "%  \(.name)"' <<<"$stats")
        # Files closed a few seconds ago, waiting their turn, or whose uploads failed
        waiting=$(jq -r '.queue[]? | select(.uploading | not) | "  \(.name)" +
            if .tries > 0 then " (failed \(.tries) time(s), will try again)" else "" end' <<<"$queue")
        list "Transferring:" "$transfers"
        list "Waiting to upload:" "$waiting"
        [[ -n $transfers$waiting ]] || echo "All uploads and downloads are complete."
    fi
    if [[ -s $log ]]; then
        echo "Latest notices, from $log:"
        tail -n 10 "$log" | sed 's/^/  /'
    fi
}

case "$*" in
    setup | mount | unmount | status) "$1" ;;
    *) echo "usage: cloud setup | mount | unmount | status" >&2
       exit 2 ;;
esac

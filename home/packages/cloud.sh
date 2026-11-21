# cloud: the Cloud folder on Google Drive, mounted with rclone.
#
#   cloud setup     sign in to Google, making Cloud in My Drive if there's
#                   none; run again to sign in again if access has expired
#   cloud mount     mount Cloud, printing where
#   cloud unmount   unmount it
#
# Cloud is mounted at /run/media/$USER/user/cloud, which Nautilus lists in its
# sidebar. /run/media/$USER/user is the user's own folder for mounts
# (os/users.nix); cloud in it is made here, as needed.
#
# Files are cached in ~/.cache/rclone, so they open like local ones, and edits
# upload in the background a few seconds after they're closed. Any not
# uploaded by unmounting are uploaded the next time Cloud is mounted.
#
# The sign-in is in ~/.config/cloud.conf, with Google's full drive scope, so
# rclone sees files added to Cloud on Drive's website or phone app too. It can
# therefore read and change all of your Drive, not just Cloud.

export RCLONE_CONFIG=~/.config/cloud.conf
mount=/run/media/$(id -un)/user/cloud

die() { echo "cloud: $*" >&2; exit 1; }

setup() {
    local id secret
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
    rclone mkdir gdrive:Cloud
}

case "$*" in
    setup)
        setup ;;
    mount)
        [[ -e $RCLONE_CONFIG ]] || die "not set up yet; run: cloud setup"
        ! mountpoint -q "$mount" || die "already mounted at $mount"
        mkdir -p "$mount"
        # --daemon returns once the mount is ready
        rclone mount gdrive:Cloud "$mount" --vfs-cache-mode full --daemon || {
            rmdir "$mount"
            exit 1
        }
        echo "$mount" ;;
    unmount)
        mountpoint -q "$mount" || die "not mounted"
        /run/wrappers/bin/fusermount3 -u "$mount" # NixOS's setuid wrapper
        rmdir "$mount" ;;
    *)
        echo "usage: cloud setup | mount | unmount" >&2
        exit 2 ;;
esac

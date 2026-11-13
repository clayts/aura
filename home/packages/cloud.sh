# cloud: ~/Cloud is an rclone mount of a folder on Google Drive.
#
#   cloud setup               set up this computer: sign in to Google, and find
#                             Cloud in My Drive, or make it if there's none
#   cloud setup --reconnect   sign in to Google again, e.g. if access has expired
#   cloud status              is it mounted, is anything waiting to upload, and
#                             anything that needs attention
#   cloud mount               mount in the foreground; the cloud user service
#                             (home/gnome.nix) runs this at login
#
# Signing in asks for Google's full drive scope, so files added to Cloud some
# other way, such as Drive's website or phone app, show up too. The sign-in in
# the config can therefore read and change all of your Drive, not just Cloud.
#
# On this computer:
#   ~/.config/cloud.conf   rclone's config: gdrive, which is Drive rooted at
#                          Cloud by its ID, so mounting needs no internet. It
#                          holds the client ID and secret and the sign-in, and
#                          only you can read it.
#   ~/.local/share/cloud   where gdrive is mounted. GNOME doesn't list mounts in
#                          hidden folders, so Files has no Eject for it.
#   ~/Cloud                a link to it
#   ~/.local/state/cloud   rclone's cache, holding changes not yet uploaded
#
# Files that are opened are cached for an hour after last use, and changes to
# them are written to the cache first and uploaded in the background, retrying
# until the internet is back; changes not yet uploaded are kept across logouts
# and restarts. Folder listings are kept in memory for as long as the mount
# runs, and refreshed by asking Drive every minute what has changed, and every
# folder is listed in the background at mount, so a dropped connection doesn't
# stop browsing. They don't survive a restart though: mounted offline, folders
# can't be opened until the internet is back. There are no conflict copies: if
# a file is changed both here and elsewhere, the last upload wins.
#
# To remove everything cloud has set up on this computer, first check `cloud
# status` says nothing is waiting to upload, as those changes are only in the
# cache, then:
#   systemctl --user stop cloud.service
#   rm -rf ~/.config/cloud.conf ~/.local/state/cloud ~/Cloud
#   rmdir ~/.local/share/cloud
# Then, if wanted, outside this computer:
#   - delete the Cloud folder on Google Drive
#   - remove rclone's access at https://myaccount.google.com/connections
#   - delete the OAuth client in the Google Cloud console
# and in this repo, remove packages.cloud from home/zsh.nix and
# home/packages/default.nix, and the cloud service from home/gnome.nix.

export RCLONE_CONFIG=~/.config/cloud.conf
mountpoint=~/.local/share/cloud
link=~/Cloud
cache=~/.local/state/cloud  # not ~/.cache: it holds changes not yet uploaded
socket=${XDG_RUNTIME_DIR:-/run/user/$UID}/cloud.sock  # rclone's remote control, for status
folder_name=Cloud           # in My Drive

die() { echo "cloud: $*" >&2; exit 1; }

need_config() {
    [[ -e $RCLONE_CONFIG ]] || die "there's no $RCLONE_CONFIG; run: cloud setup"
}

is_empty_dir() { [[ -d $1 && -z $(find "$1" -mindepth 1 -maxdepth 1 -print -quit) ]]; }

folder_url() { echo "https://drive.google.com/drive/folders/$1"; }

# Prints the IDs of the folders called $folder_name at the top of My Drive.
find_folder() {
    local listing
    listing=$(rclone lsjson gdrive: --dirs-only --no-modtime --no-mimetype) ||
        die "couldn't list folders on Drive"
    jq -r --arg name "$folder_name" '.[] | select(.Name == $name) | .ID' <<<"$listing"
}

setup() {
    local id secret ids
    [[ ! -e $RCLONE_CONFIG ]] || die "$RCLONE_CONFIG exists; delete it to set up again"
    [[ ! -e $cache ]] ||
        die "$cache exists, left from before. Changes made offline that were never" \
            "uploaded are kept in its vfs folder; once you've rescued any, delete it"
    [[ ! -e $mountpoint ]] || is_empty_dir "$mountpoint" ||
        die "$mountpoint isn't an empty folder; is it still mounted?"
    if [[ -L $link ]]; then
        [[ $(readlink "$link") == "$mountpoint" ]] || die "$link links elsewhere; move it aside to set up"
    elif [[ -e $link ]]; then
        is_empty_dir "$link" || die "$link isn't an empty folder; move it aside to set up"
    fi

    # rclone's own shared client is being retired during 2026.
    echo "This needs your own Google OAuth client. To make one:"
    echo "  https://rclone.org/drive/#making-your-own-client-id"
    echo "Its consent screen needs the scope .../auth/drive."
    read -rp "Client ID: " id
    read -rsp "Client secret: " secret; echo
    [[ -n $id && -n $secret ]] || die "the client ID and secret can't be empty"

    # A setup that fails part-way leaves no config behind, so it can just be run again.
    trap 'rm -f "$RCLONE_CONFIG"' EXIT
    # rclone opens a browser to sign in to Google.
    rclone config create gdrive drive scope=drive client_id="$id" client_secret="$secret" \
        --no-output
    ids=$(find_folder) || exit 1
    if [[ -z $ids ]]; then
        rclone mkdir "gdrive:$folder_name" || die "couldn't make $folder_name in My Drive"
        ids=$(find_folder) || exit 1
        echo "Made $folder_name in My Drive."
    fi
    [[ -n $ids && $ids != *$'\n'* ]] ||
        die "My Drive has several folders called $folder_name; rename or delete the extra ones"
    # Root gdrive: at Cloud. config_refresh_token=false keeps the sign-in.
    rclone config update gdrive root_folder_id="$ids" config_refresh_token=false --no-output
    trap - EXIT

    mkdir -p "$mountpoint"
    if [[ ! -L $link ]]; then
        [[ ! -e $link ]] || rmdir "$link"
        ln -s "$mountpoint" "$link"
    fi
    systemctl --user start cloud.service ||
        die "couldn't mount; see: journalctl --user -u cloud"
    echo "Mounted ~/Cloud from $(folder_url "$ids")"
}

run_mount() {
    need_config
    # rclone won't listen on a socket that's left over from a crash. The service
    # never runs twice, so one that's there now isn't in use.
    rm -f "$socket"
    mkdir -p "$mountpoint"
    # --vfs-cache-mode full: files are read and written through the cache, and
    #   writes are uploaded in the background, kept and retried until they succeed.
    #   They're dropped from the cache an hour after last use (--vfs-cache-max-age).
    # --dir-cache-time: folder listings never expire; Drive's change polling
    #   (--poll-interval, a minute) refreshes them, so they're there offline.
    # --vfs-refresh: list every folder in the background at mount, while online.
    # --contimeout, --timeout: give up on a dead connection sooner than the
    #   defaults (1 and 5 minutes), so browsing an uncached folder offline fails
    #   rather than hangs.
    exec rclone mount gdrive: "$mountpoint" --cache-dir "$cache" \
        --vfs-cache-mode full --dir-cache-time 100000h --vfs-refresh \
        --contimeout 15s --timeout 1m \
        --rc --rc-addr "unix://$socket"
}

# Exits 1 if anything needs attention; changes waiting to upload don't count.
status() {
    local ok=0 out net stats
    need_config
    if out=$(rclone -q config redacted gdrive); then
        echo "Drive folder: $(folder_url "$(sed -n 's/^root_folder_id = //p' <<<"$out")")"
    fi
    net=$(nmcli -t networking connectivity check || true)
    [[ $net == full ]] || echo "Offline (NetworkManager says: ${net:-nothing})."

    if ! systemctl --user -q is-active cloud.service; then
        echo "Not mounted. The mount's latest log:"
        journalctl --user -u cloud.service -n 10 -o cat --no-pager | sed 's/^/  /'
        return 1
    fi
    echo "Mounted."
    if ! stats=$(rclone rc --unix-socket "$socket" vfs/stats 2>&1); then
        echo "Couldn't ask the mount for its state: $stats"
        return 1
    fi
    jq -r '.diskCache |
        "Cached: \(.files) files, \(.bytesUsed / 1048576 | floor) MiB.",
        (.uploadsInProgress + .uploadsQueued | select(. > 0) |
            "Waiting to upload: \(.) files."),
        (select(.outOfSpace) | "The disk is too full to cache any more."),
        (.erroredFiles | select(. > 0) |
            "\(.) cached files have errors; see: journalctl --user -u cloud")' <<<"$stats"
    jq -e '.diskCache | .outOfSpace or .erroredFiles > 0' <<<"$stats" >/dev/null && ok=1
    return "$ok"
}

case "$*" in
    setup)               setup ;;
    "setup --reconnect") need_config
                         rclone config reconnect gdrive: --auto-confirm
                         # The running mount still has the old sign-in.
                         systemctl --user try-restart cloud.service ;;
    mount)               run_mount ;;
    status)              status ;;
    *) echo "usage: cloud setup [--reconnect] | status | mount" >&2
       exit 2 ;;
esac

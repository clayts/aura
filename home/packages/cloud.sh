# cloud: ~/Cloud is an rclone mount of an encrypted folder on Google Drive.
#
#   cloud setup               one-time setup; ~/Cloud must be empty or missing
#   cloud setup --reconnect   sign in to Google again, e.g. if access has expired;
#                             rclone opens the browser and fills in its defaults
#   cloud status              is it mounted, is anything waiting to upload, and
#                             anything that needs attention
#   cloud mount               mount in the foreground; the cloud user service
#                             (home/gnome.nix) runs this at login
#
# A dedicated rclone config (~/.config/cloud.conf) holds two remotes: gdrive
# (Google Drive, rooted at the folder itself by its ID) and crypt (encrypts
# gdrive:). The config is encrypted with a random key kept in the GNOME keyring,
# so the mount can only start while logged in to GNOME.
#
# Mounting needs no internet: given the folder's ID, rclone doesn't look it up
# by name. Files that are opened are cached for an hour after last use, and
# changes to them are written to the cache first and uploaded in the background,
# retrying until the internet is back; changes not yet uploaded are kept across
# logouts and restarts. Folder listings are kept in memory for as long as the
# mount runs, and refreshed by asking Drive every minute what has changed, and
# every folder is listed in the background at mount, so a dropped connection
# doesn't stop browsing. They don't survive a restart though: mounted offline,
# folders can't be opened until the internet is back.
# There are no conflict copies: if a file is changed both here and elsewhere,
# the last upload wins.
#
# ~/Cloud/.cloud marks the folder as one of cloud's: setup looks it up to check
# the passphrase.
#
# To remove everything cloud has set up, first check `cloud status` says nothing
# is waiting to upload, as those changes are only in the cache, then:
#   systemctl --user stop cloud.service
#   rm -rf ~/.config/cloud.conf ~/.local/state/cloud
#   secret-tool clear service cloud account rclone-config
#   rmdir ~/Cloud
# Then, if wanted, outside this machine:
#   - delete the folder on Google Drive (its file names are encrypted)
#   - remove rclone's access at https://myaccount.google.com/connections
#   - delete your own client ID, if setup was given one, in the Google Cloud console
# and in this repo, remove packages.cloud from home/zsh.nix and
# home/packages/default.nix, and the cloud service from home/gnome.nix.

keyring=(service cloud account rclone-config)  # the keyring entry holding the config's key
export RCLONE_CONFIG=~/.config/cloud.conf
export RCLONE_PASSWORD_COMMAND="secret-tool lookup ${keyring[*]}"
cache=~/.local/state/cloud  # not ~/.cache: it holds changes not yet uploaded
socket=${XDG_RUNTIME_DIR:-/run/user/$UID}/cloud.sock  # rclone's remote control, for status
folder_name=Cloud  # what setup looks for, or creates, in My Drive

die() { echo "cloud: $*" >&2; exit 1; }

need_config() {
    [[ -e $RCLONE_CONFIG ]] || die "there's no $RCLONE_CONFIG; run: cloud setup"
}

folder_url() { echo "https://drive.google.com/drive/folders/$1"; }

# Prints the folder ID from a Drive folder's URL, or from the ID itself.
folder_id() {
    local id='([A-Za-z0-9_-]{10,})' path query
    path="/folders/$id" query="[?&]id=$id"
    if [[ $1 =~ $path || $1 =~ $query || $1 =~ ^$id$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        return 1
    fi
}

# Prints the IDs of the folders called $folder_name at the top of My Drive.
find_folder() {
    local listing
    listing=$(rclone lsjson gdrive: --dirs-only --no-modtime --no-mimetype) ||
        die "couldn't list My Drive"
    jq -r --arg name "$folder_name" '.[] | select(.Name == $name) | .ID' <<<"$listing"
}

set_passphrase() {
    rclone config create crypt crypt remote=gdrive: password="$1" --obscure --no-output
}

setup() {
    [[ ! -e $RCLONE_CONFIG ]] || die "$RCLONE_CONFIG exists; delete it to set up again"
    [[ ! -e $cache ]] ||
        die "$cache exists, left from before. Changes made offline that were never" \
            "uploaded are kept in its vfs folder; once you've rescued any, delete it"
    if [[ -e ~/Cloud ]]; then
        [[ -d ~/Cloud && -z $(find ~/Cloud -mindepth 1 -maxdepth 1 -print -quit) ]] ||
            die "$HOME/Cloud isn't an empty folder; move it aside to set up"
    fi

    local id secret="" url folder="" pass again listing found ids=() marker rc
    read -rp "Google API client ID (empty for rclone's shared one): " id
    if [[ -n $id ]]; then read -rsp "Client secret: " secret; echo; fi
    read -rp "Drive folder's URL (empty to use or create $folder_name in My Drive): " url
    if [[ -n $url ]]; then
        folder=$(folder_id "$url") || die "that isn't a Drive folder's URL"
    fi
    IFS= read -rsp "Passphrase for the encrypted files: " pass; echo
    IFS= read -rsp "Repeat it: " again; echo
    [[ -n $pass && $pass == "$again" ]] || die "the passphrases must match and can't be empty"

    # A setup that fails part-way leaves no config behind, so it can just be run again.
    trap 'rm -f "$RCLONE_CONFIG"' EXIT
    # The config starts out encrypted, so the token and passphrase are never on disk
    # in plain text.
    head -c 32 /dev/urandom | base64 | secret-tool store --label="cloud rclone config" "${keyring[@]}"
    rclone -q config encryption set >/dev/null

    # Google Drive; rclone opens a browser to sign in. rclone's shared client ID
    # is being retired: https://rclone.org/drive/#making-your-own-client-id
    rclone config create gdrive drive scope=drive client_id="$id" client_secret="$secret" \
        config_shared_client_id=true --no-output

    if [[ -z $folder ]]; then
        found=$(find_folder) || exit 1
        [[ -z $found ]] || mapfile -t ids <<<"$found"
        case ${#ids[@]} in
            0) rclone mkdir "gdrive:$folder_name"
               found=$(find_folder) || exit 1
               [[ -n $found && $found != *$'\n'* ]] || die "couldn't create $folder_name in My Drive"
               ids=("$found")
               echo "Created $folder_name in My Drive." ;;
            1) echo "Using $folder_name in My Drive." ;;
            *) die "My Drive has ${#ids[@]} folders called $folder_name; run setup again" \
                   "and give the URL of the one to use" ;;
        esac
        folder=${ids[0]}
    fi
    # Root gdrive: at the folder. config_refresh_token=false keeps the sign-in.
    rclone config update gdrive root_folder_id="$folder" config_refresh_token=false \
        config_shared_client_id=true --no-output
    listing=$(rclone lsf gdrive:) || die "couldn't open $(folder_url "$folder")"

    set_passphrase "$pass"
    if [[ -n $listing ]]; then
        # The folder has files already. A wrong passphrase encrypts the name .cloud
        # differently, so it isn't found: rclone exits with 3 or 4, or prints null.
        while :; do
            rc=0
            marker=$(rclone -q lsjson --stat crypt:.cloud 2>/dev/null) || rc=$?
            (( rc == 0 || rc == 3 || rc == 4 )) ||
                die "couldn't read the folder (rclone exit code $rc)"
            [[ $rc == 0 && $marker != null ]] && break
            IFS= read -rsp "That doesn't unlock the folder (Ctrl-C to stop). Passphrase: " pass; echo
            set_passphrase "$pass"
        done
    else
        echo "The folder is empty, so this starts a new one."
        echo "☁️" | rclone -q rcat crypt:.cloud
    fi
    trap - EXIT

    mkdir -p ~/Cloud
    systemctl --user start cloud.service ||
        die "couldn't mount ~/Cloud; see: journalctl --user -u cloud"
    echo "Mounted ~/Cloud from $(folder_url "$folder")"
}

run_mount() {
    need_config
    # rclone won't listen on a socket that's left over from a crash. The service
    # never runs twice, so one that's there now isn't in use.
    rm -f "$socket"
    # --vfs-cache-mode full: files are read and written through the cache, and
    #   writes are uploaded in the background, kept and retried until they succeed.
    #   They're dropped from the cache an hour after last use (--vfs-cache-max-age).
    # --dir-cache-time: folder listings never expire; Drive's change polling
    #   (--poll-interval, a minute) refreshes them, so they're there offline.
    # --vfs-refresh: list every folder in the background at mount, while online.
    # --contimeout, --timeout: give up on a dead connection sooner than the
    #   defaults (1 and 5 minutes), so browsing an uncached folder offline fails
    #   rather than hangs.
    exec rclone mount crypt: ~/Cloud --cache-dir "$cache" \
        --vfs-cache-mode full --dir-cache-time 100000h --vfs-refresh \
        --contimeout 15s --timeout 1m \
        --rc --rc-addr "unix://$socket"
}

# Exits 1 if anything needs attention; changes waiting to upload don't count.
status() {
    local ok=0 out net stats
    need_config
    grep -q '^RCLONE_ENCRYPT_V0:' "$RCLONE_CONFIG" || { echo "The config isn't encrypted."; ok=1; }
    if out=$(rclone -q config redacted gdrive); then
        echo "Drive folder: $(folder_url "$(sed -n 's/^root_folder_id = //p' <<<"$out")")"
        if ! grep -q '^client_id = .' <<<"$out"; then
            echo "Using rclone's shared Google client ID, which is being retired:"
            echo "  https://rclone.org/drive/#making-your-own-client-id"
            ok=1
        fi
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

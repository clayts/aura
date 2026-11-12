# cloud: ~/Cloud is an rclone mount of an encrypted folder on Google Drive.
#
#   cloud setup               one-time setup on the first computer; signs in to
#                             Google, makes the Drive folders and the data key
#   cloud setup FILE          set up another computer from conf.age, downloaded
#                             from the Cloud folder on Drive
#   cloud setup --reconnect   sign in to Google again, e.g. if access has expired
#   cloud status              is it mounted, is anything waiting to upload, and
#                             anything that needs attention
#   cloud mount               mount in the foreground; the cloud user service
#                             (home/gnome.nix) runs this at login
#
# On Drive, Cloud in My Drive holds:
#   conf.age   what setup needs on another computer: the Google client ID and
#              secret, both folders' IDs and the data key, as a JSON object
#              with the keys client_id, client_secret, cloud_folder,
#              data_folder and data_key, encrypted with age and a password
#              chosen at setup (age --decrypt conf.age shows it). It's written
#              once and never changes; no sign-in is in it.
#   data/      the files, encrypted with the data key by rclone crypt.
# Signing in asks only for Google's drive.file scope, so rclone can reach just
# what it created itself. That's tied to the client ID: a new client can't see
# Cloud.
#
# On this computer:
#   ~/.config/cloud.conf   rclone's config: gdrive (Drive, rooted at Cloud by its
#                          ID) and crypt (encrypts data, also by its ID, so
#                          mounting needs no internet). It's encrypted with a
#                          random key kept in the GNOME keyring, so the mount
#                          only starts while logged in to GNOME.
#   ~/.local/share/cloud   where crypt is mounted. GNOME doesn't list mounts in
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
#   secret-tool clear service cloud account rclone-config
# Then, if wanted, outside this computer:
#   - delete the Cloud folder on Google Drive
#   - remove rclone's access at https://myaccount.google.com/connections
#   - delete the OAuth client in the Google Cloud console
# and in this repo, remove packages.cloud from home/zsh.nix and
# home/packages/default.nix, and the cloud service and ~/Cloud's folder icon
# from home/gnome.nix.

keyring=(service cloud account rclone-config)  # the keyring entry holding the config's key
export RCLONE_CONFIG=~/.config/cloud.conf
export RCLONE_PASSWORD_COMMAND="secret-tool lookup ${keyring[*]}"
mountpoint=~/.local/share/cloud
link=~/Cloud
cache=~/.local/state/cloud  # not ~/.cache: it holds changes not yet uploaded
socket=${XDG_RUNTIME_DIR:-/run/user/$UID}/cloud.sock  # rclone's remote control, for status
folder_name=Cloud           # in My Drive
setup_file="conf.age"  # in $folder_name

die() { echo "cloud: $*" >&2; exit 1; }

need_config() {
    [[ -e $RCLONE_CONFIG ]] || die "there's no $RCLONE_CONFIG; run: cloud setup"
}

is_empty_dir() { [[ -d $1 && -z $(find "$1" -mindepth 1 -maxdepth 1 -print -quit) ]]; }

folder_url() { echo "https://drive.google.com/drive/folders/$1"; }

# Prints the IDs of the folders called $1 at the top of gdrive:.
find_folder() {
    local listing
    listing=$(rclone lsjson gdrive: --dirs-only --no-modtime --no-mimetype) ||
        die "couldn't list folders on Drive"
    jq -r --arg name "$1" '.[] | select(.Name == $name) | .ID' <<<"$listing"
}

# Prints the ID of the folder called $1 at the top of gdrive:, making it if
# there's none.
make_folder() {
    local ids
    ids=$(find_folder "$1") || exit 1
    if [[ -z $ids ]]; then
        rclone mkdir "gdrive:$1" || die "couldn't make the folder $1 on Drive"
        ids=$(find_folder "$1") || exit 1
    fi
    [[ -n $ids && $ids != *$'\n'* ]] || die "couldn't find a single folder called $1 on Drive"
    echo "$ids"
}

setup() {
    local file=${1:-} answers values id secret cloud="" data key listing sealed
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

    if [[ -n $file ]]; then
        # age asks for the password on the terminal.
        answers=$(age --decrypt "$file") || die "couldn't decrypt $file"
        jq -e '.client_id and .client_secret and .cloud_folder and .data_folder and .data_key' \
            <<<"$answers" >/dev/null || die "$file isn't a cloud setup file"
        values=$(jq -r '.client_id, .client_secret, .cloud_folder, .data_folder, .data_key' \
            <<<"$answers")
        { read -r id; read -r secret; read -r cloud; read -r data; read -r key; } <<<"$values"
    else
        # drive.file ties the files to the client that made them, so rclone's own
        # shared client, which is being retired, would lose them with it.
        echo "Make a Google OAuth client first: https://rclone.org/drive/#making-your-own-client-id"
        echo "Its consent screen needs the scope .../auth/drive.file."
        read -rp "Client ID: " id
        read -rsp "Client secret: " secret; echo
        [[ -n $id && -n $secret ]] || die "the client ID and secret can't be empty"
    fi

    # A setup that fails part-way leaves no config behind, so it can just be run again.
    trap 'rm -f "$RCLONE_CONFIG"' EXIT
    # The config starts out encrypted, so the token and data key are never on disk
    # in plain text.
    head -c 32 /dev/urandom | base64 | secret-tool store --label="cloud rclone config" "${keyring[@]}"
    rclone -q config encryption set >/dev/null
    # rclone opens a browser to sign in to Google.
    rclone config create gdrive drive scope=drive.file client_id="$id" client_secret="$secret" \
        root_folder_id="$cloud" --no-output

    if [[ -z $cloud ]]; then
        cloud=$(make_folder "$folder_name") || exit 1
        # Root gdrive: at Cloud. config_refresh_token=false keeps the sign-in.
        rclone config update gdrive root_folder_id="$cloud" config_refresh_token=false --no-output
        listing=$(rclone lsf gdrive:) || die "couldn't list $folder_name in My Drive"
        [[ -z $listing ]] ||
            die "$folder_name in My Drive isn't empty. If it has $setup_file, download it and" \
                "run: cloud setup FILE"
        data=$(make_folder data) || exit 1
        key=$(head -c 32 /dev/urandom | base64)
        echo
        echo "The data key, which decrypts $folder_name/data with any rclone crypt remote."
        echo "Keep it somewhere safe; it isn't shown again:"
        echo "  $key"
        echo
        echo "Now a password for $setup_file, needed to set up another computer."
        echo "It protects the data key, so make it long, e.g. a few random words."
        sealed=$(jq -n --arg client_id "$id" --arg client_secret "$secret" \
            --arg cloud_folder "$cloud" --arg data_folder "$data" --arg data_key "$key" \
            '$ARGS.named' | age --passphrase --armor) || die "couldn't encrypt $setup_file"
        rclone -q rcat "gdrive:$setup_file" <<<"$sealed" || die "couldn't upload $setup_file"
    fi

    rclone config create crypt crypt remote="gdrive,root_folder_id=$data:" password="$key" \
        --obscure --no-output
    rclone -q lsf crypt: >/dev/null || die "couldn't open $folder_name/data on Drive"
    trap - EXIT

    mkdir -p "$mountpoint"
    if [[ ! -L $link ]]; then
        [[ ! -e $link ]] || rmdir "$link"
        ln -s "$mountpoint" "$link"
    fi
    systemctl --user start cloud.service ||
        die "couldn't mount; see: journalctl --user -u cloud"
    echo "Mounted ~/Cloud from $(folder_url "$cloud")"
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
    exec rclone mount crypt: "$mountpoint" --cache-dir "$cache" \
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

case ${1:-} in
    setup)
        if [[ ${2:-} == --reconnect ]]; then
            need_config
            rclone config reconnect gdrive: --auto-confirm
            # The running mount still has the old sign-in.
            systemctl --user try-restart cloud.service
        else
            setup "${2:-}"
        fi ;;
    mount)  run_mount ;;
    status) status ;;
    *) echo "usage: cloud setup [FILE | --reconnect] | status | mount" >&2
       exit 2 ;;
esac

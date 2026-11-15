# cloud: two-way sync of ~/Cloud with a folder on Google Drive.
#
#   cloud setup               set up this computer: sign in to Google, find Cloud
#                             in My Drive, or make it if there's none, and sync
#                             it into ~/Cloud, which mustn't exist yet
#   cloud setup --reconnect   sign in to Google again, e.g. if access has expired
#   cloud sync [flags]        two-way sync; extra flags go to rclone bisync. The
#                             cloud timer (home/gnome.nix) runs this at login and
#                             every hour
#   cloud status [--verify]   what the next sync would change, and anything that
#                             needs attention. --verify also compares every file
#                             with its copy on Drive, which reads all of ~/Cloud.
#
# Signing in asks for Google's full drive scope, so files added to Cloud some
# other way, such as Drive's website or phone app, are synced too. The sign-in
# in the config can therefore read and change all of your Drive, not just Cloud.
#
# On this computer:
#   ~/.config/cloud.conf   rclone's config: gdrive, which is Drive rooted at
#                          Cloud by its ID. It holds the client ID and secret
#                          and the sign-in, and only you can read it.
#   ~/.local/state/cloud   bisync's record of the last sync
#
# Cloud/.cloud is kept on both sides: bisync only runs when it can see it on
# both (--check-access), so a missing or emptied folder is never taken to mean
# everything in it was deleted. If it's deleted from one side anyway, check
# nothing else is missing there, then put it back with a resync (see below):
#   cloud sync --resync-mode newer --check-access=false
# That isn't done automatically, as a missing .cloud is the sign that something
# is wrong. Without a record of the last sync, as after a first sync that
# failed, a sync is a resync anyway: it copies whatever is missing from either
# side, keeping the newer copy of files that differ, and deletes nothing.
# A file changed on both sides since the last sync: the newer copy wins, and
# the other is kept as name.cloud-conflict-N.ext.
#
# Files in Google's own formats (Docs, Sheets, Slides and so on) are left out,
# as rclone can only download copies of them and can't upload edits back. Edit
# them on Drive. A folder holding any can't be deleted from here: Drive keeps it.
#
# To remove everything cloud has set up on this computer, stop the timer first
# so that no sync runs part-way through:
#   systemctl --user stop cloud.timer cloud.service
#   rm -rf ~/.config/cloud.conf ~/.local/state/cloud
#   rm -rf ~/Cloud                  # the local copy; keep it if Drive is going too
# Then, if wanted, outside this computer:
#   - delete the Cloud folder on Google Drive
#   - remove rclone's access at https://myaccount.google.com/connections
#   - delete the OAuth client in the Google Cloud console
# and in this repo, remove packages.cloud from home/zsh.nix and
# home/packages/default.nix, and the cloud service, timer and ~/Cloud folder
# icon from home/gnome.nix.

export RCLONE_CONFIG=~/.config/cloud.conf
export RCLONE_COLOR=NEVER  # plain logs: bisync colours some lines even when not on a terminal
export RCLONE_DRIVE_SKIP_GDOCS=true  # leave out Google Docs and so on (see above)
state=~/.local/state/cloud
folder_name=Cloud          # in My Drive

die() { echo "cloud: $*" >&2; exit 1; }

need_config() {
    [[ -e $RCLONE_CONFIG ]] ||
        die "there's no $RCLONE_CONFIG; to set up again, move ~/Cloud aside and run: cloud setup"
}

# Is there a record (lst) or backup record (lst-old) of the last sync? A glob that
# matches nothing stays as it is. (Not compgen: Nix's non-interactive bash lacks it.)
record() { local files=("$state"/*."$1"); [[ -e ${files[0]} ]]; }

# Prints a heading and the lines under it, unless there are none.
list() { [[ -n $2 ]] && printf '%s\n' "$1" "$2"; }

folder_url() { echo "https://drive.google.com/drive/folders/$1"; }

# Prints the IDs of the folders called $folder_name at the top of My Drive.
find_folder() {
    rclone lsjson gdrive: --dirs-only --no-modtime --no-mimetype |
        jq -r --arg name "$folder_name" '.[] | select(.Name == $name) | .ID'
}

bisync() {
    local net
    # Quick checks first, so a run that can't work (from a timer, say) stops at once,
    # rather than after rclone has listed both sides, or retried for minutes offline.
    need_config
    # With no record of the last sync (lst), nor a backup of it (lst-old) for --recover
    # to fall back on, only a resync can start a new one.
    record lst || record lst-old || set -- --resync-mode newer "$@"
    net=$(nmcli -t networking connectivity check || true)
    [[ $net == full ]] || die "no internet connection (NetworkManager says: ${net:-nothing})"
    # Downloads are written to name.xxxxxxxx.cloud.partial and then renamed. If rclone
    # is killed, the leftover is excluded so it's never uploaded as a real file.
    # A file changed on both sides: the newer copy wins, the other is kept as
    # name.cloud-conflict-N.ext. bisync stops if over half the files on one side were
    # deleted; --max-delete is that percentage (rclone's help calls it a count), so 100
    # lets any number of deletions through.
    rclone bisync ~/Cloud gdrive: --workdir "$state" \
        --check-access --check-filename .cloud --create-empty-src-dirs \
        --resilient --recover --max-lock 2m --max-delete 100 \
        --conflict-resolve newer --conflict-suffix cloud-conflict- --suffix-keep-extension \
        --partial-suffix .cloud.partial --exclude '*.cloud.partial' "$@" && return
    local rc=$?
    # After some errors, rclone sets the record aside and says "Must run --resync to
    # recover". It's wrong: the next sync falls back on the backup record, or resyncs.
    [[ $* == *--resync* ]] || record lst ||
        echo "cloud: no need for --resync; the next sync recovers by itself" >&2
    return "$rc"
}

setup() {
    local id secret ids synced=true
    [[ ! -e ~/Cloud && ! -L ~/Cloud ]] || die "$HOME/Cloud exists; move it aside to set up again"
    [[ ! -e $RCLONE_CONFIG ]] || die "$RCLONE_CONFIG exists; delete it to set up again"
    [[ ! -e $state ]] ||
        die "$state exists, left from before; once you're sure nothing in it is needed," \
            "delete it to set up again"

    # rclone's own shared client is being retired during 2026.
    echo "This needs your own Google OAuth client. To make one:"
    echo "  https://rclone.org/drive/#making-your-own-client-id"
    read -rp "Client ID: " id
    read -rsp "Client secret: " secret; echo
    [[ -n $id && -n $secret ]] || die "the client ID and secret can't be empty"

    # Until the first sync starts, a failed setup leaves nothing behind, so it can just
    # be run again. Before then, ~/Cloud only ever holds .cloud.
    trap 'rm -f "$RCLONE_CONFIG" ~/Cloud/.cloud; rmdir ~/Cloud 2>/dev/null || true' EXIT
    # rclone opens a browser to sign in to Google.
    rclone config create gdrive drive scope=drive client_id="$id" client_secret="$secret" \
        --no-output
    ids=$(find_folder)
    if [[ -z $ids ]]; then
        rclone mkdir "gdrive:$folder_name" || die "couldn't make $folder_name in My Drive"
        ids=$(find_folder)
        echo "Made $folder_name in My Drive."
    fi
    [[ -n $ids && $ids != *$'\n'* ]] ||
        die "My Drive has several folders called $folder_name; rename or delete the extra ones"
    # Root gdrive: at Cloud. config_refresh_token=false keeps the sign-in.
    rclone config update gdrive root_folder_id="$ids" config_refresh_token=false --no-output

    # Put .cloud on both sides; one already on Drive is replaced, as it's always empty.
    mkdir ~/Cloud
    touch ~/Cloud/.cloud
    rclone copyto ~/Cloud/.cloud gdrive:.cloud || die "couldn't upload .cloud to Drive"
    trap - EXIT

    # With no record yet, the first sync is a resync. That makes no backup record, so
    # an ordinary sync follows to make one, so that a sync that fails part-way can
    # recover by itself. A subshell, so that bisync's own checks can't stop setup
    # before the timer starts.
    ( bisync && bisync ) || synced=false
    # Without ~/Cloud at login, the timer didn't start then. It starts only now, so
    # that its first sync, a minute later, can't run into the one above; and even if
    # that failed, so that timed syncs carry on once it's fixed.
    systemctl --user start cloud.timer
    $synced || die "the first sync failed; each timed sync tries again, or run: cloud sync"
    echo "Synced ~/Cloud with $(folder_url "$ids")"
}

# Exits 1 if anything needs attention; changes waiting for the next sync don't count.
status() {
    local ok=0 out
    need_config
    echo "Drive folder: $(folder_url "$(sed -n 's/^root_folder_id = //p' "$RCLONE_CONFIG")")"
    # bisync rewrites its record after every successful sync.
    record path1.lst && echo "Last successful sync: $(date -r "$state"/*.path1.lst '+%Y-%m-%d %H:%M')"

    if ! out=$(bisync --dry-run 2>&1); then
        grep -E 'ERROR|CRITICAL|Failed to|^cloud:' <<<"$out" >&2 || true
        ok=1
        set --  # skip --verify too: offline, rclone would retry for minutes before failing
    elif [[ $out == *"Resync is copying"* ]]; then
        echo "No record of the last sync, so the next sync copies whatever is missing from either side."
    else
        list "Not synced yet:" "$(sed -nE \
            -e 's/.*- Path1 +(File[^-]*[^ -]) +- (.*)/  ~\/Cloud: \1: \2/p' \
            -e 's/.*- Path2 +(File[^-]*[^ -]) +- (.*)/  Drive:   \1: \2/p' <<<"$out")" ||
            echo "Up to date."
    fi
    list "Left in ~/Cloud by interrupted downloads (safe to delete):" \
        "$(find ~/Cloud -name '*.cloud.partial' -printf '  %P\n' 2>/dev/null)" && ok=1
    list "Conflict copies in ~/Cloud to review:" \
        "$(find ~/Cloud -name '*.cloud-conflict-[0-9]*' -printf '  %P\n' 2>/dev/null)" && ok=1

    if [[ ${1:-} == --verify ]]; then
        echo "Comparing every file with its copy on Drive (changes not synced yet count as differences):"
        rclone check ~/Cloud gdrive: --exclude '*.cloud.partial' 2>&1 |
            sed -E 's/^[0-9/]+ [0-9:]+ +[A-Z]+ *: /  /' || ok=1
    fi
    return "$ok"
}

case "$*" in
    setup)                      setup ;;
    "setup --reconnect")        need_config; rclone config reconnect gdrive: --auto-confirm ;;
    sync | "sync "*)            shift; bisync "$@" ;;
    status | "status --verify") shift; status "$@" ;;
    *) echo "usage: cloud setup [--reconnect] | sync [rclone bisync flags] | status [--verify]" >&2
       exit 2 ;;
esac

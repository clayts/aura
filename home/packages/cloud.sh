# cloud: two-way sync of ~/Cloud with an encrypted folder on Google Drive.
#
#   cloud setup                one-time setup; ~/Cloud must be empty
#   cloud setup --reconnect    sign in to Google again, e.g. if access has expired;
#                              rclone opens the browser and fills in its defaults
#   cloud sync [flags]         two-way sync; extra flags go to rclone bisync
#   cloud status [--verify]    what the next sync would change, and anything that
#                              needs attention. --verify also compares every file
#                              with its copy on Drive, which reads all of ~/Cloud.
#
# A dedicated rclone config (~/.config/cloud.conf) holds two remotes: gdrive
# (Google Drive) and crypt (encrypts gdrive:cloud). The config is encrypted
# with a random key kept in the GNOME keyring. ~/Cloud/.cloud is kept on
# both sides: bisync only runs when it can see it on both (--check-access), and
# setup looks it up to check the passphrase. bisync's record of the last sync is
# kept in ~/.local/state/cloud.

export RCLONE_CONFIG=$HOME/.config/cloud.conf
export RCLONE_PASSWORD_COMMAND="secret-tool lookup service cloud account rclone-config"
export RCLONE_COLOR=NEVER  # plain logs: bisync colours some lines even when not on a terminal
state=$HOME/.local/state/cloud  # bisync's record of the last sync

die() { echo "cloud: $*" >&2; exit 1; }

need_config() {
    [[ -e $RCLONE_CONFIG ]] ||
        die "there's no $RCLONE_CONFIG; to set up again, move ~/Cloud aside and run: cloud setup"
}

# Is there a record (lst) or backup record (lst-old) of the last sync? A glob that
# matches nothing stays as it is. (Not compgen: Nix's non-interactive bash lacks it.)
record() { local files=("$state"/*."$1"); [[ -e ${files[0]} ]]; }

bisync() {
    local net
    # Quick checks first, so a run that can't work (from a timer, say) stops at once,
    # rather than after rclone has listed both sides, or retried for minutes offline.
    need_config
    [[ -e $HOME/Cloud/.cloud ]] || die "there's no ~/Cloud/.cloud"
    # rclone wrongly calls a missing record "retryable without --resync". --recover can
    # fall back on the backup record, but if that's gone too, only --resync rebuilds it.
    record lst || record lst-old || [[ $* == *--resync* ]] ||
        die "there's no record of the last sync; run: cloud sync --resync"
    net=$(LC_ALL=C nmcli -t networking connectivity check || true)
    [[ $net == full ]] || die "no internet connection (NetworkManager says: ${net:-nothing})"
    # Downloads are written to name.xxxxxxxx.cloud.partial and then renamed. If rclone
    # is killed, the leftover is excluded so it's never uploaded as a real file.
    # A file changed on both sides: the newer copy wins, the other is kept as
    # name.cloud-conflict-N.ext. bisync stops if over half the files on one side were
    # deleted; --max-delete is that percentage (rclone's help calls it a count), so 100
    # lets any number of deletions through.
    rclone bisync "$HOME/Cloud" crypt: --workdir "$state" \
        --check-access --check-filename .cloud --create-empty-src-dirs \
        --resilient --recover --max-lock 2m --max-delete 100 \
        --conflict-resolve newer --conflict-suffix cloud-conflict- --suffix-keep-extension \
        --partial-suffix .cloud.partial --exclude '*.cloud.partial' "$@" && return
    local rc=$?
    # If copying fails part-way, rclone sets the record aside and says "Must run --resync
    # to recover". It's wrong too: --recover makes the next sync use the backup record.
    if [[ $* != *--resync* ]] && ! record lst && record lst-old; then
        echo "cloud: no need for --resync; the next sync recovers by itself" >&2
    fi
    return "$rc"
}

set_passphrase() {
    rclone config create crypt crypt remote=gdrive:cloud password="$1" --obscure --no-output
}

setup() {
    [[ -z $(ls -A "$HOME/Cloud" 2>/dev/null) ]] || die "$HOME/Cloud isn't empty"
    [[ ! -e $RCLONE_CONFIG ]] || die "$RCLONE_CONFIG exists; delete it to set up again"

    local id secret="" pass again listing rc=0
    read -rp "Google API client ID (empty for rclone's shared one): " id
    if [[ -n $id ]]; then read -rsp "Client secret: " secret; echo; fi
    IFS= read -rsp "Passphrase for the encrypted files: " pass; echo
    IFS= read -rsp "Repeat it: " again; echo
    [[ -n $pass && $pass == "$again" ]] || die "the passphrases must match and can't be empty"

    # Random key for the config, kept in the GNOME keyring. The config starts out
    # encrypted, so the token and passphrase are never on disk in plain text.
    head -c 32 /dev/urandom | base64 |
        secret-tool store --label="cloud rclone config" service cloud account rclone-config
    rclone -q config encryption set >/dev/null

    # Google Drive; rclone opens a browser to sign in. rclone's shared client ID
    # is being retired: https://rclone.org/drive/#making-your-own-client-id
    rclone config create gdrive drive scope=drive client_id="$id" client_secret="$secret" \
        config_shared_client_id=true --no-output
    set_passphrase "$pass"

    listing=$(rclone lsf gdrive:cloud 2>/dev/null) || rc=$?
    (( rc == 0 || rc == 3 )) || die "couldn't read gdrive:cloud (rclone exit code $rc)"
    if [[ -n $listing ]]; then
        # gdrive:cloud already exists. A wrong passphrase encrypts the name
        # .cloud differently, so it isn't found.
        until rclone -q lsjson --stat crypt:.cloud >/dev/null; do
            IFS= read -rsp "That doesn't unlock gdrive:cloud. Passphrase: " pass; echo
            set_passphrase "$pass"
        done
    else
        echo "gdrive:cloud is empty or missing, so this starts a new one."
        echo "☁️" | rclone -q rcat crypt:.cloud
    fi

    mkdir -p "$HOME/Cloud"
    rclone copyto crypt:.cloud "$HOME/Cloud/.cloud"
    # Start a new record. --resync would keep one from an earlier setup as the backup
    # record, and a failed sync falling back on it could delete files.
    rm -rf "$state"
    bisync --resync || die "the first sync failed; once fixed, run: cloud sync --resync"
}

# Exits 1 if anything needs attention; changes waiting for the next sync don't count.
status() {
    local ok=0 found out
    need_config
    grep -q '^RCLONE_ENCRYPT_V0:' "$RCLONE_CONFIG" || { echo "The config isn't encrypted."; ok=1; }
    if out=$(rclone -q config redacted gdrive) && ! grep -q '^client_id = .' <<<"$out"; then
        echo "Using rclone's shared Google client ID, which is being retired:"
        echo "  https://rclone.org/drive/#making-your-own-client-id"
        ok=1
    fi
    # bisync rewrites its record after every successful sync.
    if record path1.lst; then
        echo "Last successful sync: $(date -r "$state"/*.path1.lst '+%Y-%m-%d %H:%M')"
    fi

    if out=$(bisync --dry-run -v 2>&1); then
        found=$(sed -nE -e 's/.*- Path1 +(File[^-]*[^ -]) +- (.*)/  ~\/Cloud: \1: \2/p' \
                         -e 's/.*- Path2 +(File[^-]*[^ -]) +- (.*)/  Drive:   \1: \2/p' <<<"$out")
        if [[ -n $found ]]; then echo "Not synced yet:"; echo "$found"; else echo "Up to date."; fi
    else
        grep -E 'ERROR|CRITICAL|Failed to|^cloud:' <<<"$out" >&2 || true
        ok=1
    fi
    # crypt skips names it can't decrypt, so sync never touches these.
    found=$(sed -nE 's/.*NOTICE: (.*): Skipping undecryptable .*/  \1/p' <<<"$out" | sort -u)
    [[ -z $found ]] || { echo "In gdrive:cloud but not encrypted with this passphrase:"; echo "$found"; ok=1; }
    found=$(find "$HOME/Cloud" -name '*.cloud.partial' -printf '  %P\n' 2>/dev/null) || true
    [[ -z $found ]] || { echo "Left in ~/Cloud by interrupted downloads (safe to delete):"; echo "$found"; ok=1; }
    found=$(find "$HOME/Cloud" -name '*.cloud-conflict-[0-9]*' -printf '  %P\n' 2>/dev/null) || true
    [[ -z $found ]] || { echo "Conflict copies in ~/Cloud to review:"; echo "$found"; ok=1; }

    if [[ ${1:-} == --verify ]]; then
        # cryptcheck doesn't download your files: it encrypts each local file with the
        # nonce from the header of its copy on Drive and compares the checksums.
        echo "Comparing every file with its copy on Drive (changes not synced yet count as differences):"
        out=$(rclone cryptcheck "$HOME/Cloud" crypt: --exclude '*.cloud.partial' 2>&1) || ok=1
        sed -E -e '/Skipping undecryptable/d' -e 's/^[0-9/]+ [0-9:]+ +[A-Z]+ *: /  /' <<<"$out"
    fi
    return "$ok"
}

case "$*" in
    setup)               setup ;;
    "setup --reconnect") need_config; rclone config reconnect gdrive: --auto-confirm ;;
    sync | "sync "*)     shift; bisync "$@" ;;
    status)              status ;;
    "status --verify")   status --verify ;;
    *) echo "usage: cloud setup [--reconnect] | sync [rclone bisync flags] | status [--verify]" >&2
       exit 2 ;;
esac

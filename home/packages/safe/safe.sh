# safe: an encrypted folder, using gocryptfs.
#
#   safe create PATH    make a new safe at PATH, which mustn't exist yet
#   safe unlock PATH    unlock the safe at PATH, and print where it's unlocked
#   safe lock PATH      lock it again
#
# A safe is a folder holding a gocryptfs filesystem in a hidden .encrypted
# folder, and a file called Access. PATH can be the folder or its Access file.
# Access holds just a line that gets it recognised as a safe (safe.xml), so
# double-clicking it in Nautilus unlocks the safe. .encrypted is an ordinary
# gocryptfs filesystem, which gocryptfs can also mount by itself. A safe called
# NAME is unlocked at /run/media/$USER/Safe/NAME, which Nautilus lists in its
# sidebar, where ejecting it locks the safe again. That folder only exists
# while the safe is unlocked.
#
# From a terminal, safe asks for passwords there. Otherwise (from Nautilus) it
# asks in a dialog, and opens the safe in the file manager once it's unlocked.

media=/run/media/$(id -un)/Safe

if [[ -t 0 ]]; then
    terminal=true
else
    terminal=false
fi

say() {
    echo "safe: $*" >&2
    $terminal || zenity --error --no-markup --title=Safe --text="$*" 2>/dev/null || true
}

die() {
    say "$@"
    exit 1
}

# ask PROMPT: print the password the user gives, or fail if they cancel
ask() {
    if $terminal; then
        local password
        read -rsp "$1: " password && echo >&2 && printf %s "$password"
    else
        zenity --password --title="$1" 2>/dev/null
    fi
}

is_unlocked() { findmnt --mountpoint "$unlocked" --source "$data" >/dev/null; }

usage="usage: safe create|unlock|lock PATH"
(($# == 2)) || die "$usage"
path=$2
[[ $1 != create && -f $path ]] && path=$(dirname -- "$path")
safe=$(realpath -m -- "$path")
name=$(basename -- "$safe")
access=$safe/Access
data=$safe/.encrypted
unlocked=$media/$name

case $1 in
    create)
        [[ ! -e $safe ]] || die "$2 already exists"
        password=$(ask Password) || exit 1
        repeat=$(ask Repeat) || exit 1
        [[ $password == "$repeat" ]] || die "passwords don't match"
        mkdir -p -- "$data"
        gocryptfs -init -passfile <(printf %s "$password") -- "$data"
        # What gets Access recognised (safe.xml)
        printf '🔒 [Safe] 🔒\n' >"$access"
        ;;
    unlock)
        if ! is_unlocked; then
            [[ -f $access && -f $data/gocryptfs.conf ]] || die "$2 isn't a safe"
            ! findmnt --mountpoint "$unlocked" >/dev/null ||
                die "another safe called $name is unlocked"
            error=$(mktemp)
            trap 'rm -f -- "$error"' EXIT
            prompt="Password for $name"
            while :; do
                password=$(ask "$prompt") || exit 1
                mkdir -p -- "$unlocked"
                # gocryptfs runs in the foreground of a session of its own,
                # outliving this script, so that once the safe is locked (by
                # safe lock or by ejecting it) it can remove where it was
                # unlocked
                # shellcheck disable=SC2016
                setsid "$BASH" -c '
                    gocryptfs -q -fg -passfile "$1" -- "$2" "$3"
                    status=$?
                    rmdir -- "$3"
                    exit "$status"
                ' gocryptfs <(printf %s "$password") "$data" "$unlocked" \
                    </dev/null >/dev/null 2>"$error" &
                pid=$!
                while kill -0 "$pid" 2>/dev/null && ! is_unlocked; do
                    sleep 0.1
                done
                is_unlocked && break
                status=0
                wait "$pid" || status=$?
                ((status == 12)) || die "couldn't unlock $name: $(<"$error")"
                prompt="Wrong password for $name, try again"
            done
        fi
        echo "$unlocked"
        $terminal || gio open "$unlocked"
        ;;
    lock)
        is_unlocked || die "$name isn't unlocked"
        # fusermount3 is NixOS's setuid wrapper, so it isn't in runtimeInputs
        error=$(fusermount3 -u "$unlocked" 2>&1) || die "couldn't lock $name: $error"
        ;;
    *) die "$usage" ;;
esac

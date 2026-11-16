# safe: an encrypted folder, using gocryptfs.
#
#   safe create PATH    make a new safe at PATH, which mustn't exist yet
#   safe unlock PATH    unlock the safe at PATH, and print where it's unlocked
#   safe lock PATH      lock it again
#
# A safe is a folder holding an ordinary gocryptfs filesystem in a hidden
# .encrypted folder, and a file called Access, whose line gets it recognised as
# a safe (safe.xml), so double-clicking it in Nautilus unlocks the safe. PATH
# can be the folder or its Access file. A safe called NAME is unlocked at
# /run/media/$USER/Safe/NAME, which only exists while it's unlocked, and which
# Nautilus lists in its sidebar, where ejecting it locks the safe.
#
# From a terminal, safe asks for passwords there. Otherwise (from Nautilus) it
# asks, and reports errors, in dialogs, and opens the safe once it's unlocked.

terminal() { [[ -t 0 ]]; }

die() {
    echo "safe: $*" >&2
    terminal || zenity --error --no-markup --title=Safe --text="$*" 2>/dev/null
    exit 1
}

# ask PROMPT: print the password the user gives (asking again if it's empty),
# or fail if they cancel
ask() {
    local password=
    while [[ -z $password ]]; do
        if terminal; then
            IFS= read -rsp "$1: " password || { echo >&2; return 1; }
            echo >&2
        else
            password=$(zenity --password --title="$1" 2>/dev/null) || return
        fi
    done
    printf %s "$password"
}

is_unlocked() { findmnt --mountpoint "$unlocked" --source "$data" >/dev/null; }

[[ $# == 2 && $1 =~ ^(create|unlock|lock)$ ]] || die "usage: safe create|unlock|lock PATH"
safe=$(realpath -m -- "$2")
[[ $1 != create && -f $safe ]] && safe=${safe%/*}
name=${safe##*/}
data=$safe/.encrypted
unlocked=/run/media/$(id -un)/Safe/$name

case $1 in
    create)
        [[ ! -e $safe ]] || die "$2 already exists"
        password=$(ask Password) || exit 1
        repeat=$(ask Repeat) || exit 1
        [[ $password == "$repeat" ]] || die "passwords don't match"
        mkdir -p -- "$data"
        gocryptfs -init -passfile <(printf %s "$password") -- "$data" || {
            rm -rf -- "$safe"
            exit 1
        }
        printf '🔒 [Safe] 🔒\n' >"$safe/Access"
        ;;
    unlock)
        if ! is_unlocked; then
            [[ -f $safe/Access && -f $data/gocryptfs.conf ]] || die "$2 isn't a safe"
            ! findmnt --mountpoint "$unlocked" >/dev/null || die "another safe called $name is unlocked"
            error=$(mktemp)
            trap 'rm -f -- "$error"' EXIT
            prompt="Password for $name"
            while :; do
                password=$(ask "$prompt") || exit 1
                mkdir -p -- "$unlocked"
                # gocryptfs runs in the foreground of a session of its own,
                # outliving this script, so that it can remove where the safe
                # was unlocked once it's locked, however that happens
                # shellcheck disable=SC2016
                setsid "$BASH" -c 'trap "rmdir -- \"\$3\"" EXIT; gocryptfs -q -fg -passfile "$1" -- "$2" "$3"' \
                    gocryptfs <(printf %s "$password") "$data" "$unlocked" </dev/null >/dev/null 2>"$error" &
                while kill -0 $! 2>/dev/null && ! is_unlocked; do
                    sleep 0.1
                done
                is_unlocked && break
                status=0
                wait $! || status=$?
                ((status == 12)) || die "couldn't unlock $name: $(<"$error")"
                prompt="Wrong password for $name, try again"
            done
        fi
        echo "$unlocked"
        terminal || gio open "$unlocked"
        ;;
    lock)
        is_unlocked || die "$name isn't unlocked"
        # fusermount3 is NixOS's setuid wrapper, so it isn't in runtimeInputs
        error=$(fusermount3 -u "$unlocked" 2>&1) || die "couldn't lock $name: $error"
        ;;
esac

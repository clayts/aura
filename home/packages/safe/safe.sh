# A safe at /x/y/z keeps its encrypted data in /x/y/z/locked, and is mounted
# at /x/y/z/unlocked while unlocked. Its root holds a .xdg-volume-info naming
# the mount z, so file managers label it z rather than "unlocked".

die() {
    echo "$*" >&2
    exit 1
}

usage() { die "usage: ${0##*/} create|unlock|lock|delete [PATH]"; }

# Read the mount table rather than stat the mount point, which fails on a
# dead gocryptfs mount
mounted() { findmnt --mountpoint "$UNLOCKED" >/dev/null; }

is_safe() { [[ -f $LOCKED/gocryptfs.conf ]]; }

(($# == 1 || $# == 2)) || usage

# PATH defaults to the safe the current directory is in, so that safe lock
# works from anywhere inside it, or else the current directory itself.
# realpath -m makes it absolute and canonical without needing it to exist.
enclosing_safe() {
    local dir=$PWD
    while [[ -n $dir ]]; do
        [[ -f $dir/locked/gocryptfs.conf ]] && break
        dir=${dir%/*}
    done
    echo "${dir:-$PWD}"
}
SAFE=$(realpath -m -- "${2:-$(enclosing_safe)}")
LOCKED=$SAFE/locked
UNLOCKED=$SAFE/unlocked

case $1 in
    create)
        is_safe && die "$SAFE is already a safe"
        [[ ! -e $SAFE || (-d $SAFE && -z $(ls -A -- "$SAFE")) ]] || die "$SAFE isn't an empty directory"
        # Ask once and reuse the password for both -init and the mount that
        # writes .xdg-volume-info, rather than having gocryptfs ask three times
        read -rsp "Password: " password && echo
        read -rsp "Repeat: " repeat && echo
        [[ $password == "$repeat" ]] || die "Passwords don't match"
        [[ -n $password ]] || die "Password can't be empty"
        created=
        [[ -e $SAFE ]] || created=1
        # Leave nothing behind if anything fails or is interrupted. Unmount
        # first, and give up if that fails, so nothing is removed through the
        # mount.
        cleanup() {
            if mounted; then fusermount3 -u "$UNLOCKED" || return; fi
            rm -rf -- "$LOCKED" "$UNLOCKED"
            [[ -z $created ]] || rmdir -- "$SAFE"
        }
        trap cleanup EXIT
        mkdir -p -- "$LOCKED" "$UNLOCKED"
        gocryptfs -init -passfile <(printf %s "$password") "$LOCKED"
        gocryptfs -passfile <(printf %s "$password") "$LOCKED" "$UNLOCKED" >/dev/null
        printf '[Volume Info]\nName=%s\n' "${SAFE##*/}" >"$UNLOCKED/.xdg-volume-info"
        fusermount3 -u "$UNLOCKED"
        trap - EXIT
        echo "$SAFE created"
        ;;
    unlock)
        is_safe || die "$SAFE isn't a safe"
        mounted && die "$SAFE already unlocked"
        # gocryptfs prompts for the password itself
        gocryptfs "$LOCKED" "$UNLOCKED" >/dev/null
        echo "$SAFE unlocked"
        ;;
    lock)
        is_safe || die "$SAFE isn't a safe"
        mounted || die "$SAFE already locked"
        fusermount3 -u "$UNLOCKED"
        echo "$SAFE locked"
        ;;
    delete)
        is_safe || die "$SAFE isn't a safe"
        mounted && die "$SAFE is unlocked, lock it first"
        # Check before deleting anything that nothing but the safe is there,
        # including files left in unlocked while it was locked
        [[ -z $(ls -A -- "$UNLOCKED") ]] || die "$UNLOCKED isn't empty"
        shopt -s dotglob nullglob
        for entry in "$SAFE"/*; do
            [[ $entry == "$LOCKED" || $entry == "$UNLOCKED" ]] || die "$SAFE holds more than the safe"
        done
        read -rp "Delete $SAFE and everything in it for good? Type yes to confirm: " answer || true
        [[ $answer == yes ]] || die "$SAFE not deleted"
        rm -rf -- "$LOCKED"
        rmdir -- "$UNLOCKED" "$SAFE"
        echo "$SAFE deleted"
        ;;
    *) usage ;;
esac

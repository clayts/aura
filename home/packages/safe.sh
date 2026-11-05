# A safe at /x/y/z keeps its encrypted data in /x/y/.safe/z/locked. Unlocking
# mounts it at /x/y/.safe/z/unlocked and links /x/y/z there.

die() {
    echo "$*" >&2
    exit 1
}

usage() { die "usage: ${0##*/} create|unlock|lock|delete PATH"; }

# Read the mount table rather than stat the mount point, which fails on a
# dead gocryptfs mount
mounted() { findmnt --mountpoint "$UNLOCKED" >/dev/null; }

is_safe() { [[ -f $LOCKED/gocryptfs.conf ]]; }

(($# == 2)) || usage

# Make PATH absolute without following symlinks, as it is one while unlocked
SAFE=$(realpath -ms -- "$2")
NAME=${SAFE##*/}
DATA=${SAFE%/*}/.safe/$NAME
LOCKED=$DATA/locked
UNLOCKED=$DATA/unlocked

# gocryptfs prompts for the password itself
case $1 in
    create)
        is_safe && die "$SAFE is already a safe"
        [[ -e $SAFE || -L $SAFE ]] && die "$SAFE already exists"
        mkdir -p "$LOCKED" "$UNLOCKED"
        # Leave nothing behind if gocryptfs fails or is interrupted
        trap 'rmdir --ignore-fail-on-non-empty "$LOCKED" "$UNLOCKED" "$DATA" "${DATA%/*}"' EXIT
        gocryptfs -init "$LOCKED"
        trap - EXIT
        echo "$SAFE created"
        ;;
    unlock)
        is_safe || die "$SAFE isn't a safe"
        mounted && die "$SAFE already unlocked"
        # ln fails if SAFE exists. Remove the link again if gocryptfs fails or
        # is interrupted, e.g. at the password prompt.
        ln -sT -- ".safe/$NAME/unlocked" "$SAFE"
        trap 'rm -- "$SAFE"' EXIT
        gocryptfs "$LOCKED" "$UNLOCKED" >/dev/null
        trap - EXIT
        echo "$SAFE unlocked"
        ;;
    lock)
        is_safe || die "$SAFE isn't a safe"
        mounted || die "$SAFE already locked"
        fusermount3 -u "$UNLOCKED"
        rm -- "$SAFE"
        echo "$SAFE locked"
        ;;
    delete)
        is_safe || die "$SAFE isn't a safe"
        mounted && die "$SAFE is unlocked, lock it first"
        read -rp "Delete $SAFE and everything in it for good? Type yes to confirm: " answer || true
        [[ $answer == yes ]] || die "$SAFE not deleted"
        rm -rf -- "$DATA"
        rmdir --ignore-fail-on-non-empty -- "${DATA%/*}"
        echo "$SAFE deleted"
        ;;
    *) usage ;;
esac

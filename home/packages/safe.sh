# A safe at /x/y/z keeps its encrypted data in /x/y/.safe/z, and is mounted
# at /x/y/z while unlocked

die() {
    echo "$*" >&2
    exit 1
}

usage() { die "usage: ${0##*/} create|unlock|lock|delete PATH"; }

# Read the mount table rather than stat the mount point, which fails on a
# dead gocryptfs mount
mounted() { findmnt --mountpoint "$SAFE" >/dev/null; }

is_safe() { [[ -f $DATA/gocryptfs.conf ]]; }

(($# == 2)) || usage

# realpath -m makes PATH absolute and canonical without needing it to exist,
# and copes with a dead gocryptfs mount
SAFE=$(realpath -m -- "$2")
DATA=${SAFE%/*}/.safe/${SAFE##*/}

# gocryptfs prompts for the password itself
case $1 in
    create)
        is_safe && die "$SAFE is already a safe"
        [[ -e $SAFE ]] && die "$SAFE already exists"
        mkdir -p -- "$SAFE" "$DATA"
        # Leave nothing behind if gocryptfs fails or is interrupted
        trap 'rmdir --ignore-fail-on-non-empty -- "$SAFE" "$DATA" "${DATA%/*}"' EXIT
        gocryptfs -init "$DATA"
        trap - EXIT
        echo "$SAFE created"
        ;;
    unlock)
        is_safe || die "$SAFE isn't a safe"
        mounted && die "$SAFE already unlocked"
        gocryptfs "$DATA" "$SAFE" >/dev/null
        echo "$SAFE unlocked"
        ;;
    lock)
        is_safe || die "$SAFE isn't a safe"
        mounted || die "$SAFE already locked"
        fusermount3 -u "$SAFE"
        echo "$SAFE locked"
        ;;
    delete)
        is_safe || die "$SAFE isn't a safe"
        mounted && die "$SAFE is unlocked, lock it first"
        read -rp "Delete $SAFE and everything in it for good? Type yes to confirm: " answer || true
        [[ $answer == yes ]] || die "$SAFE not deleted"
        # rmdir fails if files were left in SAFE while it was locked, so do it
        # before deleting anything
        rmdir -- "$SAFE"
        rm -rf -- "$DATA"
        rmdir --ignore-fail-on-non-empty -- "${DATA%/*}"
        echo "$SAFE deleted"
        ;;
    *) usage ;;
esac

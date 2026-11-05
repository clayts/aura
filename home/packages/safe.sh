# A safe at /x/y/z keeps its encrypted data in /x/y/.safe/z, and is mounted
# at /x/y/z while unlocked

die() {
    echo "$*" >&2
    exit 1
}

usage() { die "usage: ${0##*/} create|unlock|lock|delete [PATH]"; }

# Read the mount table rather than stat the mount point, which fails on a
# dead gocryptfs mount
mounted() { findmnt --mountpoint "$SAFE" >/dev/null; }

is_safe() { [[ -f $DATA/gocryptfs.conf ]]; }

(($# == 1 || $# == 2)) || usage

# PATH defaults to the current directory. realpath -m makes it absolute and
# canonical without needing it to exist, and copes with a dead gocryptfs
# mount.
SAFE=$(realpath -m -- "${2:-.}")
DATA=${SAFE%/*}/.safe/${SAFE##*/}

# gocryptfs prompts for the password itself
case $1 in
    create)
        is_safe && die "$SAFE is already a safe"
        # The current directory can become a safe if it's empty, but any other
        # PATH mustn't exist yet
        if [[ $SAFE == "$(pwd -P)" ]]; then
            [[ -z $(ls -A) ]] || die "$SAFE isn't empty"
        elif [[ -e $SAFE ]]; then
            die "$SAFE already exists"
        fi
        mkdir -p -- "$DATA"
        # Leave nothing behind if gocryptfs fails or is interrupted
        trap 'rmdir --ignore-fail-on-non-empty -- "$DATA" "${DATA%/*}"' EXIT
        gocryptfs -init "$DATA"
        trap - EXIT
        mkdir -p -- "$SAFE"
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

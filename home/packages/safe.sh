# A safe at /x/y/z keeps its encrypted data in /x/y/.safe/z/locked. Unlocking
# mounts it at /x/y/.safe/z/unlocked and links /x/y/z there.

usage() {
    echo "usage: ${0##*/} create|unlock|lock|delete PATH" >&2
    exit 1
}

die() {
    echo "$*" >&2
    exit 1
}

# Read the mount table rather than stat the mount point, which fails on a
# dead gocryptfs mount
mounted() { findmnt --mountpoint "$UNLOCKED" >/dev/null; }

is_safe() { [[ -f $LOCKED/gocryptfs.conf ]]; }

(($# == 2)) || usage

# Make PATH absolute without following symlinks, as it is one while unlocked
SAFE=$(realpath -ms -- "$2")
DATA=${SAFE%/*}/.safe/${SAFE##*/}
LOCKED=$DATA/locked
UNLOCKED=$DATA/unlocked

# gocryptfs prompts for the password itself
case $1 in
    create)
        if is_safe; then
            die "$SAFE is already a safe"
        fi
        if [[ -e $SAFE || -L $SAFE ]]; then
            die "$SAFE already exists"
        fi
        mkdir -p "$LOCKED" "$UNLOCKED"
        # Leave nothing behind if gocryptfs fails or is interrupted
        trap 'rmdir --ignore-fail-on-non-empty "$LOCKED" "$UNLOCKED" "$DATA" "${DATA%/*}"' EXIT
        gocryptfs -init "$LOCKED"
        trap - EXIT
        echo "$SAFE created"
        ;;
    unlock)
        if ! is_safe; then
            die "$SAFE isn't a safe"
        fi
        if mounted; then
            die "$SAFE already unlocked"
        fi
        # ln fails if SAFE exists. Remove the link again if gocryptfs fails or
        # is interrupted, e.g. at the password prompt.
        ln -sT -- ".safe/${SAFE##*/}/unlocked" "$SAFE"
        trap 'rm -- "$SAFE"' EXIT
        gocryptfs "$LOCKED" "$UNLOCKED" >/dev/null
        trap - EXIT
        echo "$SAFE unlocked"
        ;;
    lock)
        if ! is_safe; then
            die "$SAFE isn't a safe"
        fi
        if ! mounted; then
            die "$SAFE already locked"
        fi
        fusermount3 -u "$UNLOCKED"
        rm -- "$SAFE"
        echo "$SAFE locked"
        ;;
    delete)
        if ! is_safe; then
            die "$SAFE isn't a safe"
        fi
        if mounted; then
            die "$SAFE is unlocked, lock it first"
        fi
        read -rp "Delete $SAFE and everything in it for good? Type yes to confirm: " answer || true
        if [[ $answer != yes ]]; then
            die "$SAFE not deleted"
        fi
        # Once confirmed, don't let Ctrl-C leave a half-deleted safe behind
        trap '' INT
        rm -rf -- "$DATA"
        rmdir --ignore-fail-on-non-empty -- "${DATA%/*}"
        echo "$SAFE deleted"
        ;;
    *)
        usage
        ;;
esac

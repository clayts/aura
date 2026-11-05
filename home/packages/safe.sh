# A safe at /x/y/z keeps its encrypted data in /x/y/.safe/z, and /x/y/z only
# exists while the safe is unlocked

usage() {
    echo "usage: ${0##*/} create|unlock|lock PATH" >&2
    exit 1
}

die() {
    echo "$*" >&2
    exit 1
}

# Read the mount table rather than stat the mount point, which fails on a
# dead gocryptfs mount
mounted() { findmnt --mountpoint "$MOUNT_DIR" >/dev/null; }

is_safe() { [[ -f $CIPHER_DIR/gocryptfs.conf ]]; }

(($# == 2)) || usage

# realpath -m makes PATH absolute and canonical without needing it to exist,
# and copes with a dead gocryptfs mount
MOUNT_DIR=$(realpath -m -- "$2")
CIPHER_DIR=${MOUNT_DIR%/*}/.safe/${MOUNT_DIR##*/}

# gocryptfs prompts for the password itself
case $1 in
    create)
        if is_safe; then
            die "$MOUNT_DIR is already a safe"
        fi
        if [[ -e $MOUNT_DIR ]]; then
            die "$MOUNT_DIR already exists"
        fi
        mkdir -p "$CIPHER_DIR"
        gocryptfs -init "$CIPHER_DIR"
        echo "$MOUNT_DIR created"
        ;;
    unlock)
        if ! is_safe; then
            die "$MOUNT_DIR isn't a safe"
        fi
        if mounted; then
            die "$MOUNT_DIR already unlocked"
        fi
        # mkdir fails if MOUNT_DIR exists. Remove it again if gocryptfs fails
        # or is interrupted, e.g. at the password prompt.
        mkdir "$MOUNT_DIR"
        trap 'rmdir "$MOUNT_DIR"' EXIT
        gocryptfs "$CIPHER_DIR" "$MOUNT_DIR" >/dev/null
        trap - EXIT
        echo "$MOUNT_DIR unlocked"
        ;;
    lock)
        if ! is_safe; then
            die "$MOUNT_DIR isn't a safe"
        fi
        if ! mounted; then
            die "$MOUNT_DIR already locked"
        fi
        fusermount3 -u "$MOUNT_DIR"
        rmdir "$MOUNT_DIR"
        echo "$MOUNT_DIR locked"
        ;;
    *)
        usage
        ;;
esac

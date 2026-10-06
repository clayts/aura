CIPHER_DIR=~/.local/share/safe/locked
MOUNT_DIR=~/.local/share/safe/unlocked

# Read the mount table rather than stat the mount point, which fails on a
# dead gocryptfs mount
mounted() { findmnt --mountpoint "$MOUNT_DIR" >/dev/null; }

case "${1:-}" in
    unlock)
        if mounted; then
            echo ~/Safe already unlocked >&2
            exit 1
        fi
        mkdir -p "$CIPHER_DIR" "$MOUNT_DIR"
        # gocryptfs doesn't create a vault on first use like cryfs did
        if [[ ! -f $CIPHER_DIR/gocryptfs.conf ]]; then
            echo "No existing vault found, creating one."
            gocryptfs -init "$CIPHER_DIR"
        fi
        # gocryptfs prompts for the password itself
        gocryptfs "$CIPHER_DIR" "$MOUNT_DIR" >/dev/null
        ln -sfn "$MOUNT_DIR" ~/Safe
        echo ~/Safe unlocked
        ;;
    lock)
        if ! mounted; then
            rm -f ~/Safe
            echo ~/Safe already locked >&2
            exit 1
        fi
        fusermount -u "$MOUNT_DIR"
        rm -f ~/Safe
        echo ~/Safe locked
        ;;
    status)
        if mounted; then
            echo ~/Safe is unlocked
        else
            echo ~/Safe is locked
        fi
        ;;
    *)
        echo "usage: ${0##*/} status|lock|unlock" >&2
        exit 1
        ;;
esac

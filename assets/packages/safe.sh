set -euo pipefail

CIPHER_DIR=~/.local/share/safe/locked
MOUNT_DIR=~/.local/share/safe/unlocked

case "$1" in
    unlock)
        if [ -d ~/Safe ]; then
            echo ~/Safe already unlocked
            exit 1
        else
            mkdir -p "$CIPHER_DIR" "$MOUNT_DIR"

            # gocryptfs doesn't auto-init like cryfs does, so create the
            # vault on first use.
            if [ ! -f "$CIPHER_DIR/gocryptfs.conf" ]; then
                echo "No existing vault found, creating one."
                gocryptfs -init "$CIPHER_DIR"
            fi

            # gocryptfs prompts for "Password:" itself (with echo off),
            # so there's no need to prompt manually beforehand.
            (gocryptfs "$CIPHER_DIR" "$MOUNT_DIR" > /dev/null &&
            echo "✔") || exit 1
            ln -s "$MOUNT_DIR" ~/Safe
            echo ~/Safe unlocked
        fi
        ;;
    lock)
        if [ -d ~/Safe ]; then
            fusermount -u "$MOUNT_DIR" > /dev/null
            rm ~/Safe
            echo ~/Safe locked
        else
            echo ~/Safe already locked
            exit 1
        fi
        ;;
    status)
        if [ -d ~/Safe ]; then
            echo ~/Safe is unlocked
        else
            echo ~/Safe is locked
        fi
        ;;
    *)
        echo "usage: $0 [status|lock|unlock]"
        exit 1
        ;;
esac

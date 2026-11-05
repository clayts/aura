# A safe at /x/y/z keeps its encrypted data in /x/y/.safe/z

usage() {
    echo "usage: ${0##*/} create|unlock|lock PATH" >&2
    echo "       ${0##*/} status [PATH]" >&2
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

if [[ ${1:-} == status ]] && (($# == 1)); then
    # findmnt -r escapes awkward characters in paths, e.g. spaces as \x20
    found=
    while read -r source target; do
        if [[ $source == "${target%/*}/.safe/${target##*/}" ]]; then
            printf '%b is unlocked\n' "$target"
            found=1
        fi
    done < <(findmnt -rn -t fuse.gocryptfs -o SOURCE,TARGET || true)
    if [[ -z $found ]]; then
        echo "No safes are unlocked"
    fi
    exit
fi

(($# == 2)) || usage

# PATH may be relative, and may also name the safe's encrypted directory.
# realpath -m copes with a dead gocryptfs mount.
path=$(realpath -m -- "$2")
parent=${path%/*}
name=${path##*/}
[[ -n $name ]] || die "/ can't be a safe"
if [[ ${parent##*/} == .safe ]]; then
    MOUNT_DIR=${parent%/*}/$name
    CIPHER_DIR=$path
else
    MOUNT_DIR=$path
    CIPHER_DIR=$parent/.safe/$name
fi

case $1 in
    create)
        if is_safe; then
            die "$MOUNT_DIR is already a safe"
        fi
        if [[ -e $MOUNT_DIR && -n $(ls -A -- "$MOUNT_DIR") ]]; then
            die "$MOUNT_DIR already exists and isn't an empty directory"
        fi
        mkdir -p "$CIPHER_DIR" "$MOUNT_DIR"
        # gocryptfs prompts for the password itself
        gocryptfs -init "$CIPHER_DIR"
        gocryptfs "$CIPHER_DIR" "$MOUNT_DIR" >/dev/null
        echo "$MOUNT_DIR created and unlocked"
        ;;
    unlock)
        if ! is_safe; then
            die "$MOUNT_DIR isn't a safe"
        fi
        if mounted; then
            die "$MOUNT_DIR already unlocked"
        fi
        mkdir -p "$MOUNT_DIR"
        gocryptfs "$CIPHER_DIR" "$MOUNT_DIR" >/dev/null
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
        echo "$MOUNT_DIR locked"
        ;;
    status)
        if ! is_safe; then
            die "$MOUNT_DIR isn't a safe"
        fi
        if mounted; then
            echo "$MOUNT_DIR is unlocked"
        else
            echo "$MOUNT_DIR is locked"
        fi
        ;;
    *)
        usage
        ;;
esac

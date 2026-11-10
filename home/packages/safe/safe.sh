# A safe at /x/y/z keeps its encrypted data in /x/y/z/locked and is mounted at
# /x/y/z/unlocked. A .xdg-volume-info in its root names the mount z for file
# managers.

die() {
    echo "$*" >&2
    exit 1
}

(($# == 2)) || die "usage: ${0##*/} create|unlock|lock PATH"

SAFE=$(realpath -m -- "$2")

case $1 in
    create)
        [[ ! -e $SAFE ]] || die "$SAFE already exists"
        # Ask once, as -init and the mount that writes .xdg-volume-info would
        # each ask otherwise
        read -rsp "Password: " password && echo
        read -rsp "Repeat: " repeat && echo
        [[ $password == "$repeat" ]] || die "Passwords don't match"
        mkdir -p -- "$SAFE/locked" "$SAFE/unlocked"
        gocryptfs -init -passfile <(printf %s "$password") "$SAFE/locked"
        gocryptfs -passfile <(printf %s "$password") "$SAFE/locked" "$SAFE/unlocked" >/dev/null
        printf '[Volume Info]\nName=%s\n' "${SAFE##*/}" >"$SAFE/unlocked/.xdg-volume-info"
        fusermount3 -u "$SAFE/unlocked"
        ;;
    unlock) gocryptfs "$SAFE/locked" "$SAFE/unlocked" >/dev/null ;;
    lock) fusermount3 -u "$SAFE/unlocked" ;;
    *) die "usage: ${0##*/} create|unlock|lock PATH" ;;
esac

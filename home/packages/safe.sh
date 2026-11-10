# safe: an encrypted directory, using gocryptfs.
#
#   safe create PATH    make a new safe at PATH, which mustn't exist yet
#   safe unlock PATH    mount the safe at PATH
#   safe lock PATH      unmount it
#
# A safe at /x/y/z keeps its encrypted data in /x/y/z/Locked and is mounted at
# /x/y/z/Unlocked. A .xdg-volume-info inside it gives the mount the name z in
# file managers, rather than "Unlocked".

die() { echo "safe: $*" >&2; exit 1; }

(($# == 2)) || die "usage: safe create|unlock|lock PATH"
safe=$2

case $1 in
    create)
        [[ ! -e $safe ]] || die "$safe already exists"
        # gocryptfs would ask for the password twice to create the safe and
        # again to mount it to write .xdg-volume-info, so ask once here
        read -rsp "Password: " password && echo
        read -rsp "Repeat: " repeat && echo
        [[ $password == "$repeat" ]] || die "passwords don't match"
        mkdir -p -- "$safe/Locked" "$safe/Unlocked"
        gocryptfs -init -passfile <(printf %s "$password") "$safe/Locked"
        gocryptfs -passfile <(printf %s "$password") "$safe/Locked" "$safe/Unlocked" >/dev/null
        printf '[Volume Info]\nName=%s\n' "$(basename -- "$safe")" >"$safe/Unlocked/.xdg-volume-info"
        fusermount3 -u "$safe/Unlocked"
        ;;
    unlock) gocryptfs "$safe/Locked" "$safe/Unlocked" >/dev/null ;;
    lock) fusermount3 -u "$safe/Unlocked" ;;
    *) die "usage: safe create|unlock|lock PATH" ;;
esac

# safe runs as its own process, so it can't move this shell around a safe it
# changes. So when the current directory is inside the safe, step out to its
# parent while safe runs, as an unmount fails while this shell is inside the
# mount, then back in to see the change. Use the builtin cd rather than
# zoxide's.
safe() {
    local dir=$PWD old=$OLDPWD target
    if [[ -n $2 ]]; then
        target=${2:A}
    else
        # As safe does, default to the safe the current directory is in, or
        # else the current directory itself
        target=$PWD
        until [[ -z $target || -f $target/locked/gocryptfs.conf ]]; do target=${target%/*}; done
        target=${target:-$PWD}
    fi
    [[ $dir/ == "$target"/* ]] || { command safe "$@"; return }
    {
        builtin cd -q -- "${target:h}" && command safe "$1" "$target"
    } always {
        # Land in the nearest directory that still exists, e.g. the mount
        # point after locking from deep inside it, or the parent after
        # deleting, and arrive from the previous directory so that cd - still
        # leads there
        while [[ ! -d $dir ]]; do dir=${dir:h}; done
        builtin cd -q -- "$old" 2>/dev/null
        builtin cd -- "$dir"
    }
}

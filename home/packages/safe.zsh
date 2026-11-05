# safe runs as its own process, so it can't move this shell around a safe it
# changes. So when the safe is the current directory, step out while safe runs,
# as an unmount fails while this shell is inside, then back in to see the
# change. Use the builtin cd rather than zoxide's.
safe() {
    local dir=$PWD old=$OLDPWD
    [[ ${${2:-.}:A} == ${dir:A} ]] || { command safe "$@"; return }
    {
        builtin cd -q .. && command safe "$1" "$dir"
    } always {
        # Land in the parent if the safe was deleted, and arrive from the
        # previous directory so that cd - still leads there
        [[ $1 == delete && ! -e $dir ]] && dir=${dir:h}
        builtin cd -q -- "$old" 2>/dev/null
        builtin cd -- "$dir"
    }
}

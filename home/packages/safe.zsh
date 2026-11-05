# safe runs as its own process, so it can't move this shell into a safe it
# unlocks, or out of one it locks or deletes. Do that here when the safe is the
# current directory, with the builtin cd rather than zoxide's.
safe() {
    local dir=$PWD
    [[ ${${2:-.}:A} == ${dir:A} ]] || { command safe "$@"; return }
    case $1 in
        # The mount arrived under this shell, so step into it
        unlock) command safe "$@" && builtin cd . ;;
        # The unmount fails while this shell is inside, so step out and back
        lock) { builtin cd -q .. && command safe lock "$dir" } always { builtin cd "$dir" } ;;
        # The folder is gone, so step out of it
        delete) command safe "$@" && builtin cd .. ;;
        *) command safe "$@" ;;
    esac
}

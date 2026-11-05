# safe runs as its own process, so it can't move this shell into a safe it
# unlocks or out of one it locks. Do that here when the safe is the current
# directory, with the builtin cd rather than zoxide's.
safe() {
    local dir=$PWD
    if [[ $1 != (un|)lock || ${${2:-.}:A} != ${dir:A} ]]; then
        command safe "$@"
    elif [[ $1 == unlock ]]; then
        # The mount arrived under this shell, so step into it
        command safe "$@" && builtin cd .
    else
        # The unmount fails while this shell is inside, so step out and back
        { builtin cd -q .. && command safe lock "$dir" } always { builtin cd "$dir" }
    fi
}

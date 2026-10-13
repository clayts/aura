usage() {
    cat <<USAGE
Usage: system <command> [--boot]

Commands:
  switch   Build the system in $flake as it is and switch to it
  sync     Pull $flake and switch to it, without updating its inputs; does
           nothing if the pull brings in no new commits
  update   Pull $flake, update its inputs, switch, then commit and push
           flake.lock; does nothing if neither brings in any changes
  clean    Delete old generations, collect garbage, optimise the store and
           prune old boot entries

Options:
  --boot   (switch, sync, update) Use the new system from the next boot instead
           of switching now
USAGE
}

fail() {
    echo "Error: $*" >&2
    exit 1
}

flake=$NH_FLAKE
cmd=${1:-}
if [[ $# -gt 0 ]]; then
    shift
fi

mode=switch
while [[ $# -gt 0 ]]; do
    case "$1" in
        --boot)
            mode=boot
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            fail "unknown option: $1"
            ;;
    esac
    shift
done

rebuild() {
    nh os "$mode" "$flake" -- --quiet
}

# Pull $flake and report whether that brought in any new commits. The
# explicit exit is needed because errexit is ignored when this is the
# condition of an if
pull() {
    local before
    before=$(git -C "$flake" rev-parse HEAD)
    git -C "$flake" pull --ff-only || exit
    [[ $(git -C "$flake" rev-parse HEAD) != "$before" ]]
}

# The update commits flake.lock on top of whatever is checked out, so refuse to
# start unless the working tree is clean
require_clean() {
    if [[ -n $(git -C "$flake" status --porcelain) ]]; then
        fail "$flake has uncommitted changes, commit or stash them first"
    fi
}

# Summarise the package changes between two system closures, skipping the
# header that names their store paths
closure_diff() {
    dix --color never "$1" "$2" | sed -n '/^[A-Z]/,$p'
}

case "$cmd" in
    switch)
        rebuild
        ;;
    sync)
        if ! pull; then
            echo "Already up to date, nothing to build"
            exit 0
        fi
        rebuild
        ;;
    update)
        require_clean
        pulled=false
        if pull; then
            pulled=true
        fi
        nix flake update --flake "$flake"
        if ! $pulled && git -C "$flake" diff --quiet -- flake.lock; then
            echo "Already up to date, nothing to build"
            exit 0
        fi
        old_system=$(readlink -f /nix/var/nix/profiles/system)
        rebuild
        new_system=$(readlink -f /nix/var/nix/profiles/system)
        # Only publish the new lock once the system has built with it
        if ! git -C "$flake" diff --quiet -- flake.lock; then
            printf 'Update flake.lock\n\n%s\n' "$(closure_diff "$old_system" "$new_system")" |
                git -C "$flake" commit --quiet --file - -- flake.lock
            git -C "$flake" push --quiet
        fi
        ;;
    clean)
        [[ $mode == switch ]] || fail "clean takes no options"
        nh clean all --optimise
        # Reinstall the bootloader so entries for deleted generations are removed
        sudo /nix/var/nix/profiles/system/bin/switch-to-configuration boot
        ;;
    -h | --help)
        usage
        ;;
    *)
        [[ -z $cmd ]] || echo "Unknown command: $cmd" >&2
        usage >&2
        exit 1
        ;;
esac

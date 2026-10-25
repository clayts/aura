usage() {
    cat <<USAGE
Usage: system <command> [--boot]

Commands:
  switch   Build the system in $NH_FLAKE as it is and switch to it
  sync     Pull $NH_FLAKE and switch to it, without updating its inputs; does
           nothing if the pull brings in no new commits
  update   Pull $NH_FLAKE, update its inputs, switch, then commit and push
           flake.lock; does nothing if neither brings in any changes
  clean    Delete old generations, collect garbage, optimise the store and
           prune old boot entries

Options:
  --boot   (switch, sync, update) Use the new system from the next boot instead
           of switching now
USAGE
}

cmd=${1:-}
mode=switch
if [[ $# -eq 2 && $2 == --boot && $cmd != clean ]]; then
    mode=boot
elif [[ $# -gt 1 ]]; then
    usage >&2
    exit 1
fi
cd "$NH_FLAKE" || exit

rebuild() {
    nh os "$mode" . -- --quiet
}

# Pull and report whether that brought in any new commits. The explicit exit
# is needed because errexit is ignored when this is the condition of an if
pull() {
    local before
    before=$(git rev-parse HEAD)
    git pull --ff-only || exit
    [[ $(git rev-parse HEAD) != "$before" ]]
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
        # The update commits flake.lock on top of whatever is checked out, so
        # the build must match HEAD apart from flake.lock, which is committed
        if [[ -n $(git status --porcelain -- . ':!flake.lock') ]]; then
            echo "$NH_FLAKE has uncommitted changes, commit or stash them first" >&2
            exit 1
        fi
        pulled=false
        pull && pulled=true
        nix flake update
        if ! $pulled && git diff --quiet -- flake.lock; then
            echo "Already up to date, nothing to build"
            exit 0
        fi
        old_system=$(readlink -f /nix/var/nix/profiles/system)
        rebuild
        # Only publish the new lock once the system has built with it, with a
        # summary of its package changes, skipping dix's header
        if ! git diff --quiet -- flake.lock; then
            diff=$(dix --color never "$old_system" "$(readlink -f /nix/var/nix/profiles/system)" | sed -n '/^[A-Z]/,$p')
            printf 'Update flake.lock\n\n%s\n' "$diff" | git commit --quiet --file - -- flake.lock
            git push --quiet
        fi
        ;;
    clean)
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

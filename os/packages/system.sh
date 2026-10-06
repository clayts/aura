usage() {
    cat <<USAGE
Usage: system <command> [options]

Commands:
  switch   Build the system in $flake and switch to it
  update   Pull $flake, update its inputs, switch, then commit and push flake.lock
  clean    Delete old generations, collect garbage, optimise the store and
           prune old boot entries

Options:
  --boot                   (switch, update) Use the new system from the next
                           boot instead of switching now
  --input <input> <path>   (switch, repeatable) Override a flake input with a
                           local path, e.g. --input nixpkgs ~/nixpkgs
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
overrides=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --boot)
            mode=boot
            shift
            ;;
        --input)
            if [[ $# -lt 3 || -z $2 || -z $3 || $2 == --* || $3 == --* ]]; then
                fail "--input needs two values: <input> <path>"
            fi
            overrides+=(--override-input "$2" "path:$3")
            shift 3
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            fail "unknown option: $1"
            ;;
    esac
done

rebuild() {
    nh os "$mode" "$flake" -- --quiet "${overrides[@]}"
}

case "$cmd" in
    switch)
        rebuild
        ;;
    update)
        [[ ${#overrides[@]} -eq 0 ]] || fail "update doesn't take --input"
        git -C "$flake" pull --ff-only
        nix flake update --flake "$flake"
        rebuild
        # Only publish the new lock once the system has built with it
        if ! git -C "$flake" diff --quiet -- flake.lock; then
            git -C "$flake" commit --quiet --message "Update flake.lock" -- flake.lock
            git -C "$flake" push --quiet
        fi
        ;;
    clean)
        [[ $mode == switch && ${#overrides[@]} -eq 0 ]] || fail "clean takes no options"
        nh clean all --optimise
        # Reinstall the bootloader so entries for deleted generations go
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

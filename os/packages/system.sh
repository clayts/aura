usage() {
    cat <<USAGE
Usage:
  system sync [--boot] [--input <input> <path>]...
  system clean

Commands:
  sync    Pull the flake in \$NH_FLAKE and rebuild the system (via nh os)
  clean   Collect garbage, optimise the store and prune old boot entries

Options:
  --boot                   (sync only) Apply on next boot instead of switching now
  --input <input> <path>   (sync only, repeatable) Override a flake input with a
                           local path instead of pulling, e.g. --input nixpkgs ~/nixpkgs
USAGE
}

flake=$NH_FLAKE

do_sync() {
    local subcmd=switch
    local overrides=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --boot)
                subcmd=boot
                shift
                ;;
            --input)
                if [[ $# -lt 3 || -z $2 || -z $3 || $2 == --* || $3 == --* ]]; then
                    echo "Error: --input requires two values: <input> <path>" >&2
                    exit 1
                fi
                echo "Overriding $2 with path:$3"
                overrides+=(--override-input "$2" "path:$3")
                shift 3
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown argument: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
    done
    if [[ ${#overrides[@]} -eq 0 ]]; then
        git -C "$flake" pull --ff-only
    fi
    nh os "$subcmd" "$flake" -- --quiet "${overrides[@]}"
}

do_clean() {
    if [[ $# -gt 0 ]]; then
        echo "Error: clean takes no options" >&2
        exit 1
    fi
    nh clean all --optimise
    # Reinstall the bootloader so entries for collected generations go
    sudo /nix/var/nix/profiles/system/bin/switch-to-configuration boot
}

case "${1:-}" in
    sync)
        shift
        do_sync "$@"
        ;;
    clean)
        shift
        do_clean "$@"
        ;;
    -h | --help)
        usage
        ;;
    "")
        usage >&2
        exit 1
        ;;
    *)
        echo "Unknown command: $1" >&2
        usage >&2
        exit 1
        ;;
esac

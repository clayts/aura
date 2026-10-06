#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage:
  system sync [--boot] [--input <input> <path>]
  system clean

Commands:
  sync                     Rebuild the system (via nh os)
  clean                    Run garbage collection / store optimisation

Options:
  --boot                 (sync only) Apply on next boot instead of switching now
  --input <input> <path>   (sync only) Override a flake input with a local path,
                           e.g. --input nixpkgs ~/nixpkgs
EOF
}

MODE=""
BOOT=0
INPUT_NAME=""
INPUT_PATH=""

# --- parse args -------------------------------------------------------
case "${1:-}" in
    sync|clean)
        MODE="$1"
        shift
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    "")
        echo "Error: must specify a command: sync or clean" >&2
        usage
        exit 1
        ;;
    *)
        echo "Unknown command: $1" >&2
        usage
        exit 1
        ;;
esac

while [[ $# -gt 0 ]]; do
    case "$1" in
        --boot)
            BOOT=1
            shift
            ;;
        --input)
            if [[ -z "${2:-}" || "$2" == --* || -z "${3:-}" || "$3" == --* ]]; then
                echo "Error: --input requires two values: <input> <path>" >&2
                exit 1
            fi
            INPUT_NAME="$2"
            INPUT_PATH="$3"
            shift 3
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
done

# --- validate -----------------------------------------------------------
if [[ "$MODE" == "clean" ]]; then
    if [[ $BOOT -eq 1 || -n "$INPUT_NAME" ]]; then
        echo "Error: --boot and --input are only valid with sync" >&2
        exit 1
    fi
fi

FLAKE_DIR="/etc/nixos"

# --- actions --------------------------------------------------------

do_sync() {
    local subcmd="switch"
    if [[ $BOOT -eq 1 ]]; then
        subcmd="boot"
    fi

    if [[ -n "$INPUT_NAME" ]]; then
        echo "Overriding $INPUT_NAME with path:$INPUT_PATH"
        nh os "$subcmd" "$FLAKE_DIR" -- --quiet --override-input "$INPUT_NAME" "path:$INPUT_PATH"
    else
        # --refresh: without it, nix may reuse a cached resolution (tarball-ttl,
        # root's cache under sudo) and miss an input revision pushed moments ago.
        sudo nix flake update --refresh --flake "$FLAKE_DIR"
        nh os "$subcmd" "$FLAKE_DIR" -- --quiet
    fi
}

do_clean() {
    nh clean all --optimise
    nh os boot
}

case "$MODE" in
    sync)  do_sync ;;
    clean) do_clean ;;
esac

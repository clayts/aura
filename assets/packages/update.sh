#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage:
  update [--commit [--push]]

Update flake.lock for the flake at the root of the current git repository.

Options:
  --commit   Check the git tree is clean, update flake.lock, and commit it
  --push     (commit only) Also check the current branch is in sync with its
             upstream before updating, then push the commit
EOF
}

COMMIT=0
PUSH=0

# --- parse args -------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --commit)
            COMMIT=1
            shift
            ;;
        --push)
            PUSH=1
            shift
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
if [[ $PUSH -eq 1 && $COMMIT -eq 0 ]]; then
    echo "Error: --push requires --commit" >&2
    exit 1
fi

root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Error: $PWD is not inside a git repository" >&2
    exit 1
}
cd "$root"

if [[ ! -f flake.nix ]]; then
    echo "Error: no flake.nix in $PWD" >&2
    exit 1
fi

# --- checks -----------------------------------------------------------

check_clean() {
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "Error: uncommitted changes; commit or stash them before using --commit" >&2
        exit 1
    fi
}

# Aborts on commits that exist locally but not on the remote (they'd be pushed
# along with the lock update), or on remote commits we don't have yet.
check_in_sync() {
    local upstream
    upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)" || {
        echo "Error: no upstream configured for the current branch" >&2
        exit 1
    }

    git fetch

    if [[ -n "$(git log --oneline "$upstream"..HEAD)" ]]; then
        echo "Error: unpushed commits; push or reset them before using --push" >&2
        git log --oneline "$upstream"..HEAD >&2
        exit 1
    fi

    # Drop this block if you'd rather let the push fail on non-fast-forward.
    if [[ -n "$(git log --oneline HEAD.."$upstream")" ]]; then
        echo "Error: behind $upstream; pull before using --push" >&2
        git log --oneline HEAD.."$upstream" >&2
        exit 1
    fi
}

# --- main -------------------------------------------------------------
if [[ $COMMIT -eq 1 ]]; then
    check_clean
fi
if [[ $PUSH -eq 1 ]]; then
    check_in_sync
fi

echo "Updating flake.lock..."
nix flake update

if [[ $COMMIT -eq 0 ]]; then
    exit 0
fi

if [[ -z "$(git status --porcelain)" ]]; then
    echo "flake.lock already up to date; nothing to commit"
    exit 0
fi

git add flake.lock
git commit -m "Update flake.lock"

if [[ $PUSH -eq 1 ]]; then
    git push origin HEAD
    # Give the remote a moment before anything (e.g. system sync) fetches it.
    sleep 3
fi

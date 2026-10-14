: "${templates:?}" # Set by runtimeEnv in home/packages/default.nix
: "${lock:?}" # Set by runtimeEnv in home/packages/default.nix

usage() {
    cat <<EOF
Usage: ${0##*/} <language> <name>

Create a project in ./<name>, with git and direnv set up.

Languages:
  go        Go module
  node      Node package
  python    Python script
  rust      Rust binary crate
  rust-lib  Rust library crate

Options:
  -h, --help  Show help
EOF
}

case "${1:-}" in
    -h | --help)
        usage
        exit
        ;;
esac
if [[ $# -ne 2 ]]; then
    usage >&2
    exit 1
fi
kind=$1
name=$2
case "$kind" in
    go | node | python | rust) template=$kind ;;
    rust-lib) template=rust ;;
    *)
        usage >&2
        exit 1
        ;;
esac
if [[ -e $name ]]; then
    echo "$name already exists" >&2
    exit 1
fi

cp -rL --no-preserve=mode "$templates/$template" "$name"
cp --no-preserve=mode "$lock" "$name/flake.lock"
cd "$name" || exit
git init -q
case "$kind" in
    go)
        out=$(go mod init "$name" 2>&1) || {
            echo "$out" >&2
            exit 1
        }
        ;;
    node) npm init -y >/dev/null ;;
    python) mv main.py "$name.py" ;;
    rust) cargo init -q --vcs none --bin ;;
    rust-lib) cargo init -q --vcs none --lib ;;
esac
git add -A
direnv allow
echo "Created $name"

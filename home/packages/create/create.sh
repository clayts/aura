: "${templates:?}" # Set by runtimeEnv in home/packages/default.nix

usage() {
    cat >&2 <<EOF
Usage: ${0##*/} <language> <name>

Create a project in ./<name>, with git and direnv set up.

Languages:
  --go        Go module with main.go
  --node      Node package with index.js
  --python    Python script <name>.py
  --rust      Rust binary crate
  --rust-lib  Rust library crate
EOF
    exit 1
}

[[ $# -eq 2 ]] || usage
kind=${1#--}
name=$2
case "$kind" in
    go | node | python | rust) template=$kind ;;
    rust-lib) template=rust ;;
    *) usage ;;
esac
if [[ -e $name ]]; then
    echo "$name already exists" >&2
    exit 1
fi

# Templates come from the read-only Nix store
cp -rL --no-preserve=mode "$templates/$template" "$name"
cd "$name" || exit
git init -q
case "$kind" in
    go)
        # go mod init always suggests go mod tidy, so only show its output on failure
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
# Flakes in a git repo only see tracked files
git add -A
direnv allow
echo "Created $name"

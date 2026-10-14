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
ignore=()
case "$kind" in
    go) packages=(go gopls gotools delve) ;;
    node) packages=(nodejs package-version-server superhtml) ignore=(node_modules) ;;
    python) packages=(python3 basedpyright ruff) ignore=(__pycache__) ;;
    rust | rust-lib) packages=(rustc cargo rustfmt clippy rust-analyzer pkg-config) ignore=(/target) ;;
    *)
        usage >&2
        exit 1
        ;;
esac
if [[ -e $name ]]; then
    echo "$name already exists" >&2
    exit 1
fi

mkdir "$name"
cd "$name" || exit
git init -q
cp --no-preserve=mode "$lock" flake.lock
printf '%s\n' "use flake" "source_env_if_exists .envrc.local" >.envrc
printf '%s\n' .direnv .envrc.local "${ignore[@]}" >.gitignore
cat >flake.nix <<EOF
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
  outputs =
    { nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [
$(printf '          %s\n' nixd nixfmt "${packages[@]}")
        ];
      };
    };
}
EOF
case "$kind" in
    go)
        out=$(go mod init "$name" 2>&1) || {
            echo "$out" >&2
            exit 1
        }
        cat >main.go <<'EOF'
package main

import "fmt"

func main() {
	fmt.Println("Hello, world!")
}
EOF
        ;;
    node)
        npm init -y >/dev/null
        echo 'console.log("Hello, world!");' >index.js
        ;;
    python) echo 'print("Hello, world!")' >"$name.py" ;;
    rust) cargo init -q --vcs none --bin ;;
    rust-lib) cargo init -q --vcs none --lib ;;
esac
git add -A
direnv allow
echo "Created $name"

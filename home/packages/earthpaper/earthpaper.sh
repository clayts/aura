: "${ids:?}" # Set by runtimeEnv in home/packages/default.nix
target="${1:-$HOME/.local/share/earthpaper/image.jpeg}"
id=$(jq -r '.[]' "$ids" | shuf -n 1)

echo "Fetching image data..."
data=$(curl -fsS --retry 4 --retry-all-errors "https://www.gstatic.com/prettyearth/assets/data/v3/$id.json")

# Decode next to the target first, so a failed download never leaves a broken
# wallpaper behind
mkdir -p "$(dirname "$target")"
tmp=$(mktemp "$target.XXXXXX")
trap 'rm -f "$tmp"' EXIT
jq -r '.dataUri | sub("^data:image/jpeg;base64,"; "")' <<<"$data" | base64 -d >"$tmp"
# Then overwrite the target in place rather than renaming over it: GNOME Shell
# reloads the wallpaper when its file is rewritten, but not when another file
# is moved onto it
cat "$tmp" >"$target"

jq -r --arg id "$id" --arg target "$target" '
    "Wrote image: \($target)",
    "ID:          \($id)",
    "Country:     \(.geocode.country // "unknown")",
    "Latitude:    \(.lat)",
    "Longitude:   \(.lng)",
    "Elevation:   \(.elevation)",
    "Map URL:     https://maps.google.com/?q=\(.lat),\(.lng)",
    "Attribution: \(.attribution)"' <<<"$data"

target="${1:-$HOME/.local/share/earthpaper/image.jpeg}"
id=$(jq -r '.[]' "$ids" | shuf -n 1)

echo "Fetching image data..."
data=$(curl -fsS --retry 4 --retry-all-errors "https://www.gstatic.com/prettyearth/assets/data/v3/$id.json")

# Write next to the target and rename it into place, so a failed download
# never leaves a broken wallpaper behind
mkdir -p "$(dirname "$target")"
tmp=$(mktemp "$target.XXXXXX")
trap 'rm -f "$tmp"' EXIT
jq -r '.dataUri | sub("^data:image/jpeg;base64,"; "")' <<<"$data" | base64 -d >"$tmp"
chmod 644 "$tmp"
mv "$tmp" "$target"

jq -r --arg id "$id" --arg target "$target" '
    "Wrote image: \($target)",
    "ID:          \($id)",
    "Country:     \(.geocode.country // "unknown")",
    "Latitude:    \(.lat)",
    "Longitude:   \(.lng)",
    "Elevation:   \(.elevation)",
    "Map URL:     https://maps.google.com/?q=\(.lat),\(.lng)",
    "Attribution: \(.attribution)"' <<<"$data"

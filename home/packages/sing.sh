[[ $# -ge 1 ]] || fail "usage: ${0##*/} <query…>"

cache="$HOME/.cache/sing"
query="$*"
if [[ ! -L "$cache/queries/$query" ]]; then
    echo " $query"
    json=$(yt-dlp --dump-json --no-playlist "ytsearch1:$query")
    id=$(echo "$json" | jq -r '.id')
    mp3="$(echo "$json" | jq -r '.title').mp3"
    if [[ ! -f "$cache/mp3s/$mp3" ]]; then
        echo " https://www.youtube.com/watch?v=$id"
        mkdir -p "$cache/mp3s"
        yt-dlp \
            -q \
            -t mp3 \
            --no-playlist \
            --output "$cache/mp3s/$mp3" \
            -- "https://www.youtube.com/watch?v=$id"
    fi
    mkdir -p "$cache/queries"
    ln -s "$cache/mp3s/$mp3" "$cache/queries/$query"
fi
mp3=$(basename "$(readlink -f "$cache/queries/$query")")
echo " $mp3"
mpv \
    --really-quiet \
    --scripts-add="$mpris/share/mpv/scripts/mpris.so" \
    "$cache/mp3s/$mp3"
exit 0

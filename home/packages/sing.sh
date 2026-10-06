if [[ $# -eq 0 ]]; then
    echo "usage: ${0##*/} <query…>" >&2
    exit 1
fi

cache="$HOME/.cache/sing"
query="$*"
# '/' can't appear in a file name, so it becomes '_' in cache entries
link="$cache/queries/${query//\//_}"
if [[ ! -e $link ]]; then
    echo " $query"
    json=$(yt-dlp --dump-json --no-playlist "ytsearch1:$query")
    id=$(jq -r '.id' <<<"$json")
    title=$(jq -r '.title' <<<"$json")
    mp3="$cache/mp3s/${title//\//_}.mp3"
    if [[ ! -f $mp3 ]]; then
        echo " https://www.youtube.com/watch?v=$id"
        mkdir -p "$cache/mp3s"
        # yt-dlp reads % as the start of a template field
        yt-dlp \
            -q \
            -t mp3 \
            --no-playlist \
            --output "${mp3//\%/%%}" \
            -- "https://www.youtube.com/watch?v=$id"
    fi
    mkdir -p "$cache/queries"
    ln -sfn "$mp3" "$link"
fi
mp3=$(readlink "$link")
echo " ${mp3##*/}"
mpv --really-quiet "$mp3"

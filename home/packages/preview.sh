# Preview a path for fzf: list a directory, show a file
if [[ -d $1 ]]; then
    lsd -1 --color=always --icon=always -- "$1"
elif [[ ! -e $1 ]]; then
    exit 0
elif [[ ! -s $1 ]]; then
    printf '\e[1mEmpty file\e[0m\n'
elif [[ $(file -b --mime-encoding -- "$1") == binary ]]; then
    # bat would only print a warning, so say what the file is instead, one
    # detail per line so long descriptions fit the preview
    printf '\e[1mBinary file\e[0m\n'
    file -b -- "$1" | sed 's/, /\n/g'
else
    bat --color=always -- "$1"
fi

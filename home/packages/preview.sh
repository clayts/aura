# Preview a path for fzf: list a directory, show a file
if [[ -d $1 ]]; then
    lsd -1 --color=always --icon=always -- "$1"
elif [[ -e $1 ]]; then
    bat --color=always -- "$1"
fi

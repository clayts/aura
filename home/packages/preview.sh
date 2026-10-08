# Preview a path for fzf: list a directory, show a file
if [[ -d $1 ]]; then
    lsd -1 --color=always --icon=always -- "$1"
elif [[ ! -e $1 ]]; then
    exit 0
elif [[ ! -s $1 ]]; then
    echo "Empty file"
elif [[ $(file -b --mime-encoding -- "$1") == binary ]]; then
    # bat would only print a warning, so say what the file is instead
    echo "Binary file: $(file -b -- "$1")"
else
    bat --color=always -- "$1"
fi

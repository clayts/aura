{
  pkgs,
  assets,
  ...
}:
{
  xdg.desktopEntries."micro" = {
    name = "Micro";
    noDisplay = true;
  };
  programs.micro = {
    enable = true;
    package = pkgs.micro-with-wl-clipboard;
    settings = {
      colorscheme = "custom";
      mkparents = true;
      wordwrap = true;
      softwrap = true;
      clipboard = "external";
      ruler = false;
    };
  };
  home.file.".config/micro/colorschemes/custom.micro".text = with assets.style.colors; ''
    color-link default "${x5}"
    color-link comment "${x4}"
    color-link identifier "bold ${xC}"
    color-link constant "${x8}"
    color-link constant.string "${xF}"
    color-link constant.number "${x8}"
    color-link constant.string.char "${xF}"
    color-link statement "${xA}"
    color-link symbol.operator "${x5}"
    color-link preproc "${xF}"
    color-link type "${xD}"
    color-link special "${x9}"
    color-link underlined "${x8}"
    color-link error "bold ${x8}"
    color-link todo "bold ${x9}"
    color-link hlsearch "${x2},${x4}"
    color-link statusline "${x2},${x4}"
    color-link tabbar "${x2},${x4}"
    color-link indent-char "${x2}"
    color-link line-number "${x2},${x4}"
    color-link current-line-number "${xF}"
    color-link diff-added "${xB}"
    color-link diff-modified "${xA}"
    color-link diff-deleted "${x8}"
    color-link gutter-error "${x8}"
    color-link gutter-warning "${xA}"
    color-link cursor-line "${x2}"
    color-link color-column "${x2}"
    #No extended types; Plain brackets.
    color-link type.extended "default"
    #color-link symbol.brackets "default"
    color-link symbol.tag "${x9}"
    color-link match-brace "${x4},${x5}"
    color-link tab-error "${x8}"
    color-link trailingws "${x8}"
  '';
  home.file.".config/micro/bindings.json".text = ''
    {
        "Alt-/": "lua:comment.comment",
    }
  '';
}

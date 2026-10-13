{ pkgs, style, ... }:
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
  xdg.configFile."micro/colorschemes/custom.micro".text = with style.colors; ''
    color-link default "${grey5}"
    color-link comment "${grey4}"
    color-link identifier "bold ${cyan}"
    color-link constant "${red}"
    color-link constant.string "${brown}"
    color-link constant.number "${red}"
    color-link constant.string.char "${brown}"
    color-link statement "${orange}"
    color-link symbol.operator "${grey5}"
    color-link preproc "${brown}"
    color-link type "${blue}"
    color-link special "${yellow}"
    color-link underlined "${red}"
    color-link error "bold ${red}"
    color-link todo "bold ${yellow}"
    color-link hlsearch "${grey2},${grey4}"
    color-link statusline "${grey2},${grey4}"
    color-link tabbar "${grey2},${grey4}"
    color-link indent-char "${grey2}"
    color-link line-number "${grey2},${grey4}"
    color-link current-line-number "${brown}"
    color-link diff-added "${green}"
    color-link diff-modified "${orange}"
    color-link diff-deleted "${red}"
    color-link gutter-error "${red}"
    color-link gutter-warning "${orange}"
    color-link cursor-line "${grey2}"
    color-link color-column "${grey2}"
    #No extended types; Plain brackets.
    color-link type.extended "default"
    #color-link symbol.brackets "default"
    color-link symbol.tag "${yellow}"
    color-link match-brace "${grey4},${grey5}"
    color-link tab-error "${red}"
    color-link trailingws "${red}"
  '';
  xdg.configFile."micro/bindings.json".text = ''
    {
        "Alt-/": "lua:comment.comment",
    }
  '';
}

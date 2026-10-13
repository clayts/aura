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
    color-link default "${base05}"
    color-link comment "${base04}"
    color-link identifier "bold ${base0C}"
    color-link constant "${base08}"
    color-link constant.string "${base0F}"
    color-link constant.number "${base08}"
    color-link constant.string.char "${base0F}"
    color-link statement "${base0A}"
    color-link symbol.operator "${base05}"
    color-link preproc "${base0F}"
    color-link type "${base0D}"
    color-link special "${base09}"
    color-link underlined "${base08}"
    color-link error "bold ${base08}"
    color-link todo "bold ${base09}"
    color-link hlsearch "${base02},${base04}"
    color-link statusline "${base02},${base04}"
    color-link tabbar "${base02},${base04}"
    color-link indent-char "${base02}"
    color-link line-number "${base02},${base04}"
    color-link current-line-number "${base0F}"
    color-link diff-added "${base0B}"
    color-link diff-modified "${base0A}"
    color-link diff-deleted "${base08}"
    color-link gutter-error "${base08}"
    color-link gutter-warning "${base0A}"
    color-link cursor-line "${base02}"
    color-link color-column "${base02}"
    #No extended types; Plain brackets.
    color-link type.extended "default"
    #color-link symbol.brackets "default"
    color-link symbol.tag "${base09}"
    color-link match-brace "${base04},${base05}"
    color-link tab-error "${base08}"
    color-link trailingws "${base08}"
  '';
  xdg.configFile."micro/bindings.json".text = ''
    {
        "Alt-/": "lua:comment.comment",
    }
  '';
}

{
  pkgs,
  lib,
  osConfig,
  style,
  ...
}:
{
  programs.zed-editor = {
    enable = true;
    extensions = [
      "toml"
      "colored-zed-icons-theme"
      "superhtml"
      "nix"
      "git-firefly"
      "color-highlight"
      "xml"
      "emmet"
    ];
    extraPackages = with pkgs; [
      color-lsp
    ];

    userSettings = {
      format_on_save = "on";
      hard_tabs = true;
      cli_default_open_behavior = "new_window";
      git = {
        inline_blame = {
          show_commit_summary = true;
          enabled = false;
        };
      };
      git_panel = {
        dock = "right";
        status_style = "icon";
      };
      scroll_beyond_last_line = "off";
      icon_theme = "Colored Zed Icons Theme Dark";
      show_edit_predictions = false;
      project_panel = {
        indent_guides.show = "never";
        starts_open = false;
        hide_root = true;
        entry_spacing = "standard";
        dock = "right";
      };
      indent_guides.enabled = false;
      notification_panel.button = false;
      disable_ai = true;
      diagnostics.inline.enabled = true;
      terminal.button = false;
      debugger.button = false;
      outline_panel.button = false;
      collaboration_panel.button = false;
      gutter = {
        line_numbers = false;
        runnables = false;
        breakpoints = false;
        folds = false;
      };
      tab_bar = {
        show = false;
        show_nav_history_buttons = true;
        show_tab_bar_buttons = true;
      };
      toolbar = {
        breadcrumbs = true;
        quick_actions = true;
        selections_menu = true;
        agent_review = false;
        code_actions = true;
      };
      restore_on_startup = "empty_tab";
      buffer_font_family = style.fonts.mono.name;
      buffer_font_features = lib.genAttrs style.fonts.mono.features (_: true);
      buffer_font_weight = 400;
      buffer_font_size = style.fonts.mono.size * 4.0 / 3.0;
      buffer_line_height.custom = 1.23;
      ui_font_family = ".SystemUIFont";
      ui_font_size = style.fonts.sans.size * 3.0 / 2.0;
      ui_font_weight = 400;
      soft_wrap = "editor_width";
      preferred_line_length = 100;
      tabs.file_icons = true;
      theme = {
        mode = "dark";
        light = "custom";
        dark = "custom";
      };
      node.path = "${pkgs.nodejs}/bin/node";
      load_direnv = "direct";
      languages = {
        Nix.language_servers = [
          "nixd"
          "!nil"
          "..."
        ];
        HTML = {
          language_servers = [
            "superhtml"
            "..."
          ];
          formatter.language_server.name = "superhtml";
        };
      };
      lsp_document_colors = "background";
      lsp = {
        nixd.binary.arguments = [ "--semantic-tokens=true" ];
        nixd.settings =
          let
            system-flake = ''(builtins.getFlake "${osConfig.programs.nh.flake}")'';
            nixos-options = "${system-flake}.nixosConfigurations.${osConfig.networking.hostName}.options";
          in
          {
            nixpkgs.expr = "import ${system-flake}.inputs.nixpkgs { }";
            formatting.command = [ "nixfmt" ];
            options = {
              nixos.expr = nixos-options;
              home-manager.expr = "${nixos-options}.home-manager.users.type.getSubOptions []";
            };
          };
        rust-analyzer.initialization_options.check.command = "clippy";
      };
    };
    themes.custom =
      with style.colors;
      let
        # A syntax highlight: a colour, plus any font style or weight
        syntax =
          color: font:
          {
            color = "${color}ff";
            font_style = null;
            font_weight = null;
          }
          // font;
        # A status colour, with its background and border
        status = name: color: {
          ${name} = "${color}ff";
          "${name}.background" = "${color}1a";
          "${name}.border" = "${color}80";
        };
        # A collaborator's colours
        player = color: {
          cursor = "${color}ff";
          background = "${color}20";
          selection = "${color}30";
        };
      in
      {
        "$schema" = "https://zed.dev/schema/themes/v0.2.0.json";
        "name" = "custom";
        "author" = "";
        "themes" = [
          {
            "name" = "custom";
            "appearance" = "dark";
            "style" = {
              "border" = "${grey4}25";
              "border.variant" = "${grey0}30";
              "border.focused" = "${grey0}30";
              "border.selected" = "${grey0}30";
              "border.transparent" = "#00000000";
              "border.disabled" = "${grey0}30";
              "elevated_surface.background" = "${grey1}ff";
              "surface.background" = "${grey1}ff";
              "background" = "${grey2}ff";
              "element.background" = "${grey3}ff";
              "element.hover" = "${grey3}ff";
              "element.active" = "${grey3}ff";
              "element.selected" = "${grey3}ff";
              "element.disabled" = "${grey3}ff";
              "drop_target.background" = "${grey4}80";
              "ghost_element.background" = "#00000000";
              "ghost_element.hover" = "${grey3}ff";
              "ghost_element.active" = "${grey3}ff";
              "ghost_element.selected" = "${grey3}ff";
              "ghost_element.disabled" = "${grey1}ff";
              "text" = "${grey6}ff";
              "text.muted" = "${grey5}ff";
              "text.placeholder" = "${grey4}ff";
              "text.disabled" = "${grey3}ff";
              "text.accent" = "${blue}ff";
              "icon" = "${grey5}ff";
              "icon.muted" = "${grey4}ff";
              "icon.disabled" = "${grey4}ff";
              "icon.placeholder" = "${grey4}ff";
              "icon.accent" = "${blue}ff";
              "status_bar.background" = "${grey2}ff";
              "title_bar.background" = "${grey2}ff";
              "title_bar.inactive_background" = "${grey2}ff";
              "toolbar.background" = "${grey0}ff";
              "tab_bar.background" = "${grey2}ff";
              "tab.inactive_background" = "${grey2}ff";
              "tab.active_background" = "${grey0}ff";
              "search.match_background" = "${orange}66";
              "search.active_match_background" = "${yellow}66";
              "panel.background" = "${grey0}ff";
              "panel.focused_border" = null;
              "pane.focused_border" = null;
              "scrollbar.thumb.background" = "${grey4}4c";
              "scrollbar.thumb.hover_background" = "${grey2}ff";
              "scrollbar.thumb.border" = "${grey2}ff";
              "scrollbar.track.background" = "#00000000";
              "scrollbar.track.border" = "${grey1}00";
              "editor.foreground" = "${grey5}ff";
              "editor.background" = "${grey0}ff";
              "editor.gutter.background" = "${grey0}ff";
              "editor.subheader.background" = "${grey1}ff";
              "editor.active_line.background" = "${grey1}80";
              "editor.highlighted_line.background" = "${grey1}ff";
              "editor.line_number" = "${grey3}ff";
              "editor.active_line_number" = "${grey5}ff";
              "editor.hover_line_number" = "${grey4}ff";
              "editor.invisible" = "${grey3}ff";
              "editor.wrap_guide" = "${grey2}0d";
              "editor.active_wrap_guide" = "${grey2}1a";
              "editor.document_highlight.read_background" = "${blue}1a";
              "editor.document_highlight.write_background" = "${grey2}66";
              "editor.document_highlight.bracket_background" = "${green}40"; # Brackets around the cursor
              "terminal.background" = "${grey0}ff";
              "terminal.foreground" = "${grey5}ff";
              "terminal.bright_foreground" = "${grey7}ff";
              "terminal.dim_foreground" = "${grey3}ff";
              "terminal.ansi.black" = "${grey0}ff";
              "terminal.ansi.bright_black" = "${grey3}ff";
              "terminal.ansi.dim_black" = "${grey0}ff";
              "terminal.ansi.red" = "${red}ff";
              "terminal.ansi.bright_red" = "${bright.red}ff";
              "terminal.ansi.dim_red" = "${red}bf";
              "terminal.ansi.green" = "${green}ff";
              "terminal.ansi.bright_green" = "${bright.green}ff";
              "terminal.ansi.dim_green" = "${green}bf";
              "terminal.ansi.yellow" = "${orange}ff";
              "terminal.ansi.bright_yellow" = "${bright.orange}ff";
              "terminal.ansi.dim_yellow" = "${orange}bf";
              "terminal.ansi.blue" = "${blue}ff";
              "terminal.ansi.bright_blue" = "${bright.blue}ff";
              "terminal.ansi.dim_blue" = "${blue}bf";
              "terminal.ansi.magenta" = "${purple}ff";
              "terminal.ansi.bright_magenta" = "${bright.purple}ff";
              "terminal.ansi.dim_magenta" = "${purple}bf";
              "terminal.ansi.cyan" = "${cyan}ff";
              "terminal.ansi.bright_cyan" = "${bright.cyan}ff";
              "terminal.ansi.dim_cyan" = "${cyan}bf";
              "terminal.ansi.white" = "${grey5}ff";
              "terminal.ansi.bright_white" = "${grey7}ff";
              "terminal.ansi.dim_white" = "${grey4}ff";
              "link_text.hover" = "${blue}ff";
              "version_control.added" = "${green}ff";
              "version_control.modified" = "${orange}ff";
              "version_control.word_added" = "${green}59";
              "version_control.word_deleted" = "${red}cc";
              "version_control.deleted" = "${red}ff";
              "version_control.conflict_marker.ours" = "${green}1a";
              "version_control.conflict_marker.theirs" = "${blue}1a";
              "hidden" = "${grey3}ff";
              "hidden.background" = "${grey2}1a";
              "hidden.border" = "${grey2}ff";
              "ignored" = "${grey3}ff";
              "ignored.background" = "${grey2}1a";
              "ignored.border" = "${grey2}ff";
              "unreachable" = "${grey4}ff";
              "unreachable.background" = "${grey3}1a";
              "unreachable.border" = "${grey3}ff";
              "players" = map player [
                blue
                purple
                red
                yellow
                orange
                green
                cyan
                grey7
              ];
              "syntax" = {
                attribute = syntax purple { };
                boolean = syntax orange { };
                comment = syntax grey3 { font_style = "italic"; };
                "comment.doc" = syntax grey4 { font_style = "italic"; };
                constant = syntax yellow { };
                constructor = syntax blue { };
                embedded = syntax brown { }; # Embedded language tags, as base16 has it
                emphasis = syntax purple { font_style = "italic"; };
                "emphasis.strong" = syntax orange { font_weight = 700; };
                enum = syntax yellow { };
                function = syntax green { };
                hint = syntax grey3 { };
                keyword = syntax orange { };
                label = syntax red { };
                link_text = syntax blue { font_style = "normal"; };
                link_uri = syntax blue { };
                namespace = syntax orange { };
                number = syntax red { };
                operator = syntax grey5 { };
                predictive = syntax grey3 { font_style = "italic"; };
                preproc = syntax grey7 { };
                primary = syntax grey5 { };
                property = syntax cyan { };
                punctuation = syntax grey5 { };
                "punctuation.bracket" = syntax grey5 { };
                "punctuation.delimiter" = syntax grey5 { };
                "punctuation.list_marker" = syntax red { };
                "punctuation.markup" = syntax red { };
                "punctuation.special" = syntax orange { };
                selector = syntax orange { };
                "selector.pseudo" = syntax cyan { };
                string = syntax grey7 { };
                "string.escape" = syntax grey4 { };
                "string.regex" = syntax grey4 { };
                "string.special" = syntax yellow { };
                "string.special.symbol" = syntax red { };
                tag = syntax red { };
                "text.literal" = syntax green { };
                title = syntax blue { font_weight = 700; };
                type = syntax blue { };
                variable = syntax cyan { };
                "variable.special" = syntax cyan { };
                variant = syntax blue { };
              };
            }
            // lib.concatMapAttrs status {
              conflict = orange;
              created = green;
              deleted = red;
              error = red;
              hint = cyan;
              info = blue;
              modified = orange;
              predictive = grey3;
              renamed = blue;
              success = green;
              warning = orange;
            };
          }
        ];
      };
  };
}

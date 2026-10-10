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
              "border" = "${x4}25";
              "border.variant" = "${x0}30";
              "border.focused" = "${x0}30";
              "border.selected" = "${x0}30";
              "border.transparent" = "#00000000";
              "border.disabled" = "${x0}30";
              "elevated_surface.background" = "${x1}ff";
              "surface.background" = "${x1}ff";
              "background" = "${x2}ff";
              "element.background" = "${x3}ff";
              "element.hover" = "${x3}ff";
              "element.active" = "${x3}ff";
              "element.selected" = "${x3}ff";
              "element.disabled" = "${x3}ff";
              "drop_target.background" = "${x4}80";
              "ghost_element.background" = "#00000000";
              "ghost_element.hover" = "${x3}ff";
              "ghost_element.active" = "${x3}ff";
              "ghost_element.selected" = "${x3}ff";
              "ghost_element.disabled" = "${x1}ff";
              "text" = "${x6}ff";
              "text.muted" = "${x5}ff";
              "text.placeholder" = "${x4}ff";
              "text.disabled" = "${x3}ff";
              "text.accent" = "${xD}ff";
              "icon" = "${x5}ff";
              "icon.muted" = "${x4}ff";
              "icon.disabled" = "${x4}ff";
              "icon.placeholder" = "${x4}ff";
              "icon.accent" = "${xD}ff";
              "status_bar.background" = "${x2}ff";
              "title_bar.background" = "${x2}ff";
              "title_bar.inactive_background" = "${x2}ff";
              "toolbar.background" = "${x0}ff";
              "tab_bar.background" = "${x2}ff";
              "tab.inactive_background" = "${x2}ff";
              "tab.active_background" = "${x0}ff";
              "search.match_background" = "${xA}66";
              "search.active_match_background" = "${x9}66";
              "panel.background" = "${x0}ff";
              "panel.focused_border" = null;
              "pane.focused_border" = null;
              "scrollbar.thumb.background" = "${x4}4c";
              "scrollbar.thumb.hover_background" = "${x2}ff";
              "scrollbar.thumb.border" = "${x2}ff";
              "scrollbar.track.background" = "#00000000";
              "scrollbar.track.border" = "${x1}00";
              "editor.foreground" = "${x5}ff";
              "editor.background" = "${x0}ff";
              "editor.gutter.background" = "${x0}ff";
              "editor.subheader.background" = "${x1}ff";
              "editor.active_line.background" = "${x1}80";
              "editor.highlighted_line.background" = "${x1}ff";
              "editor.line_number" = "${x3}ff";
              "editor.active_line_number" = "${x5}ff";
              "editor.hover_line_number" = "${x4}ff";
              "editor.invisible" = "${x3}ff";
              "editor.wrap_guide" = "${x2}0d";
              "editor.active_wrap_guide" = "${x2}1a";
              "editor.document_highlight.read_background" = "${xD}1a";
              "editor.document_highlight.write_background" = "${x2}66";
              "terminal.background" = "${x0}ff";
              "terminal.foreground" = "${x5}ff";
              "terminal.bright_foreground" = "${x7}ff";
              "terminal.dim_foreground" = "${x3}ff";
              "terminal.ansi.black" = "${x0}ff";
              "terminal.ansi.bright_black" = "${x3}ff";
              "terminal.ansi.dim_black" = "${x0}ff";
              "terminal.ansi.red" = "${x8}ff";
              "terminal.ansi.bright_red" = "${x8}ff";
              "terminal.ansi.dim_red" = "${x8}bf";
              "terminal.ansi.green" = "${xB}ff";
              "terminal.ansi.bright_green" = "${xB}ff";
              "terminal.ansi.dim_green" = "${xB}bf";
              "terminal.ansi.yellow" = "${xA}ff";
              "terminal.ansi.bright_yellow" = "${xA}ff";
              "terminal.ansi.dim_yellow" = "${xA}bf";
              "terminal.ansi.blue" = "${xD}ff";
              "terminal.ansi.bright_blue" = "${xD}ff";
              "terminal.ansi.dim_blue" = "${xD}bf";
              "terminal.ansi.magenta" = "${xE}ff";
              "terminal.ansi.bright_magenta" = "${xE}ff";
              "terminal.ansi.dim_magenta" = "${xE}bf";
              "terminal.ansi.cyan" = "${xC}ff";
              "terminal.ansi.bright_cyan" = "${xC}ff";
              "terminal.ansi.dim_cyan" = "${xC}bf";
              "terminal.ansi.white" = "${x5}ff";
              "terminal.ansi.bright_white" = "${x7}ff";
              "terminal.ansi.dim_white" = "${x4}ff";
              "link_text.hover" = "${xD}ff";
              "version_control.added" = "${xB}ff";
              "version_control.modified" = "${xA}ff";
              "version_control.word_added" = "${xB}59";
              "version_control.word_deleted" = "${x8}cc";
              "version_control.deleted" = "${x8}ff";
              "version_control.conflict_marker.ours" = "${xB}1a";
              "version_control.conflict_marker.theirs" = "${xD}1a";
              "hidden" = "${x3}ff";
              "hidden.background" = "${x2}1a";
              "hidden.border" = "${x2}ff";
              "ignored" = "${x3}ff";
              "ignored.background" = "${x2}1a";
              "ignored.border" = "${x2}ff";
              "unreachable" = "${x4}ff";
              "unreachable.background" = "${x3}1a";
              "unreachable.border" = "${x3}ff";
              "players" = map player [
                xD
                xE
                x8
                x9
                xA
                xB
                xC
                xF
              ];
              "syntax" = {
                attribute = syntax xE { };
                boolean = syntax xA { };
                comment = syntax x3 { font_style = "italic"; };
                "comment.doc" = syntax x4 { font_style = "italic"; };
                constant = syntax x9 { };
                constructor = syntax xD { };
                embedded = syntax xF { };
                emphasis = syntax xE { font_style = "italic"; };
                "emphasis.strong" = syntax xA { font_weight = 700; };
                enum = syntax x9 { };
                function = syntax xB { };
                hint = syntax x3 { };
                keyword = syntax xA { };
                label = syntax x8 { };
                link_text = syntax xD { font_style = "normal"; };
                link_uri = syntax xD { };
                namespace = syntax xA { };
                number = syntax x8 { };
                operator = syntax x5 { };
                predictive = syntax x3 { font_style = "italic"; };
                preproc = syntax xF { };
                primary = syntax x5 { };
                property = syntax xC { };
                punctuation = syntax x5 { };
                "punctuation.bracket" = syntax x5 { };
                "punctuation.delimiter" = syntax x5 { };
                "punctuation.list_marker" = syntax x8 { };
                "punctuation.markup" = syntax x8 { };
                "punctuation.special" = syntax xA { };
                selector = syntax xA { };
                "selector.pseudo" = syntax xC { };
                string = syntax xF { };
                "string.escape" = syntax x4 { };
                "string.regex" = syntax x4 { };
                "string.special" = syntax x9 { };
                "string.special.symbol" = syntax x8 { };
                tag = syntax x8 { };
                "text.literal" = syntax xB { };
                title = syntax xD { font_weight = 700; };
                type = syntax xD { };
                variable = syntax xC { };
                "variable.special" = syntax xC { };
                variant = syntax xD { };
              };
            }
            // lib.concatMapAttrs status {
              conflict = xA;
              created = xB;
              deleted = x8;
              error = x8;
              hint = xC;
              info = xD;
              modified = xA;
              predictive = x3;
              renamed = xD;
              success = xB;
              warning = xA;
            };
          }
        ];
      };
  };
}

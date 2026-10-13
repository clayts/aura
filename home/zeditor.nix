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
              "border" = "${base04}25";
              "border.variant" = "${base00}30";
              "border.focused" = "${base00}30";
              "border.selected" = "${base00}30";
              "border.transparent" = "#00000000";
              "border.disabled" = "${base00}30";
              "elevated_surface.background" = "${base01}ff";
              "surface.background" = "${base01}ff";
              "background" = "${base02}ff";
              "element.background" = "${base03}ff";
              "element.hover" = "${base03}ff";
              "element.active" = "${base03}ff";
              "element.selected" = "${base03}ff";
              "element.disabled" = "${base03}ff";
              "drop_target.background" = "${base04}80";
              "ghost_element.background" = "#00000000";
              "ghost_element.hover" = "${base03}ff";
              "ghost_element.active" = "${base03}ff";
              "ghost_element.selected" = "${base03}ff";
              "ghost_element.disabled" = "${base01}ff";
              "text" = "${base06}ff";
              "text.muted" = "${base05}ff";
              "text.placeholder" = "${base04}ff";
              "text.disabled" = "${base03}ff";
              "text.accent" = "${base0D}ff";
              "icon" = "${base05}ff";
              "icon.muted" = "${base04}ff";
              "icon.disabled" = "${base04}ff";
              "icon.placeholder" = "${base04}ff";
              "icon.accent" = "${base0D}ff";
              "status_bar.background" = "${base02}ff";
              "title_bar.background" = "${base02}ff";
              "title_bar.inactive_background" = "${base02}ff";
              "toolbar.background" = "${base00}ff";
              "tab_bar.background" = "${base02}ff";
              "tab.inactive_background" = "${base02}ff";
              "tab.active_background" = "${base00}ff";
              "search.match_background" = "${base0A}66";
              "search.active_match_background" = "${base09}66";
              "panel.background" = "${base00}ff";
              "panel.focused_border" = null;
              "pane.focused_border" = null;
              "scrollbar.thumb.background" = "${base04}4c";
              "scrollbar.thumb.hover_background" = "${base02}ff";
              "scrollbar.thumb.border" = "${base02}ff";
              "scrollbar.track.background" = "#00000000";
              "scrollbar.track.border" = "${base01}00";
              "editor.foreground" = "${base05}ff";
              "editor.background" = "${base00}ff";
              "editor.gutter.background" = "${base00}ff";
              "editor.subheader.background" = "${base01}ff";
              "editor.active_line.background" = "${base01}80";
              "editor.highlighted_line.background" = "${base01}ff";
              "editor.line_number" = "${base03}ff";
              "editor.active_line_number" = "${base05}ff";
              "editor.hover_line_number" = "${base04}ff";
              "editor.invisible" = "${base03}ff";
              "editor.wrap_guide" = "${base02}0d";
              "editor.active_wrap_guide" = "${base02}1a";
              "editor.document_highlight.read_background" = "${base0D}1a";
              "editor.document_highlight.write_background" = "${base02}66";
              "editor.document_highlight.bracket_background" = "${base0B}40"; # Brackets around the cursor
              "terminal.background" = "${base00}ff";
              "terminal.foreground" = "${base05}ff";
              "terminal.bright_foreground" = "${base07}ff";
              "terminal.dim_foreground" = "${base03}ff";
              "terminal.ansi.black" = "${base00}ff";
              "terminal.ansi.bright_black" = "${base03}ff";
              "terminal.ansi.dim_black" = "${base00}ff";
              "terminal.ansi.red" = "${base08}ff";
              "terminal.ansi.bright_red" = "${bright.base08}ff";
              "terminal.ansi.dim_red" = "${base08}bf";
              "terminal.ansi.green" = "${base0B}ff";
              "terminal.ansi.bright_green" = "${bright.base0B}ff";
              "terminal.ansi.dim_green" = "${base0B}bf";
              "terminal.ansi.yellow" = "${base0A}ff";
              "terminal.ansi.bright_yellow" = "${bright.base0A}ff";
              "terminal.ansi.dim_yellow" = "${base0A}bf";
              "terminal.ansi.blue" = "${base0D}ff";
              "terminal.ansi.bright_blue" = "${bright.base0D}ff";
              "terminal.ansi.dim_blue" = "${base0D}bf";
              "terminal.ansi.magenta" = "${base0E}ff";
              "terminal.ansi.bright_magenta" = "${bright.base0E}ff";
              "terminal.ansi.dim_magenta" = "${base0E}bf";
              "terminal.ansi.cyan" = "${base0C}ff";
              "terminal.ansi.bright_cyan" = "${bright.base0C}ff";
              "terminal.ansi.dim_cyan" = "${base0C}bf";
              "terminal.ansi.white" = "${base05}ff";
              "terminal.ansi.bright_white" = "${base07}ff";
              "terminal.ansi.dim_white" = "${base04}ff";
              "link_text.hover" = "${base0D}ff";
              "version_control.added" = "${base0B}ff";
              "version_control.modified" = "${base0A}ff";
              "version_control.word_added" = "${base0B}59";
              "version_control.word_deleted" = "${base08}cc";
              "version_control.deleted" = "${base08}ff";
              "version_control.conflict_marker.ours" = "${base0B}1a";
              "version_control.conflict_marker.theirs" = "${base0D}1a";
              "hidden" = "${base03}ff";
              "hidden.background" = "${base02}1a";
              "hidden.border" = "${base02}ff";
              "ignored" = "${base03}ff";
              "ignored.background" = "${base02}1a";
              "ignored.border" = "${base02}ff";
              "unreachable" = "${base04}ff";
              "unreachable.background" = "${base03}1a";
              "unreachable.border" = "${base03}ff";
              "players" = map player [
                base0D
                base0E
                base08
                base09
                base0A
                base0B
                base0C
                base0F
              ];
              "syntax" = {
                attribute = syntax base0E { };
                boolean = syntax base0A { };
                comment = syntax base03 { font_style = "italic"; };
                "comment.doc" = syntax base04 { font_style = "italic"; };
                constant = syntax base09 { };
                constructor = syntax base0D { };
                embedded = syntax base0F { };
                emphasis = syntax base0E { font_style = "italic"; };
                "emphasis.strong" = syntax base0A { font_weight = 700; };
                enum = syntax base09 { };
                function = syntax base0B { };
                hint = syntax base03 { };
                keyword = syntax base0A { };
                label = syntax base08 { };
                link_text = syntax base0D { font_style = "normal"; };
                link_uri = syntax base0D { };
                namespace = syntax base0A { };
                number = syntax base08 { };
                operator = syntax base05 { };
                predictive = syntax base03 { font_style = "italic"; };
                preproc = syntax base0F { };
                primary = syntax base05 { };
                property = syntax base0C { };
                punctuation = syntax base05 { };
                "punctuation.bracket" = syntax base05 { };
                "punctuation.delimiter" = syntax base05 { };
                "punctuation.list_marker" = syntax base08 { };
                "punctuation.markup" = syntax base08 { };
                "punctuation.special" = syntax base0A { };
                selector = syntax base0A { };
                "selector.pseudo" = syntax base0C { };
                string = syntax base0F { };
                "string.escape" = syntax base04 { };
                "string.regex" = syntax base04 { };
                "string.special" = syntax base09 { };
                "string.special.symbol" = syntax base08 { };
                tag = syntax base08 { };
                "text.literal" = syntax base0B { };
                title = syntax base0D { font_weight = 700; };
                type = syntax base0D { };
                variable = syntax base0C { };
                "variable.special" = syntax base0C { };
                variant = syntax base0D { };
              };
            }
            // lib.concatMapAttrs status {
              conflict = base0A;
              created = base0B;
              deleted = base08;
              error = base08;
              hint = base0C;
              info = base0D;
              modified = base0A;
              predictive = base03;
              renamed = base0D;
              success = base0B;
              warning = base0A;
            };
          }
        ];
      };
  };
}

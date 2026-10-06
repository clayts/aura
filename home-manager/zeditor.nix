{
  pkgs,
  lib,
  assets,
  osConfig,
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
    package = pkgs.symlinkJoin {
      name = "zed-editor-bundle";
      paths = [
        pkgs.zed-editor
        pkgs.color-lsp
        assets.style.fonts.sans.package
        assets.style.fonts.mono.package
        assets.style.fonts.emoji.package
      ];
    };

    userSettings = {
      hard_tabs = true;
      cli_default_open_behavior= "new_window";
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
      buffer_font_family = assets.style.fonts.mono.name;
      buffer_font_features = lib.genAttrs assets.style.fonts.mono.features (f: true);
      buffer_font_weight = 400;
      buffer_font_size = assets.style.fonts.mono.size * 4.0 / 3.0;
      buffer_line_height.custom = 1.23;
      ui_font_family = lib.mkForce ".SystemUIFont"; # style.fonts.sans.name;
      ui_font_size = assets.style.fonts.sans.size * 3.0 / 2.0;
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
        nixd.settings =
          let
            system-flake = ''(builtins.getFlake "/etc/nixos")'';
            nixos-options = "${system-flake}.nixosConfigurations.${osConfig.networking.hostName}.options";
          in
          {
            args = [ "--semantic-tokens=true" ];
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
    themes.custom = with assets.style.colors; {
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
            "conflict" = "${xA}ff";
            "conflict.background" = "${xA}1a";
            "conflict.border" = "${xA}80";
            "created" = "${xB}ff";
            "created.background" = "${xB}1a";
            "created.border" = "${xB}80";
            "deleted" = "${x8}ff";
            "deleted.background" = "${x8}1a";
            "deleted.border" = "${x8}80";
            "error" = "${x8}ff";
            "error.background" = "${x8}1a";
            "error.border" = "${x8}80";
            "hidden" = "${x3}ff";
            "hidden.background" = "${x2}1a";
            "hidden.border" = "${x2}ff";
            "hint" = "${xC}ff";
            "hint.background" = "${xC}1a";
            "hint.border" = "${xC}80";
            "ignored" = "${x3}ff";
            "ignored.background" = "${x2}1a";
            "ignored.border" = "${x2}ff";
            "info" = "${xD}ff";
            "info.background" = "${xD}1a";
            "info.border" = "${xD}80";
            "modified" = "${xA}ff";
            "modified.background" = "${xA}1a";
            "modified.border" = "${xA}80";
            "predictive" = "${x3}ff";
            "predictive.background" = "${x3}1a";
            "predictive.border" = "${x3}80";
            "renamed" = "${xD}ff";
            "renamed.background" = "${xD}1a";
            "renamed.border" = "${xD}80";
            "success" = "${xB}ff";
            "success.background" = "${xB}1a";
            "success.border" = "${xB}80";
            "unreachable" = "${x4}ff";
            "unreachable.background" = "${x3}1a";
            "unreachable.border" = "${x3}ff";
            "warning" = "${xA}ff";
            "warning.background" = "${xA}1a";
            "warning.border" = "${xA}80";
            "players" = [
              {
                "cursor" = "${xD}ff";
                "background" = "${xD}20";
                "selection" = "${xD}30";
              }
              {
                "cursor" = "${xE}ff";
                "background" = "${xE}20";
                "selection" = "${xE}30";
              }
              {
                "cursor" = "${x8}ff";
                "background" = "${x8}20";
                "selection" = "${x8}30";
              }
              {
                "cursor" = "${x9}ff";
                "background" = "${x9}20";
                "selection" = "${x9}30";
              }
              {
                "cursor" = "${xA}ff";
                "background" = "${xA}20";
                "selection" = "${xA}30";
              }
              {
                "cursor" = "${xB}ff";
                "background" = "${xB}20";
                "selection" = "${xB}30";
              }
              {
                "cursor" = "${xC}ff";
                "background" = "${xC}20";
                "selection" = "${xC}30";
              }
              {
                "cursor" = "${xF}ff";
                "background" = "${xF}20";
                "selection" = "${xF}30";
              }
            ];
            "syntax" = {
              "attribute" = {
                "color" = "${xE}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "boolean" = {
                "color" = "${xA}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "comment" = {
                "color" = "${x3}ff";
                "font_style" = "italic";
                "font_weight" = null;
              };
              "comment.doc" = {
                "color" = "${x4}ff";
                "font_style" = "italic";
                "font_weight" = null;
              };
              "constant" = {
                "color" = "${x9}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "constructor" = {
                "color" = "${xD}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "embedded" = {
                "color" = "${xF}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "emphasis" = {
                "color" = "${xE}ff";
                "font_style" = "italic";
                "font_weight" = null;
              };
              "emphasis.strong" = {
                "color" = "${xA}ff";
                "font_style" = null;
                "font_weight" = 700;
              };
              "enum" = {
                "color" = "${x9}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "function" = {
                "color" = "${xB}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "hint" = {
                "color" = "${x3}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "keyword" = {
                "color" = "${xA}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "label" = {
                "color" = "${x8}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "link_text" = {
                "color" = "${xD}ff";
                "font_style" = "normal";
                "font_weight" = null;
              };
              "link_uri" = {
                "color" = "${xD}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "namespace" = {
                "color" = "${xA}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "number" = {
                "color" = "${x8}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "operator" = {
                "color" = "${x5}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "predictive" = {
                "color" = "${x3}ff";
                "font_style" = "italic";
                "font_weight" = null;
              };
              "preproc" = {
                "color" = "${xF}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "primary" = {
                "color" = "${x5}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "property" = {
                "color" = "${xC}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "punctuation" = {
                "color" = "${x5}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "punctuation.bracket" = {
                "color" = "${x5}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "punctuation.delimiter" = {
                "color" = "${x5}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "punctuation.list_marker" = {
                "color" = "${x8}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "punctuation.markup" = {
                "color" = "${x8}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "punctuation.special" = {
                "color" = "${xA}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "selector" = {
                "color" = "${xA}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "selector.pseudo" = {
                "color" = "${xC}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "string" = {
                "color" = "${xF}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "string.escape" = {
                "color" = "${x4}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "string.regex" = {
                "color" = "${x4}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "string.special" = {
                "color" = "${x9}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "string.special.symbol" = {
                "color" = "${x8}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "tag" = {
                "color" = "${x8}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "text.literal" = {
                "color" = "${xB}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "title" = {
                "color" = "${xD}ff";
                "font_style" = null;
                "font_weight" = 700;
              };
              "type" = {
                "color" = "${xD}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "variable" = {
                "color" = "${xC}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "variable.special" = {
                "color" = "${xC}ff";
                "font_style" = null;
                "font_weight" = null;
              };
              "variant" = {
                "color" = "${xD}ff";
                "font_style" = null;
                "font_weight" = null;
              };
            };
          };
        }
      ];
    };
  };
}

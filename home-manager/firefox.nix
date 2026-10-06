{
  inputs,
  config,
  pkgs,
  ...
}:
{
  home.file.".config/mozilla/managed-storage/uBlock0@raymondhill.net.json".text = builtins.toJSON {
    name = "uBlock0@raymondhill.net";
    description = "_";
    type = "storage";
    data = {
      userSettings = [
        [
          "prefetchingDisabled"
          "false"
        ]
      ];
    };
  };
  programs.firefox = {
    enable = true;
    # package = pkgs.firefox-beta;
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };
      };
    };
    profiles = {
      default = {
        id = 0;
        name = "default";
        isDefault = true;
        userChrome = ''
          @import "${inputs.firefox-theme}/userChrome.css";
          #nav-bar-overflow-button {
            display: none !important;
          }
        '';
        userContent = ''@import "${inputs.firefox-theme}/userContent.css";'';
        extraConfig = builtins.readFile "${inputs.firefox-theme}/configuration/user.js";
        settings = {
          # "browser.display.use_document_fonts" = 0;
          "spellchecker.dictionary_path" = "${pkgs.hunspellDicts.en_GB-ize}/share/hunspell";
          "spellchecker.dictionary" = "en-GB,en_GB";
          "intl.accept_languages" = "en-GB,en";
          "browser.uiCustomization.navBarWhenVerticalTabs" = [
            "sidebar-button"
            "back-button"
            "forward-button"
            "stop-reload-button"
            "customizableui-special-spring1"
            "vertical-spacer"
            "firefox-view-button"
            "urlbar-container"
            "customizableui-special-spring2"
            "downloads-button"
            "unified-extensions-button"
            "alltabs-button"
          ];

          "sidebar.verticalTabs" = false;
          "sidebar.main.tools" = "";
          "sidebar.revamp" = false;
          "sidebar.revamp.round-content-area" = false;
          "browser.tabs.groups.enabled" = false;
          "extensions.pocket.enabled" = false;
          "browser.newtabpage.pinned" = "";
          "browser.topsites.contile.enabled" = false;
          "browser.newtabpage.activity-stream.showSponsored" = false;
          "browser.newtabpage.activity-stream.system.showSponsored" = false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          "browser.toolbars.bookmarks.visibility" = "never";
          "media.ffmpeg.vaapi.enabled" = true;
          "browser.aboutConfig.showWarning" = false;
          # "browser.cache.disk.enable" = false; # Be kind to hard drive
          "browser.cache.disk.enable" = true;
          "browser.cache.disk.capacity" = 256 * 1024;
          "browser.cache.disk.parent_directory" = "/run/user/${toString config.home.uid}/firefox";
          "gnomeTheme.hideSingleTab" = true;
          "browser.uiCustomization.state" = {
            "placements" = {
              "widget-overflow-fixed-list" = [ ];
              "unified-extensions-area" = [ "ublock0_raymondhill_net-browser-action" ];
              "nav-bar" = [
                "back-button"
                "forward-button"
                "stop-reload-button"
                "customizableui-special-spring1"
                "firefox-view-button"
                "urlbar-container"
                "new-tab-button"
                "customizableui-special-spring2"
                "downloads-button"
                "unified-extensions-button"
              ];
              "toolbar-menubar" = [ "menubar-items" ];
              "TabsToolbar" = [
                "tabbrowser-tabs"
                "alltabs-button"
              ];
              "vertical-tabs" = [ ];
              "PersonalToolbar" = [
                "import-button"
                "personal-bookmarks"
              ];
            };
            "currentVersion" = 20;
          };
          "browser.newtabpage.activity-stream.feeds.section.highlights" = false;
          "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
          "browser.newtabpage.activity-stream.showSearch" = false;
          "browser.newtabpage.activity-stream.topSitesRows" = 3;
          "browser.uidensity" = 0;
          "svg.context-properties.content.enabled" = true;
          "browser.theme.dark-private-windows" = false;
          "widget.gtk.rounded-bottom-corners.enabled" = true;
          "gnomeTheme.normalWidthTabs" = false;
          "gnomeTheme.swapTabClose" = false;
          "gnomeTheme.bookmarksToolbarUnderTabs" = false;
          "gnomeTheme.tabsAsHeaderbar" = false;
          "gnomeTheme.tabAlignLeft" = false;
          "gnomeTheme.activeTabContrast" = false;
          "gnomeTheme.closeOnlySelectedTabs" = true;
          "gnomeTheme.symbolicTabIcons" = false;
          "gnomeTheme.allTabsButton" = false;
          "gnomeTheme.allTabsButtonOnOverflow" = false;
          "gnomeTheme.hideWebrtcIndicator" = false;
          "gnomeTheme.noThemedIcons" = false;
          "gnomeTheme.bookmarksOnFullscreen" = false;
        };
      };
    };
  };
}

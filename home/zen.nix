{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ inputs.zen-browser.homeModules.beta ];
  # Only web pages and links; the module's setAsDefaultBrowser would also take
  # plain text and JSON files
  xdg.mimeApps.defaultApplications = lib.genAttrs [
    "text/html"
    "application/xhtml+xml"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
  ] (_: "zen-beta.desktop");
  programs.zen-browser = {
    enable = true;
    # The workspace's name above the tabs, which the switcher at the bottom of
    # the sidebar already shows; and the library's list of sections when only one
    # is left in it, keeping the buttons under it that bring the others back
    profiles.default.userChrome = ''
      .zen-current-workspace-indicator {
        display: none !important;
      }
      #zen-library-sidebar-tabs:has(> .zen-library-tab:only-child) {
        display: none !important;
      }
    '';
    policies = {
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
          private_browsing = true;
        };
      };
      # uBlock's managed storage, given through policy rather than a managed-storage file
      "3rdparty".Extensions."uBlock0@raymondhill.net".userSettings = [
        [
          "prefetchingDisabled"
          "false"
        ]
      ];
    };
    profiles.default.settings = {
      "spellchecker.dictionary_path" = "${pkgs.hunspellDicts.en_GB-ize}/share/hunspell";
      "spellchecker.dictionary" = "en-GB,en_GB";
      "intl.accept_languages" = "en-GB,en";
      "browser.tabs.insertAfterCurrent" = true;
      "middlemouse.paste" = config.dconf.settings."org/gnome/desktop/interface".gtk-enable-primary-paste;
      "media.webrtc.camera.allow-pipewire" = true; # lets camera work
      "browser.aboutConfig.showWarning" = false;
      "intl.regional_prefs.use_os_locales" = true; # en_GB dates, though Zen's own language is en-US
      "zen.theme.hide-unified-extensions-button" = false; # Otherwise uBlock's button can't be reached
      # Zen's default, the floating address bar for new tabs; set rather than left
      # out, as Zen keeps an earlier value in prefs.js
      "zen.urlbar.replace-newtab" = true;
      # Not the address bar at startup, which Zen opens when the space it starts
      # in has no tabs
      "zen.urlbar.open-on-startup" = false;
      "browser.search.suggest.enabled" = true; # Search engine suggestions, which Zen turns off
      # Search suggestions in the address bar too, which Zen also turns off. Without
      # them, the home page search box hands off to the address bar in search mode,
      # so it only searches instead of also taking addresses
      "browser.urlbar.suggest.searches" = true;
      # Zen's defaults, set rather than left out, as Zen keeps earlier values (no
      # swiping to new spaces or the library, a library of only history) in
      # prefs.js. This brings back any library sections taken out of it at each
      # start
      "zen.workspaces.swipe-actions.edge-actions" = true;
      "zen.library.hidden-tabs" = "";
      # The home page, which Zen also uses as the new tab page when
      # zen.urlbar.replace-newtab is off: a search box and three rows of shortcuts. Zen
      # already turns off stories and sponsored shortcuts, but also the
      # shortcuts themselves
      "browser.newtabpage.activity-stream.feeds.topsites" = true;
      "browser.newtabpage.activity-stream.topSitesRows" = 3;
      "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
      "browser.newtabpage.pinned" = "";
      "browser.newtabpage.activity-stream.feeds.section.highlights" = false;
      "browser.newtabpage.activity-stream.showSearch" = true;
      "browser.cache.disk.smart_size.enabled" = false; # Otherwise capacity is ignored
      "browser.cache.disk.capacity" = 256 * 1024;
      "browser.cache.disk.parent_directory" = "/run/user/${toString config.home.uid}/zen";
    };
  };
}

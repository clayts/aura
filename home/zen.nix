{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  # The zen-browser-flake variant: beta, or twilight (Zen's nightly builds)
  variant = "beta";
in
{
  imports = [ inputs.zen-browser.homeModules.${variant} ];
  # Only web pages and links; the module's setAsDefaultBrowser would also take
  # plain text and JSON files
  xdg.mimeApps.defaultApplications = lib.genAttrs [
    "text/html"
    "application/xhtml+xml"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
  ] (_: "zen-${variant}.desktop");
  programs.zen-browser = {
    enable = true;
    # The workspace's name above the tabs, which the switcher at the bottom of
    # the sidebar already shows
    profiles.default.userChrome = ''
      .zen-current-workspace-indicator {
        display: none !important;
      }
      /* In compact mode with the top toolbar, the floating sidebar the same
         distance from the top of the window as from the bottom, as it is with
         a single toolbar, rather than starting under the top toolbar */
      :root[zen-compact-mode="true"]:not([zen-single-toolbar="true"])
        #navigator-toolbox:not([animate="true"]) {
        margin-top: 0 !important;
        top: calc(var(--zen-compact-float) / 2) !important;
        bottom: auto !important;
        height: calc(100% - var(--zen-compact-float)) !important;
      }
      /* A little space before the compact mode (sidebar) button in the top
         toolbar, in compact mode */
      :root[zen-compact-mode="true"] #zen-toggle-compact-mode {
        margin-inline-start: 8px !important;
      }
    '';
    # uBlock's button in the extensions menu rather than on the toolbar
    profiles.default.extensionButtons."unified-extensions-area" = [ "uBlock0@raymondhill.net" ];
    # From Zen's mod store (zen-browser.app/mods), fetched when the system is built
    profiles.default.mods = [
      "6c122084-c4ec-4c9e-8cc5-3d87c3a089cb" # NavBar Margin
    ];
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
      "zen.welcome-screen.seen" = true; # No first-run wizard, as for guest
      "zen.updates.show-update-notification" = false; # Nor a note after each update
      "intl.regional_prefs.use_os_locales" = true; # en_GB dates, though Zen's own language is en-US
      "zen.theme.hide-unified-extensions-button" = false; # Otherwise uBlock's button can't be reached
      # Zen's default, the floating address bar for new tabs; set rather than left
      # out, as Zen keeps an earlier value in prefs.js
      "zen.urlbar.replace-newtab" = true;
      "zen.view.compact.enable-at-startup" = true;
      # The "Sidebar and Top Toolbar" layout
      "zen.view.use-single-toolbar" = false;
      "zen.view.sidebar-expanded" = true;
      "zen.urlbar.behavior" = "float"; # Always floating
      "zen.workspaces.continue-where-left-off" = true;
      # Not the address bar at startup, which Zen opens when the space it starts
      # in has no tabs
      "zen.urlbar.open-on-startup" = false;
      "browser.search.suggest.enabled" = true; # Search engine suggestions, which Zen turns off
      # Search suggestions in the address bar too, which Zen also turns off. Without
      # them, the home page search box hands off to the address bar in search mode,
      # so it only searches instead of also taking addresses
      "browser.urlbar.suggest.searches" = true;
      # Zen's default, set rather than left out, as Zen keeps an earlier value
      # (no swiping to new spaces or the library) in prefs.js
      "zen.workspaces.swipe-actions.edge-actions" = true;
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

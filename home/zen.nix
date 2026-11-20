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
      /* In compact mode, the floating sidebar flush with the window's edges,
         with square corners */
      :root[zen-compact-mode="true"] #navigator-toolbox {
        --zen-compact-float: 0px !important;
      }
      :root[zen-compact-mode="true"] #navigator-toolbox .zen-toolbar-background {
        &,
        &::before,
        &::after {
          border-radius: 0 !important;
        }
        /* Its outline (in Zen's colour for it) only on the side facing the
           page, as the window's own outline already runs along the others */
        &::before,
        &::after {
          outline: none !important;
          box-shadow: inset -1px 0 0 rgba(255, 255, 255, 0.15) !important;
        }
      }
      :root[zen-compact-mode="true"][zen-right-side="true"] #navigator-toolbox .zen-toolbar-background {
        &::before,
        &::after {
          box-shadow: inset 1px 0 0 rgba(255, 255, 255, 0.15) !important;
        }
      }
      /* In compact mode, the sidebar kept hidden in a window or space with no
         tabs (Zen's empty tab), which Zen otherwise shows as if hovered; it
         still shows on hover and the like */
      :root[zen-compact-mode="true"]:not([customizing], [inDOMFullscreen="true"], [zen-renaming-tab="true"])
        #navigator-toolbox[zen-has-empty-tab]:not([zen-has-hover], [zen-user-show], [flash-popup], [has-popup-menu], [movingtab], [zen-compact-mode-active], [animate="true"]) {
        translate: var(--zen-compact-hidden-translate) !important;
        transition:
          translate 0.15s ease,
          visibility 0.15s ease !important;
        & #titlebar {
          visibility: hidden !important;
          transition: visibility 0.15s !important;
        }
      }
      /* The window's outline unbroken round its corners. GTK draws the
         outline (adw-gtk3's 1px ring) behind Zen, curving in further at the
         corners than Zen's own rounding (the theme's 15px), so Zen covered
         the curves. Rounding Zen's corners at 18px leaves GTK's curves in
         view, without a gap between them and the window; found by measuring
         at 1x and 2x scale */
      @media (-moz-gtk-csd-transparency-available) {
        :root[customtitlebar][sizemode="normal"]:not([tiled])
          :is(body, #zen-main-app-wrapper, #zen-browser-background) {
          border-top-left-radius: 18px !important;
          border-top-right-radius: 18px !important;
          /* Firefox rounds the bottom corners, of both window and outline,
             only with this */
          @media -moz-pref("widget.gtk.rounded-bottom-corners.enabled") {
            border-radius: 18px !important;
          }
        }
        /* Where Zen's rounded edge meets GTK's curve, each lets a little of
           what's behind the window through, a dark line inside the outline
           against Zen's lighter frame. Behind Zen's frame, and over GTK's
           curve, the outline's colour (lighter while the window's focused),
           so nothing shows through. In dark mode only: in light the
           outline is nearly transparent and the frame light, so no line */
        @media (prefers-color-scheme: dark) {
          :root[customtitlebar][sizemode="normal"]:not([tiled]) body {
            --zen-aura-outline: rgb(58, 58, 60);
            background-color: var(--zen-aura-outline) !important;
            box-shadow: 0 0 0 1px var(--zen-aura-outline) !important;
          }
          :root[customtitlebar][sizemode="normal"]:not([tiled]):-moz-window-inactive body {
            --zen-aura-outline: rgb(47, 47, 49);
          }
        }
      }
      /* Zen's frame (the sidebar and the edge round the page) in GNOME's
         sidebar colours, libadwaita's sidebar_bg_color and, while the
         window isn't focused, sidebar_backdrop_color, rather than Zen's own
         greys; only for Zen's default theme, so a space's own colour stays */
      :root[zen-default-theme="true"] :is(#zen-browser-background, .zen-toolbar-background) {
        --zen-aura-frame: #ebebed;
        @media (prefers-color-scheme: dark) {
          --zen-aura-frame: #2e2e32;
        }
        &:-moz-window-inactive {
          --zen-aura-frame: #f2f2f4;
          @media (prefers-color-scheme: dark) {
            --zen-aura-frame: #28282c;
          }
        }
        --zen-main-browser-background: var(--zen-aura-frame) !important;
        --zen-main-browser-background-old: var(--zen-aura-frame) !important;
        --zen-main-browser-background-toolbar: var(--zen-aura-frame) !important;
        --zen-main-browser-background-toolbar-old: var(--zen-aura-frame) !important;
      }
    '';
    # uBlock's button in the extensions menu rather than on the toolbar
    profiles.default.extensionButtons."unified-extensions-area" = [ "uBlock0@raymondhill.net" ];
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
      # Not compact mode (the sidebar hidden until hovered) at startup; it can
      # still be turned on from the sidebar's menu
      "zen.view.compact.enable-at-startup" = false;
      # The "Only Sidebar" layout, with no top toolbar, and the sidebar on the
      # right
      "zen.view.use-single-toolbar" = true;
      "zen.view.sidebar-expanded" = true;
      "zen.tabs.vertical.right-side" = true;
      "zen.urlbar.behavior" = "float"; # Always floating
      "zen.workspaces.continue-where-left-off" = true;
      "zen.tabs.show-newtab-vertical" = false; # No "New Tab" in the tab list
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

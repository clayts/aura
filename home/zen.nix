{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.zen-browser;
  autoconfig = pkgs.writeText "autoconfig.js" ''
    pref("general.config.filename", "zen.cfg");
    pref("general.config.obscure_value", 0);
    pref("general.config.sandbox_enabled", false);
  '';
in
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
    # Zen reads autoconfig from beside its real binary, which the wrapper's
    # extraPrefs never reach, so it goes into the unwrapped package (as the
    # module itself does for policies)
    unwrappedPackage =
      (inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta-unwrapped.override {
        inherit (cfg) policies enablePrivateDesktopEntry;
      }).overrideAttrs
        (old: {
          postInstall = (old.postInstall or "") + ''
            for libdir in "$out"/lib/zen-bin-*; do
              chmod -R u+w "$libdir/defaults"
              install -m 644 ${./zen-newtab.js} "$libdir/zen.cfg"
              install -m 644 ${autoconfig} "$libdir/defaults/pref/zen-autoconfig.js"
            done
          '';
        });
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
    # The workspace's name above the tabs, which the switcher at the bottom of
    # the sidebar already shows
    profiles.default.userChrome = ''
      .zen-current-workspace-indicator {
        display: none !important;
      }
    '';
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
      "zen.urlbar.replace-newtab" = false; # A new tab page rather than the floating address bar
      # The new tab and home page: three rows of shortcuts and nothing else. Zen
      # already turns off stories and sponsored shortcuts, but also the
      # shortcuts themselves
      "browser.newtabpage.activity-stream.feeds.topsites" = true;
      "browser.newtabpage.activity-stream.topSitesRows" = 3;
      "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
      "browser.newtabpage.pinned" = "";
      "browser.newtabpage.activity-stream.feeds.section.highlights" = false;
      "browser.newtabpage.activity-stream.showSearch" = false;
      "browser.cache.disk.smart_size.enabled" = false; # Otherwise capacity is ignored
      "browser.cache.disk.capacity" = 256 * 1024;
      "browser.cache.disk.parent_directory" = "/run/user/${toString config.home.uid}/zen";
    };
  };
}

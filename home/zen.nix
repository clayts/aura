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
    # Zen always keeps at least one workspace, and with only one it hides the
    # workspace switcher but still shows that workspace's name above the tabs
    profiles.default.userChrome = ''
      :root:has(#zen-workspaces-button[dont-show="true"]) .zen-current-workspace-indicator {
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
      "browser.cache.disk.smart_size.enabled" = false; # Otherwise capacity is ignored
      "browser.cache.disk.capacity" = 256 * 1024;
      "browser.cache.disk.parent_directory" = "/run/user/${toString config.home.uid}/zen";
    };
  };
}

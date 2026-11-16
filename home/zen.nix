{
  inputs,
  config,
  pkgs,
  ...
}:
{
  imports = [ inputs.zen-browser.homeModules.beta ];
  programs.zen-browser = {
    enable = true;
    policies = {
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
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
      "browser.cache.disk.smart_size.enabled" = false; # Otherwise capacity is ignored
      "browser.cache.disk.capacity" = 256 * 1024;
      "browser.cache.disk.parent_directory" = "/run/user/${toString config.home.uid}/zen";
    };
  };
}

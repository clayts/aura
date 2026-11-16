// Open the address bar over each new tab, as Zen does in place of a new tab
// page when zen.urlbar.replace-newtab is on, but with the new tab page under it
Services.obs.addObserver(window => {
  const { BrowserCommands, gBrowser } = window;
  const openTab = BrowserCommands.openTab;
  BrowserCommands.openTab = function (options = {}) {
    const previous = gBrowser.selectedTab;
    const result = openTab.call(this, options);
    // Not for a middle click, which can open a search for the clipboard
    if (!options.url && options.event?.button != 1 && gBrowser.selectedTab != previous) {
      window.document.getElementById("Browser:OpenLocation").doCommand();
    }
    return result;
  };
}, "browser-delayed-startup-finished");

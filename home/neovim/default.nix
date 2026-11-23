{
  pkgs,
  lib,
  config,
  osConfig,
  style,
  ...
}:
let
  nvim = lib.getExe config.programs.neovim.finalPackage;
  # Neovim GTK, a GTK 4 window for Neovim, set to run this Neovim, with
  # its header bar dark like the editor. It takes its font from GNOME's
  # monospace font, and its font features from ginit.vim. nixpkgs builds it
  # looking for its runtime, with GuiFont and its other commands, where it
  # was built, so it's told where it was installed
  neovim-gtk = pkgs.symlinkJoin {
    name = "neovim-gtk";
    paths = [ pkgs.neovim-gtk ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/nvim-gtk \
        --add-flags "--nvim-bin-path ${nvim}" \
        --set NVIM_GTK_RUNTIME_PATH ${pkgs.neovim-gtk}/share/nvim-gtk/runtime \
        --set NVIM_GTK_PREFER_DARK_THEME 1
    '';
    meta.mainProgram = "nvim-gtk";
  };
  # What init.lua and the colour scheme need from Nix, as require("aura")
  aura = {
    inherit (style) colors;
    font.features = style.fonts.mono.features;
    # nixd's settings, as Zed has them: nixpkgs, and the options of this
    # NixOS and Home Manager configuration, from the system flake
    nixd =
      let
        flake = ''(builtins.getFlake "${osConfig.programs.nh.flake}")'';
        nixos = "${flake}.nixosConfigurations.${osConfig.networking.hostName}.options";
      in
      {
        nixpkgs.expr = "import ${flake}.inputs.nixpkgs { }";
        formatting.command = [ "nixfmt" ];
        options = {
          nixos.expr = nixos;
          home-manager.expr = "${nixos}.home-manager.users.type.getSubOptions []";
        };
      };
    direnv = lib.getExe config.programs.direnv.package;
  };
in
{
  home.packages = [ neovim-gtk ];
  # Neovim GTK's window background is transparent, for its NGTransparency
  # command, which lets the desktop show through wherever its widgets don't
  # quite meet, as at the sidebar's edge. The user's GTK CSS comes before the
  # app's own, so this makes it the editor's. Only Neovim GTK's window has
  # the nvim-background class
  # Its sidebar, a box with a tree view in it, is coloured as libadwaita colours
  # sidebars, which, dark, is grey2, with a faint highlight for the selected
  # row in place of GTK's blue
  gtk.gtk4.extraCss = ''
    window.nvim-background {
      background: ${style.colors.grey0};
    }
    window.nvim-background paned > box.view,
    window.nvim-background paned > box.view treeview.view {
      background-color: ${style.colors.grey2};
    }
    window.nvim-background paned > box.view treeview.view:selected {
      background-color: alpha(currentColor, 0.1);
      color: inherit;
    }
  '';
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    # Language servers, formatters and the tools the pickers use. They come
    # after PATH, so a project's own, from its direnv, are used first
    extraPackages = with pkgs; [
      # Nix
      nixd
      nixfmt
      # Lua
      lua-language-server
      stylua
      # Shell
      bash-language-server
      shellcheck
      shfmt
      # Python
      basedpyright
      ruff
      # Rust and Go, for projects without their own
      rust-analyzer
      gopls
      # JavaScript, TypeScript, HTML, CSS, JSON
      vtsls
      vscode-langservers-extracted
      superhtml
      emmet-language-server
      prettier
      # Markup and config
      yaml-language-server
      taplo
      lemminx
      marksman
      # Pickers
      ripgrep
      fd
    ];
    # ripgrep, as the file and text pickers run it, also searches hidden
    # files, like fzf's fd --hidden, but not .git
    extraWrapperArgs = [
      "--set"
      "RIPGREP_CONFIG_PATH"
      "${pkgs.writeText "ripgreprc" ''
        --hidden
        --glob=!.git
      ''}"
    ];
    plugins = with pkgs.vimPlugins; [
      mini-nvim
      blink-cmp
      friendly-snippets
      conform-nvim
      nvim-lspconfig
      lazydev-nvim
      SchemaStore-nvim
      nvim-treesitter.withAllGrammars
      nvim-treesitter-textobjects
    ];
    initLua = builtins.readFile ./init.lua;
  };
  xdg.configFile = {
    "nvim/lua/aura.lua".text = "return ${lib.generators.toLua { } aura}\n";
    "nvim/colors/custom.lua".source = ./colors/custom.lua;
    # Neovim GTK runs ginit.vim once its window is up
    "nvim/ginit.vim".text = ''
      execute 'GuiFontFeatures' join(v:lua.require('aura').font.features, ',')
      lua vim.keymap.set("n", "<Leader>E", "<Cmd>NGToggleSidebar<CR>", { desc = "Sidebar" })
    '';
  };
  # Neovim takes folders, for Open With, but Files still opens them
  xdg.mimeApps.defaultApplications."inode/directory" = "org.gnome.Nautilus.desktop";
  xdg.desktopEntries = {
    # Neovim in a terminal, hidden as Micro is; Neovim GTK is the app
    "nvim" = {
      name = "Neovim";
      noDisplay = true;
    };
    # In place of Neovim GTK's own, under the name GNOME matches its window to
    "org.daa.NeovimGtk" = {
      name = "Neovim";
      genericName = "Text Editor";
      comment = "Edit text files";
      icon = "nvim";
      exec = "${lib.getExe neovim-gtk} -- %F";
      categories = [
        "Utility"
        "TextEditor"
        "Development"
      ];
      mimeType = [
        "text/plain"
        "text/markdown"
        "text/x-nix"
        "text/x-python"
        "text/rust"
        "text/x-go"
        "text/javascript"
        "text/css"
        "text/html"
        "application/json"
        "application/toml"
        "application/xml"
        "application/x-yaml"
        "application/x-shellscript"
        "text/x-shellscript"
        "inode/directory"
      ];
      startupNotify = true;
    };
  };
}

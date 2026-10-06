{
  pkgs,
  lib,
  config,
  inputs,
  assets,
  ...
}:
{
  imports = [
    inputs.nix-index-database.homeModules.nix-index
  ];
  home.packages = with pkgs; [
    assets.packages.earthpaper
    assets.packages.safe
    assets.packages.sing
    grc
  ];
  programs = {
    ripgrep-all = {
      enable = true;
    };
    bat = {
      enable = true;
      extraPackages = with pkgs.bat-extras; [
        batdiff
        batman
        batpipe
        batwatch
      ];
      config = {
        style = "plain";
        pager = "never";
        theme = "base16";
      };
    };
    nix-index = {
      enable = true;
      enableZshIntegration = false; # slow - just use comma
    };
    nix-index-database.comma.enable = true;
    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
      silent = true;
    };
    git.enable = true;
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };
    lsd = {
      enable = true;
      enableZshIntegration = true;
      icons = {
        name = {
          "desk" = "󱈹";
          "code" = "";
          "universe" = "";
          "${config.home.username}" = "";
        };
      };
    };
    gh.enable = true;
    fd.enable = true;
    starship = {
      enable = true;
      enableZshIntegration = true;
      presets = [ "no-runtime-versions" ];
      settings = {
        add_newline = false;
        format = lib.strings.concatStrings [
          "($username"
          "(@$hostname) )"
          "\${custom.directory_icon}"
          "$directory"
          "$git_branch"
          "$git_commit"
          "$git_state"
          "$git_status"
          "$direnv"
          "$env_var"
          "$jobs"
          "$shlvl"
          "$character"
        ];
        git_branch = {
          format = "[($symbol$branch(:$remote_branch) )]($style)";
          symbol = "󰊢 ";
          style = "bright-white";
        };
        git_status = {
          format = "[($all_status$ahead_behind)]($style)";
          style = "bright-white";
          conflicted = "$count󰩋 ";
          ahead = "$count󰶣 ";
          behind = "$count󰶡 ";
          diverged = "$ahead_count󰶣 $behind_count󰶡 ";
          up_to_date = "";
          untracked = "$count󰱼 ";
          stashed = "$count󱋡 ";
          modified = "$count󱇧 ";
          staged = "$count󰈖 ";
          renamed = "$count󱈖 ";
          deleted = "$count󱪡 ";
        };
        direnv = {
          disabled = false;
          format = "[($loaded)]($style)";
          loaded_msg = "󱧶 ";
          unloaded_msg = "󱧴 ";
          style = "bold yellow";
        };
        directory = {
          format = "[$read_only]($read_only_style)[$path]($style) ";
          truncate_to_repo = false;
          truncation_symbol = "…";
          truncation_length = 3;
          style = "bold blue";
          read_only = "󰏮 ";
          read_only_style = "bold blue";
        };
        username = {
          format = "([ $user]($style))";
          style_root = "bright-red";
        };
        hostname = {
          format = "[($hostname)]($style)";
        };
        custom = {
          directory_icon = {
            when = true;
            style = "blue";
            command = "lsd -d $(pwd) --icon always | cut -c1-2";
            format = "[$symbol($output )]($style)";
          };
        };
        shlvl = {
          disabled = false;
          symbol = "❯";
          style = "bright-green";
          repeat = true;
          repeat_offset = 1;
          format = "[$symbol]($style)";
        };
        character = {
          success_symbol = "[❯](bold bright-green)";
          error_symbol = "[❯](bold bright-red)";
        };
        jobs = {
          symbol = "󰒲";
          style = "purple";
        };
      };
    };
    zsh = {
      enable = true;
      plugins = [
        {
          name = "fzf-tab";
          src = "${pkgs.zsh-fzf-tab}/share/fzf-tab";
        }
        {
          name = "grc";
          src = "${pkgs.grc}/etc";
          file = "grc.zsh";
        }
      ];
      shellAliases = {
        edit = "$EDITOR";
        open = "xdg-open";
        l = "lsd --almost-all --long --git --group-dirs first --no-symlink --date relative";
        ls = lib.mkForce "lsd --group-dirs first";
        lt = lib.mkForce "lsd --tree --long --git --group-dirs first --no-symlink --date relative";
        ssh = "TERM='xterm-256color' ssh";
        cd = "z";
        diff = "batdiff";
        man = "batman --pager less";
        cat = "bat";
      };
      sessionVariables = {
        GREP_OPTIONS = "--color=auto";
        DIRENV_WARN_TIMEOUT = 0;
      };
      dotDir = "${config.xdg.stateHome}/zsh";
      historySubstringSearch.enable = true;
      syntaxHighlighting.enable = true;
      autosuggestion.enable = true;
      initContent = ''
        [[ -o interactive ]] && [[ -n $DISPLAY ]] && [[ $SHLVL -eq 1 ]] && ${assets.packages.rizzlefetch}/bin/rizzlefetch && echo
        echo

        # keybindings
        bindkey "$terminfo[kcuu1]" history-substring-search-up
        bindkey "$terminfo[kcud1]" history-substring-search-down
        bindkey  "^[[H"   beginning-of-line
        bindkey  "^[[F"   end-of-line
        bindkey  "^[[3~"  delete-char

        # batpipe
        eval "$(batpipe)"
      '';
    };
  };
}

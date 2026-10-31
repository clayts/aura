{
  pkgs,
  lib,
  config,
  ...
}:
let
  # Folder on Google Drive that holds the encrypted files
  folder = "Encrypted";
  mountPoint = "${config.home.homeDirectory}/Cloud";
  # rclone.conf holds the Drive token and crypt passwords, so rclone keeps it encrypted, and this
  # fetches the key from the GNOME keyring, which is unlocked at login
  password = pkgs.writeShellScript "rclone-password" ''
    exec ${lib.getExe' pkgs.libsecret "secret-tool"} lookup application rclone
  '';
  setup = pkgs.writeShellApplication {
    name = "cloud-setup";
    runtimeInputs = with pkgs; [
      rclone
      libsecret
      coreutils
      systemd
    ];
    runtimeEnv.RCLONE_PASSWORD_COMMAND = password;
    text = ''
      if ! secret-tool lookup application rclone >/dev/null; then
          head -c 32 /dev/urandom | base64 -w 0 |
              secret-tool store --label "rclone config" application rclone
      fi

      # /tmp is a tmpfs, so the config is never on disk unencrypted
      tmp="$(mktemp -d)"
      trap 'rm -rf "$tmp"' EXIT
      conf="$tmp/rclone.conf"

      echo "Sign in to Google Drive in the browser window that opens"
      rclone config create gdrive drive scope=drive --config "$conf" >/dev/null

      ask() {
          local value confirm
          while true; do
              IFS= read -rsp "$1: " value && echo >&2
              IFS= read -rsp "Confirm $1: " confirm && echo >&2
              [[ $value == "$confirm" ]] && break
              echo "Passwords do not match, try again" >&2
          done
          rclone obscure - <<<"$value"
      }
      echo "Enter the encryption passwords; to reuse existing encrypted files, enter the ones they were made with"
      password="$(ask password)"
      password2="$(ask "salt password")"
      # Appended rather than passed to rclone config create, which would show them in ps
      cat >>"$conf" <<EOF
      [cloud]
      type = crypt
      remote = gdrive:${folder}
      filename_encryption = standard
      directory_name_encryption = true
      password = $password
      password2 = $password2
      EOF

      RCLONE_PASSWORD_CHANGE=1 rclone config encryption set --config "$conf" >/dev/null
      install -D -m 600 "$conf" ${lib.escapeShellArg "${config.xdg.configHome}/rclone/rclone.conf"}

      systemctl --user restart cloud.service
      echo "Mounted at "${lib.escapeShellArg mountPoint}
    '';
  };
in
{
  home = {
    packages = [
      pkgs.rclone
      setup
    ];
    # Lets rclone on the command line read the config too
    sessionVariables.RCLONE_PASSWORD_COMMAND = "${password}";
  };
  systemd.user.services.cloud = {
    Unit = {
      Description = "Encrypted Google Drive mount at ${mountPoint}";
      # The keyring is only reachable once the session is up
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      # Skipped until cloud-setup has run
      ConditionPathExists = "${config.xdg.configHome}/rclone/rclone.conf";
    };
    Service = {
      Type = "notify";
      Environment = [
        # Where NixOS puts the setuid fusermount3
        "PATH=/run/wrappers/bin"
        "RCLONE_PASSWORD_COMMAND=${password}"
      ];
      ExecStartPre = "${lib.getExe' pkgs.coreutils "mkdir"} -p ${lib.escapeShellArg mountPoint}";
      ExecStart = "${lib.getExe pkgs.rclone} mount --vfs-cache-mode=full --cache-dir=%C/rclone cloud: ${lib.escapeShellArg mountPoint}";
      # rclone unmounts on SIGTERM, then exits with 143
      SuccessExitStatus = 143;
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}

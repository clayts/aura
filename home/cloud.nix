{
  pkgs,
  lib,
  config,
  ...
}:
let
  # Credentials can't go in the world-readable Nix store, so they live here as plain files,
  # written once by cloud-setup and read by the rclone-config service on each login
  secrets = "${config.xdg.configHome}/rclone/secrets";
  # Folder on Google Drive that holds the encrypted files
  folder = "Encrypted";
  mountPoint = "${config.home.homeDirectory}/Cloud";
  # Named after the mount's remote path ("" for the root) and remote, see home-manager's rclone module
  mountService = "rclone-mount:@cloud";
  secretFiles = [
    "${secrets}/token"
    "${secrets}/password"
    "${secrets}/password2"
  ];
  setup = pkgs.writeShellApplication {
    name = "cloud-setup";
    runtimeInputs = with pkgs; [
      config.programs.rclone.package
      coreutils
      jq
      systemd
    ];
    text = ''
      secrets=${lib.escapeShellArg secrets}
      tmp="$(mktemp -d)"
      trap 'rm -rf "$tmp"' EXIT

      echo "Sign in to Google Drive in the browser window that opens"
      rclone config create gdrive drive scope=drive --config "$tmp/rclone.conf" >/dev/null
      token="$(rclone config dump --config "$tmp/rclone.conf" | jq -er .gdrive.token)"

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

      install -d -m 700 "$secrets"
      install -m 600 /dev/stdin "$secrets/token" <<<"$token"
      install -m 600 /dev/stdin "$secrets/password" <<<"$password"
      install -m 600 /dev/stdin "$secrets/password2" <<<"$password2"

      systemctl --user restart rclone-config.service ${lib.escapeShellArg "${mountService}.service"}
      echo "Mounted at "${lib.escapeShellArg mountPoint}
    '';
  };
  # Until cloud-setup has run, skip the services rather than have them fail on every login
  needsSecrets.Unit.ConditionPathExists = secretFiles;
in
{
  home.packages = [ setup ];
  programs.rclone = {
    enable = true;
    remotes = {
      gdrive = {
        config = {
          type = "drive";
          scope = "drive";
        };
        secrets.token = "${secrets}/token";
      };
      cloud = {
        config = {
          type = "crypt";
          remote = "gdrive:${folder}";
          filename_encryption = "standard";
          directory_name_encryption = true;
        };
        secrets = {
          password = "${secrets}/password";
          password2 = "${secrets}/password2";
        };
        mounts."" = {
          enable = true;
          inherit mountPoint;
        };
      };
    };
  };
  systemd.user.services = {
    rclone-config = needsSecrets;
    ${mountService} = needsSecrets;
  };
}

# Vaults, a GNOME app for gocryptfs vaults. nixpkgs dropped it along with
# CryFS (which needs the removed fuse2), so it's built here for gocryptfs only.
# Upstream targets Flatpak and runs everything through flatpak-spawn: the patch
# runs gocryptfs directly and locks with NixOS's setuid fusermount3 (plain
# umount can't unmount a user's FUSE mount), and stops it warning at every
# start that CryFS is missing
{ pkgs }:
pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "vaults";
  version = "0.13.0";
  src = pkgs.fetchFromGitHub {
    owner = "mpobaschnig";
    repo = "vaults";
    tag = finalAttrs.version;
    hash = "sha256-DTuCkPBsKNMzKo9fktab5AM+AK9o3aby4zwxlwknK68=";
  };
  cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    hash = "sha256-tQeLUJ4r7iPNHySBF6vMl5rPhmv2vJ65jgcN4n2DE5o=";
  };
  patches = [
    (pkgs.replaceVars ./vaults.patch {
      gocryptfs = pkgs.lib.getExe' pkgs.gocryptfs "gocryptfs";
      fusermount = "/run/wrappers/bin/fusermount3";
    })
  ];
  # The post-install script updates caches in the system's /usr, so it's
  # replaced by compiling just this app's settings schema
  postPatch = ''
    substituteInPlace meson.build \
      --replace-fail "meson.add_install_script('build-aux/meson_post_install.py')" ""
  '';
  postInstall = ''
    glib-compile-schemas $out/share/glib-2.0/schemas
  '';
  nativeBuildInputs = with pkgs; [
    glib
    meson
    ninja
    pkg-config
    desktop-file-utils
    appstream
    wrapGAppsHook4
    cargo
    rustc
    rustPlatform.cargoSetupHook
  ];
  buildInputs = with pkgs; [
    glib
    gtk4
    libadwaita
  ];
  meta.mainProgram = "vaults";
})

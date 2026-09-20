# Android build shell for komikku-M3E on a headless x86_64 Linux host.
#
# Enter with:  nix-shell
#
# The repo declares JavaVersion.VERSION_17 / JvmTarget.JVM_17 (buildSrc AndroidConfig.kt)
# and COMPILE_SDK 36, so this shell provides JDK 17 and the platform 36 SDK.
#
# The SDK is read-only (a Nix store path). Gradle only reads it; AVDs and Gradle
# caches live outside, so set GRADLE_USER_HOME to a writable directory on a large
# disk (the repo lives on /mnt/2tb-ext4).
#
# nixpkgs comes from the flake registry, so this file is not pinned.

let
  pkgs = import (builtins.getFlake "nixpkgs") {
    system = builtins.currentSystem;
    config = {
      android_sdk.accept_license = true;
      allowUnfree = true;
    };
  };

  androidComposition = pkgs.androidenv.composeAndroidPackages {
    cmdLineToolsVersion = "latest";
    platformToolsVersion = "latest";
    buildToolsVersions = [
      "36.0.0"
      "35.0.0"
    ];
    platformVersions = [ "36" ];
    includeEmulator = true;
    includeSystemImages = true;
    systemImageTypes = [ "default" ];
    abiVersions = [ "x86_64" ];
    includeSources = false;
    includeNDK = false;
    includeCmake = false;
  };

  androidSdk = androidComposition.androidsdk;
  androidHome = "${androidSdk}/libexec/android-sdk";
  jdk = pkgs.jdk17;
in
pkgs.mkShell {
  name = "komikku-m3e-android";

  packages = [ jdk ];

  JAVA_HOME = jdk.home;
  ANDROID_HOME = androidHome;
  ANDROID_SDK_ROOT = androidHome;

  # AGP downloads `aapt2` from Google's Maven repository and runs it as a daemon.
  # That binary cannot start on NixOS (it is dynamically linked for a generic
  # Linux layout), which fails the resource tasks. Pass this through the build
  # with -Pandroid.aapt2FromMavenOverride=$(printenv AAPT2_OVERRIDE).
  AAPT2_OVERRIDE = "${androidHome}/build-tools/36.0.0/aapt2";

  shellHook = ''
    for dir in "$ANDROID_HOME"/cmdline-tools/*/bin "$ANDROID_HOME/platform-tools" "$ANDROID_HOME/emulator"; do
      PATH="$dir:$PATH"
    done
    export PATH

    # AVDs must be writable; the SDK is a store path. Do NOT override ANDROID_USER_HOME: the
    # debug keystore used to sign the APK lives in $HOME/.android, and a different user home
    # produces a different key, so an update install fails with
    # INSTALL_FAILED_UPDATE_INCOMPATIBLE.
    export ANDROID_AVD_HOME=''${ANDROID_AVD_HOME:-/mnt/2tb-ext4/.android-avd}

    echo "komikku-M3E Android shell"
    echo "  JAVA_HOME=$JAVA_HOME"
    echo "  ANDROID_HOME=$ANDROID_HOME"
    echo "  aapt2 override: $AAPT2_OVERRIDE"
    echo "  AVD home: $ANDROID_AVD_HOME"
    echo "  gradle: pass -Pandroid.aapt2FromMavenOverride=\$AAPT2_OVERRIDE"
  '';
}

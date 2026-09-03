#!/usr/bin/env sh
# Idempotent toolchain bootstrap for the organizer project (NFR21).
#
# Provisions, under gitignored .toolchain/:
#   - the official Flutter SDK of the pinned 3.47.x line — seeded from a
#     pre-existing official SDK of the exact pinned version when one is on
#     this machine (FLUTTER_SEED, no download), otherwise downloaded as the
#     sha256-verified official tarball (NEVER `devbox add flutter` — nixpkgs
#     lags the line's patches and is not the official SDK);
#   - the Android SDK (cmdline-tools + platform-tools + platform 36 +
#     build-tools 36), because nixpkgs carries no android-sdk package
#     (verified 2026-08-27). Needed by `make build` / `make run` and by
#     the two Gradle-backed egress seals under `make check` (story 4-2).
#   - the Gradle wrapper under android/, injected from the pinned SDK's
#     own cache so the egress seals can resolve the Gradle graph and
#     merge the manifests without a prior `flutter build` (story 4-2).
#     Flutter-managed files, kept out of git; the pinned distribution
#     stays in the committed gradle-wrapper.properties.
#
# A patch bump within the 3.47 line is exactly two edited values below
# (version, sha256) plus a re-lock and the gate — plus one visible,
# deliberate re-freeze of the egress Gradle-graph allowlist (seal 2,
# story 4-2: the engine-hash io.flutter coordinates change with the
# engine; `dart run tool/check_gradle_dependencies.dart --re-freeze`
# prints the new literal). Nothing else changes.
#
# Offline behaviour: once the SDK is provisioned (seeded or unpacked) and
# the archives are cached in .toolchain/downloads/, this script performs
# no network access.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TOOLCHAIN="$ROOT/.toolchain"
DOWNLOADS="$TOOLCHAIN/downloads"
mkdir -p "$DOWNLOADS"

# --- The pinned Flutter SDK (line 3.47.x, latest stable patch) ---------------
FLUTTER_VERSION=3.47.2
FLUTTER_SHA256=447878859d01ca9bfdb99a85f245af07ed8a15fedcd9d189c4749e8e92d1f185
FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_ARCHIVE}"
# A pre-existing official SDK of the exact pinned version can seed .toolchain/
# flutter as a symlink instead of downloading. The seed is opt-in per machine:
# set FLUTTER_SEED in the environment or in gitignored tool/env.local.sh
# (sourced by tool/env.sh). Empty disables the seed.
FLUTTER_SEED="${FLUTTER_SEED:-}"

# --- Android SDK (build/run + the Gradle-backed egress seals) -----------------
CMDLINETOOLS_BUILD=13114758
CMDLINETOOLS_SHA256=7ec965280a073311c339e571cd5de778b9975026cfcbe79f2b1cdcb1e15317ee
ANDROID_PLATFORM=android-36
ANDROID_BUILD_TOOLS=36.0.0

log() { printf '[bootstrap] %s\n' "$*"; }

verify_sha256() {
  actual=$(sha256sum "$1" | cut -d' ' -f1)
  if [ "$actual" != "$2" ]; then
    printf '[bootstrap] sha256 mismatch for %s\n  expected %s\n  actual   %s\n' "$1" "$2" "$actual" >&2
    rm -f "$1"
    exit 1
  fi
}

fetch_cached() {
  url=$1
  archive=$2
  sha256=$3
  if [ ! -f "$DOWNLOADS/$archive" ]; then
    log "downloading $archive"
    curl -sSL --fail --connect-timeout 30 --max-time 900 -o "$DOWNLOADS/$archive.part" "$url"
    mv "$DOWNLOADS/$archive.part" "$DOWNLOADS/$archive"
  fi
  verify_sha256 "$DOWNLOADS/$archive" "$sha256"
}

# --- Flutter -------------------------------------------------------------------
# The pin marker lives OUTSIDE the SDK tree (.toolchain/flutter.pinned) so a
# seeded .toolchain/flutter symlink never writes into the seed SDK.
FLUTTER_MARKER="$TOOLCHAIN/flutter.pinned"
sdk_version() {
  sed -n 's/.*"flutterVersion": *"\([^"]*\)".*/\1/p' "$1/bin/cache/flutter.version.json" 2>/dev/null | head -n 1
}

need_flutter=1
if [ -x "$TOOLCHAIN/flutter/bin/flutter" ] \
   && [ "$(cat "$FLUTTER_MARKER" 2>/dev/null || true)" = "$FLUTTER_VERSION" ]; then
  # A seeded SDK upgraded in place leaves the marker stale — trust the SDK's
  # own version file when present: if it disagrees with the pin, re-provision.
  if [ -f "$TOOLCHAIN/flutter/bin/cache/flutter.version.json" ]; then
    installed=$(sdk_version "$TOOLCHAIN/flutter")
    if [ "$installed" = "$FLUTTER_VERSION" ]; then
      need_flutter=0
    else
      log "installed SDK reports $installed, pin is $FLUTTER_VERSION — re-provisioning"
    fi
  else
    need_flutter=0
  fi
fi

if [ "$need_flutter" = 0 ]; then
  log "Flutter $FLUTTER_VERSION already provisioned"
else
  if [ -n "$FLUTTER_SEED" ] && [ "$(sdk_version "$FLUTTER_SEED")" = "$FLUTTER_VERSION" ]; then
    log "seeding Flutter $FLUTTER_VERSION from $FLUTTER_SEED (official SDK already on this machine — no download)"
    rm -rf "$TOOLCHAIN/flutter"
    ln -s "$FLUTTER_SEED" "$TOOLCHAIN/flutter"
  else
    fetch_cached "$FLUTTER_URL" "$FLUTTER_ARCHIVE" "$FLUTTER_SHA256"
    log "unpacking Flutter $FLUTTER_VERSION"
    rm -rf "$TOOLCHAIN/flutter"
    tar -xJf "$DOWNLOADS/$FLUTTER_ARCHIVE" -C "$TOOLCHAIN"
  fi
  printf '%s\n' "$FLUTTER_VERSION" > "$FLUTTER_MARKER"
fi

# Make the freshly installed SDK visible to the calling shell (the devbox
# init_hook only sources tool/env.sh at shell start, before a first bootstrap).
case ":$PATH:" in
  *":$TOOLCHAIN/flutter/bin:"*) ;;
  *) PATH="$TOOLCHAIN/flutter/bin:$PATH"; export PATH ;;
esac

flutter config --no-analytics >/dev/null 2>&1 || true

# --- Android SDK (cmdline-tools; platform 36; build-tools 36) ------------------
SDK="$TOOLCHAIN/android-sdk"
need_sdk=0
if [ ! -d "$SDK/platforms/$ANDROID_PLATFORM" ] || [ ! -d "$SDK/build-tools/$ANDROID_BUILD_TOOLS" ] \
   || [ ! -d "$SDK/platform-tools" ]; then
  # An interrupted install (e.g. platforms present, platform-tools absent)
  # must be treated as incomplete and re-run.
  need_sdk=1
fi

if [ "$need_sdk" = 1 ]; then
  fetch_cached \
    "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINETOOLS_BUILD}_latest.zip" \
    "commandlinetools-linux-${CMDLINETOOLS_BUILD}_latest.zip" \
    "$CMDLINETOOLS_SHA256"
  log "unpacking Android cmdline-tools"
  rm -rf "$SDK/cmdline-tools"
  mkdir -p "$SDK/cmdline-tools"
  unzip -q "$DOWNLOADS/commandlinetools-linux-${CMDLINETOOLS_BUILD}_latest.zip" -d "$SDK/cmdline-tools"
  mv "$SDK/cmdline-tools/cmdline-tools" "$SDK/cmdline-tools/latest"

  SDKMANAGER="$SDK/cmdline-tools/latest/bin/sdkmanager"
  export ANDROID_HOME="$SDK"
  export ANDROID_SDK_ROOT="$SDK"

  log "accepting Android SDK licences"
  yes 2>/dev/null | "$SDKMANAGER" --licenses >/dev/null

  log "installing platform-tools, $ANDROID_PLATFORM, build-tools $ANDROID_BUILD_TOOLS"
  yes 2>/dev/null | "$SDKMANAGER" \
    "platform-tools" "platforms;$ANDROID_PLATFORM" "build-tools;$ANDROID_BUILD_TOOLS" >/dev/null
else
  log "Android SDK ($ANDROID_PLATFORM) already provisioned"
fi

# --- Gradle wrapper (injected from the pinned SDK's cache) ---------------------
# The egress seals (story 4-2: resolved-graph allowlist, merged-manifest
# enumeration) drive gradlew directly and must run in CI before any
# `flutter build` has produced a wrapper. The wrapper files are the
# Flutter SDK's own, so they are injected here — idempotently, every
# bootstrap — and gitignored (see .gitignore); the distribution pin
# lives in the committed android/gradle/wrapper/gradle-wrapper.properties.
# No cache-warming step is needed: the official tarball itself ships
# bin/cache/artifacts/gradle_wrapper/{gradlew,gradlew.bat,gradle/wrapper/
# gradle-wrapper.jar} (verified 2026-09-03 by listing
# flutter_linux_3.47.2-stable.tar.xz), so a fresh unpack always has it.
WRAPPER_SRC="$TOOLCHAIN/flutter/bin/cache/artifacts/gradle_wrapper"
if [ -d "$WRAPPER_SRC" ]; then
  log "injecting the Gradle wrapper from the pinned Flutter SDK"
  mkdir -p "$ROOT/android/gradle/wrapper"
  cp -f "$WRAPPER_SRC/gradlew" "$ROOT/android/gradlew"
  cp -f "$WRAPPER_SRC/gradlew.bat" "$ROOT/android/gradlew.bat"
  cp -f "$WRAPPER_SRC/gradle/wrapper/gradle-wrapper.jar" \
    "$ROOT/android/gradle/wrapper/gradle-wrapper.jar"
  chmod +x "$ROOT/android/gradlew"
else
  printf '[bootstrap] the pinned SDK has no gradle_wrapper cache (%s) — the egress seals will not run; re-provision the SDK\n' "$WRAPPER_SRC" >&2
  exit 1
fi

log "toolchain ready"

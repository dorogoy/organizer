#!/usr/bin/env sh
# Environment glue for the devbox shell (sourced by devbox.json's init_hook)
# and for `devbox run --` (sourced where needed by the Makefile / bootstrap).
#
# The Flutter SDK is NOT a nix package: it is the official SDK of the pinned
# 3.47.x line under gitignored .toolchain/flutter/ — a symlink to a
# pre-existing official SDK of the exact pinned version when one is on the
# machine (FLUTTER_SEED in tool/bootstrap.sh), otherwise the sha256-verified
# official tarball unpacked by tool/bootstrap.sh (NFR21 — never
# `devbox add flutter`). The Android SDK is provisioned the same way under
# .toolchain/android-sdk/ because nixpkgs has no android-sdk package
# (verified 2026-08-27).
#
# This script is idempotent and safe to source repeatedly.

# Machine-local overrides, gitignored — e.g. FLUTTER_SEED for
# tool/bootstrap.sh. Sourced before anything else so overrides can shape the
# rest of the environment.
[ -f "$PWD/tool/env.local.sh" ] && . "$PWD/tool/env.local.sh"

# When sourced (devbox init_hook, Makefile recipes, CI), $0 is the sourcing
# shell — resolve the root from the working directory instead, falling back
# to $0 for direct execution.
if [ -f "$PWD/tool/env.sh" ]; then
  ORGANIZER_ROOT=$PWD
else
  ORGANIZER_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fi

# Pinned Flutter SDK on PATH (ahead of anything the host may leak in).
if [ -d "$ORGANIZER_ROOT/.toolchain/flutter/bin" ]; then
  case ":$PATH:" in
    *":$ORGANIZER_ROOT/.toolchain/flutter/bin:"*) ;;
    *) PATH="$ORGANIZER_ROOT/.toolchain/flutter/bin:$PATH" ;;
  esac
  export PATH
fi

# Android SDK provisioned by the bootstrap (needed by make build / make
# run and by the two Gradle-backed egress seals under make check —
# story 4-2: they drive gradlew before any flutter build has happened).
if [ -d "$ORGANIZER_ROOT/.toolchain/android-sdk" ]; then
  export ANDROID_HOME="$ORGANIZER_ROOT/.toolchain/android-sdk"
  export ANDROID_SDK_ROOT="$ANDROID_HOME"
fi

# JAVA_HOME always follows the java that the devbox shell resolves — an
# inherited host JAVA_HOME (possibly pointing at a non-LTS) is never kept.
JAVA_BIN=$(command -v java 2>/dev/null || true)
if [ -n "$JAVA_BIN" ]; then
  _JAVA_HOME=$(dirname "$(dirname "$JAVA_BIN")")
  [ -d "$_JAVA_HOME" ] && export JAVA_HOME="$_JAVA_HOME"
fi
unset _JAVA_HOME JAVA_BIN

# libsqlite3 for drift's host-side tests (Story 1.3): NativeDatabase loads
# libsqlite3.so through the dynamic loader, whose default search does not
# include the nix profile's package directories. The devbox sqlite package
# ships the library next to its sqlite3 binary, so resolve it there and put
# it on LD_LIBRARY_PATH — deterministic in every devbox environment (CI
# included), independent of any host leak.
SQLITE3_BIN=$(command -v sqlite3 2>/dev/null || true)
if [ -n "$SQLITE3_BIN" ]; then
  SQLITE3_REAL=$(readlink -f "$SQLITE3_BIN" 2>/dev/null || printf '%s' "$SQLITE3_BIN")
  SQLITE3_LIB=$(dirname "$(dirname "$SQLITE3_REAL")")/lib
  if [ -f "$SQLITE3_LIB/libsqlite3.so" ]; then
    case ":${LD_LIBRARY_PATH:-}:" in
      *":$SQLITE3_LIB:"*) ;;
      *) LD_LIBRARY_PATH="$SQLITE3_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" && export LD_LIBRARY_PATH ;;
    esac
  fi
fi
unset SQLITE3_BIN SQLITE3_REAL SQLITE3_LIB

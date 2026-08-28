# organizer — the development loop (NFR20).
#
# Registration rule, verbatim from Story 1.1's AC 13:
#   Given a later story that introduces a `tool/` check or a build-time guard
#   When that story is complete
#   Then its target is registered in the `Makefile` and reachable from
#   `make check` in the same pass (NFR20).
#
# The environment contract is devbox's (NFR21): every target here runs inside
# `devbox shell` (locally) or through `devbox run --` (CI), never on the host
# toolchain. No target wraps its commands in `devbox …` — that contract is
# devbox's, not the Makefile's. Toolchain-dependent recipes source
# ./tool/env.sh first: it is idempotent glue that re-resolves the SDK paths
# after a first `make deps` in a shell opened before provisioning, and a
# no-op when nothing changed.

.PHONY: help gate deps test test-core format format-check analyze check run build clean

.DEFAULT_GOAL := help

help: ## List every target with a one-line description
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

deps: ## Provision the pinned SDKs (sha256-verified) and fetch pub dependencies
	./tool/bootstrap.sh && . ./tool/env.sh && flutter pub get && cd packages/core && dart pub get

test: ## Run the root suite (flutter test)
	. ./tool/env.sh && flutter test

test-core: ## Run the pure-Dart core suite (dart test, no emulator)
	. ./tool/env.sh && cd packages/core && dart test

format: ## Format every Dart file (root and packages/core)
	. ./tool/env.sh && dart format .

format-check: ## Verify formatting without rewriting anything
	. ./tool/env.sh && dart format --set-exit-if-changed .

analyze: ## Static analysis (flutter analyze; see check for the tool/ checks)
	. ./tool/env.sh && flutter analyze

check: ## Run the tool/ checks that exist today: core purity (AD-3, AD-5)
	. ./tool/env.sh && dart run tool/check_core_purity.dart

gate: ## NFR17 story completion gate: flutter test, format check, analyze
	. ./tool/env.sh && flutter test
	. ./tool/env.sh && dart format --set-exit-if-changed .
	. ./tool/env.sh && flutter analyze

run: ## Run the app on a connected Android device (needs make deps once)
	. ./tool/env.sh && flutter run

build: ## Build a debug APK (release signing arrives with Epic 9, AD-18)
	. ./tool/env.sh && flutter build apk --debug

clean: ## Remove build outputs and resolution caches (keeps .toolchain SDKs)
	. ./tool/env.sh && flutter clean
	rm -rf packages/core/.dart_tool

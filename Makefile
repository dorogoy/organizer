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

.PHONY: help gate deps codegen codegen-check test test-core format format-check analyze check run build clean eval-probe eval-run eval-judge eval-report

.DEFAULT_GOAL := help

help: ## List every target with a one-line description
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

deps: ## Provision the pinned SDKs (sha256-verified) and fetch pub dependencies
	. ./tool/env.sh && ./tool/bootstrap.sh && . ./tool/env.sh && flutter pub get
	. ./tool/env.sh && cd packages/core && dart pub get
	. ./tool/env.sh && cd eval && dart pub get

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

check: ## Run every tool/ check: core purity (AD-3, AD-5), no-literal-strings + string-table audit (AD-15), text scaling (UX-DR45), forbidden vocabulary (naming), store seal (AD-21), catalogue floor, continuity, evolution, dictate wire contract, codegen freshness, eval harness unit tests (story 4.1)
	. ./tool/env.sh && dart run tool/check_core_purity.dart
	. ./tool/env.sh && dart run tool/check_no_literal_strings.dart
	. ./tool/env.sh && dart run tool/check_text_scaling.dart
	. ./tool/env.sh && dart run tool/check_string_table_audit.dart
	. ./tool/env.sh && dart run tool/check_forbidden_vocabulary.dart
	. ./tool/env.sh && dart run tool/check_store_seal.dart
	. ./tool/env.sh && dart run tool/check_catalogue_floor.dart
	. ./tool/env.sh && dart run tool/check_catalogue_id_diff.dart
	. ./tool/env.sh && dart run tool/check_catalogue_evolution.dart
	. ./tool/env.sh && dart run tool/check_dictate_wire_contract.dart
	. ./tool/env.sh && cd eval && dart test
	$(MAKE) --no-print-directory codegen-check

codegen: ## Regenerate every generated file (store schema, localization accessors, catalogue lookup)
	. ./tool/env.sh && dart run build_runner build --delete-conflicting-outputs
	. ./tool/env.sh && flutter gen-l10n
	. ./tool/env.sh && dart run tool/gen_catalogue_lookup.dart

codegen-check: ## Fail when a generated file is stale or untracked (store schema, localization accessors, catalogue lookup; needs make deps once)
	$(MAKE) --no-print-directory codegen
	@if git diff --exit-code -- lib/store/substrate.g.dart lib/strings/app_strings.dart lib/strings/app_strings_es.dart lib/catalogue/catalogue_names.g.dart; then \
		if git ls-files --others --exclude-standard -- lib/store/substrate.g.dart lib/strings/app_strings.dart lib/strings/app_strings_es.dart lib/catalogue/catalogue_names.g.dart | grep -q .; then \
			echo "codegen check FAILED: a generated file is untracked — regenerate and commit the scoped outputs" >&2; \
			exit 1; \
		fi; \
		echo 'codegen check passed'; \
	else \
		echo "codegen check FAILED: generated files are stale — run 'make codegen', then stage and commit the regenerated files" >&2; \
		exit 1; \
	fi

eval-probe: ## Probe the local Lemonade endpoint with one corpus photo (image-input gate, story 4.1)
	. ./tool/env.sh && cd eval && dart run bin/harness.dart probe

eval-run: ## Score one candidate over the corpus: CANDIDATE=e2b_local|e4b_local|gemini|openai|anthropic, optional VIA=openrouter
	. ./tool/env.sh && cd eval && dart run bin/harness.dart run --candidate $(CANDIDATE) $(if $(VIA),--via $(VIA),)

eval-judge: ## Judge the two human limbs per photo: CANDIDATE=<id> (re-ask via dart run ... judge --candidate <id> --redo)
	. ./tool/env.sh && cd eval && dart run bin/harness.dart judge --candidate $(CANDIDATE)

eval-report: ## Write eval/results/report.md + scores.json (selection proposal + OQ-1 draft)
	. ./tool/env.sh && cd eval && dart run bin/harness.dart report

gate: ## NFR17 story completion gate: flutter test, format check, analyze
	. ./tool/env.sh && flutter test
	. ./tool/env.sh && dart format --set-exit-if-changed .
	. ./tool/env.sh && flutter analyze

run: ## Run the app on a connected Android device (needs make deps once)
	. ./tool/env.sh && flutter run

build: ## Build a debug APK (release signing arrives with Epic 9, AD-18)
	. ./tool/env.sh && flutter build apk --debug

clean: ## Remove build outputs, Gradle project state and resolution caches (keeps .toolchain SDKs)
	. ./tool/env.sh && flutter clean
	rm -rf packages/core/.dart_tool
	# Gradle's project-local state bakes absolute worktree paths into
	# itself (execution history, configuration cache). Once a sibling
	# worktree is renamed, moved or deleted, every Android compile here
	# resolves dead paths — the 1-9 break over the deleted 1-8 worktree's
	# android.jar. flutter clean never touches this state; only purging
	# it re-resolves the SDK fresh.
	rm -rf android/.gradle android/build android/app/build

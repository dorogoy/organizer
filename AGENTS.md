<!-- bmad:context -->
<!-- Verified 2026-08-27 against f30667c. Managed by bmad-project-context; edits inside this block are replaced on refresh. Keep anything you want preserved outside the markers. -->

## organizer

Anti-overwhelm mobile task organizer, validation build: single-user Android app, local-first, no backend. Flutter/Dart with a pure-Dart functional core (no Flutter imports in core). Greenfield — no code yet; the stack and its invariants are decided in the architecture spine: `_bmad-output/planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md`.

## Policy

- A story (or any implementation unit) is not done until all three pass: `flutter test`, `dart format --set-exit-if-changed .`, `flutter analyze`. Never present work with one of them red or unrun.
- Invocations are the canonical Flutter toolchain for the decided stack (Flutter 3.47 / Dart 3.13); no project exists yet — verify them on the first refresh once `pubspec.yaml` lands, and prefer a CI check over this line when CI exists.
- The development environment is devbox: `devbox shell` before any toolchain command, locally and in CI; `devbox.json` + `devbox.lock` are committed. The build JVM is a current JDK LTS from devbox (21, or 25 once the template's Gradle is 9.1+ — never the 17 minimum, never a non-LTS); the Java/Kotlin bytecode level is the Flutter template's own (17 today), not ours to choose. The Flutter SDK is the official tarball of the pinned 3.47.x line with version and sha256 recorded — never `devbox add flutter` (nixpkgs lags the line's patches and is not the official bits). Full rule: `project-context.md` → Development environment.

<!-- /bmad:context -->

## Android emulation setup (manual verification)

One-time, machine-local — reuse the existing toolchain, never install a second SDK/Studio:

- This is an Orca worktree: symlink the machine's toolchain instead of provisioning another one (`.toolchain/` is gitignored): `ln -sfn /home/moltbot/develop/organizer/.toolchain .toolchain` — `tool/env.sh` then resolves both Flutter and `ANDROID_HOME` from the shared install.
- Emulation needs three pieces the bootstrap does not ship. Add them once **into that same SDK** (inside `devbox shell`, after `. ./tool/env.sh`): `yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses` then `"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" "emulator" "system-images;android-36;google_apis;x86_64"` (~1.5 GB).
- KVM is required: `sudo usermod -aG kvm $USER` + re-login (a one-off `sudo chmod 666 /dev/kvm` lasts only until reboot). Without KVM a boot takes 30+ minutes — do not.
- Create the AVD once: `"$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" create avd -n organizer36 -k "system-images;android-36;google_apis;x86_64" -d pixel_6`.

Per session:

- Boot headless: `"$ANDROID_HOME/emulator/emulator" -avd organizer36 -no-window -no-audio -no-boot-anim -no-snapshot -gpu swiftshader_indirect` — boots in ~25 s with KVM.
- adb is not on PATH: `ADB=$ANDROID_HOME/platform-tools/adb`.
- App: `devbox run -- make build` → `$ADB install -r build/app/outputs/flutter-apk/app-debug.apk` → `$ADB shell am start -n dev.dorogoy.organizer/.MainActivity`.
- Verifying the UI: `uiautomator dump` comes back empty for Flutter unless an accessibility service is attached — verify via `screencap` + image OCR instead; check foreground with `dumpsys window | grep mCurrentFocus`.
- Synthesizing absence (Warm Return and friends): `adb root` (the `google_apis` image allows it), then `$ADB shell "date -s @$((epoch))"`. The 48 h gap measures from the **last contact in the log, not "now"** — after a fresh open, device-now +49 h is due; always compute targets from the **device** clock (`$ADB shell date +%s`), never the host's. To read the app's actual log: `$ADB shell "cat /data/data/dev.dorogoy.organizer/app_flutter/organizer_substrate.sqlite" > log.sqlite`, then `sqlite3` (in devbox).
- Restore after tests: `settings put system font_scale 1.0`, `cmd uimode night no`, `date -s @<host epoch>`; stop with `$ADB -s emulator-5554 emu kill`.

Reference run with full evidence: story 2-7's spec, `_bmad-output/implementation-artifacts/2-7-warm-return.md` → Manual Verification.

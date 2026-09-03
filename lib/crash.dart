import 'dart:async';

import 'package:core/log/log_entry.dart';
import 'package:core/ports/store_port.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Installs the build's only diagnostics destination (AD-12): uncaught
/// Flutter errors and platform errors each append one `crash_recorded` entry
/// through the store port. No logging framework, no print channel, no third
/// store — the crash entry is the whole channel, and it swallows its own
/// write failures so the guard can never become a second crash.
///
/// The append is fire-and-forget: if the process dies hard before the write
/// lands, that entry is lost — an accepted trade-off, since blocking the
/// error path to guarantee durability is worse.
void installCrashGuard(StorePort store) {
  FlutterError.onError = (details) {
    unawaited(appendCrashEntry(store, details.stack?.toString()));
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(appendCrashEntry(store, stackTrace.toString()));
    return true;
  };
}

/// Appends exactly one `crash_recorded` entry: the stack and the timestamp
/// (plus the shell-minted id and the offset in force) and nothing else
/// (AD-12). The entry type offers no other field, so no task text, image
/// path, prompt or URL can ride along. The shell may read the clock; the
/// core never does (AD-3).
Future<void> appendCrashEntry(
  StorePort store,
  String? stack, {
  Uuid idMinter = const Uuid(),
}) async {
  final now = DateTime.now();
  final resolvedStack = stack ?? StackTrace.current.toString();
  final LogEntryRecord entry = (
    id: idMinter.v7(),
    kind: LogKind.crashRecorded.name,
    instantUtcMicros: now.microsecondsSinceEpoch,
    offsetSeconds: now.timeZoneOffset.inSeconds,
    itemId: null,
    itemOrigin: null,
    stack: resolvedStack,
    settingKey: null,
    settingValue: null,
    settingTextValue: null,
    pocketMinutes: null,
    energyLevel: null,
    reportValue: null,
    reportWeek: null,
    permission: null,
  );
  try {
    await store.appendLogEntry(entry);
  } catch (error) {
    // Swallowed on purpose: a failing diagnostics write must never surface
    // on a user surface or re-enter the error path — the handler swallows
    // its own write failures.
  }
}

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

/// Replacement for a matched credential in a crash stack (AD-22).
const String _redactedText = '[REDACTED]';

/// Authorization headers and query keys whose values must not persist.
const String _sensitivePatternString =
    r'(Bearer[ \t]+|Authorization[:=][ \t]*(?:Bearer[ \t]+)?|x-api-key[:=][ \t]*|x-goog-api-key[:=][ \t]*|(?:api[_-]?key|key|token)=)([^\s\n\r,;&]+)';

/// Standalone `sk-…` (20+ after the prefix) and classic Gemini `AIzaSy`+33.
const String _apiKeyTokenPatternString =
    r'\b(?:sk-[a-zA-Z0-9_\-]{20,}|AIzaSy[a-zA-Z0-9_\-]{33})\b';

final RegExp _sensitivePattern = RegExp(
  _sensitivePatternString,
  caseSensitive: false,
);

final RegExp _apiKeyTokenPattern = RegExp(_apiKeyTokenPatternString);

/// Redacts allowlisted credential shapes; surrounding frames stay.
String sanitizeStackTrace(String input) {
  final sanitizedHeader = input.replaceAllMapped(
    _sensitivePattern,
    (match) => match.group(1)! + _redactedText,
  );
  return sanitizedHeader.replaceAll(_apiKeyTokenPattern, _redactedText);
}

/// Appends exactly one `crash_recorded` entry: the stack and the timestamp
/// (plus the shell-minted id and the offset in force) and nothing else
/// (AD-12). The entry type offers no other field, so no task text, image
/// path, prompt or URL can ride along. The shell may read the clock; the
/// core never does (AD-3). The resolved stack is sanitized immediately
/// before the store write so provider plaintext cannot ride the event
/// (AD-22).
Future<void> appendCrashEntry(
  StorePort store,
  String? stack, {
  Uuid idMinter = const Uuid(),
}) async {
  final now = DateTime.now();
  final rawStack = stack ?? StackTrace.current.toString();
  final resolvedStack = sanitizeStackTrace(rawStack);
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
    sliceCause: null,
    cluster: null,
    enabled: null,
    triageDestination: null,
    triageVolumeTag: null,
    triageBoxId: null,
    beforeName: null,
    afterName: null,
  );
  try {
    await store.appendLogEntry(entry);
  } catch (error) {
    // Swallowed on purpose: a failing diagnostics write must never surface
    // on a user surface or re-enter the error path — the handler swallows
    // its own write failures.
  }
}

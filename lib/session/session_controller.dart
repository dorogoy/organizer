import 'dart:async';

import 'package:core/catalogue/catalogue.dart';
import 'package:core/commands/session_commands.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/ports/files_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:core/settings/settings.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../catalogue/loader.dart';
import '../strings/app_strings.dart';
import 'log_write_queue.dart';

/// Installs the session lifecycle wiring (AD-19) beside the crash guard:
/// the controller is registered as a binding observer and the launch
/// open runs once, unawaited, so the first frame never waits on the
/// store. The registrar is injectable so tests observe the registration
/// — the crash guard's own testability pattern. The [files] seam is
/// the standing adapter in production (Story 5.4's `app_opened`
/// sweep); tests that pass none simply run without the sweep.
SessionController installSessionController({
  required StorePort store,
  required AppStrings strings,
  AssetBundle? bundle,
  Uuid idMinter = const Uuid(),
  DateTime Function() nowOf = DateTime.now,
  LogWriteQueue? writeQueue,
  FilesPort? files,
  void Function(WidgetsBindingObserver observer)? addObserver,
}) {
  final controller = SessionController(
    store: store,
    strings: strings,
    bundle: bundle,
    idMinter: idMinter,
    nowOf: nowOf,
    writeQueue: writeQueue,
    files: files,
  );
  (addObserver ?? WidgetsBinding.instance.addObserver)(controller);
  unawaited(controller.handleAppOpen());
  return controller;
}

/// The session lifecycle wiring (AD-19): the shell observer that turns
/// app opens and backgroundings into log facts. It follows the crash
/// path's division of labour exactly — the core decides content (pure
/// commands over the read log), and this shell mints each record's
/// UUIDv7 id, instant and offset before the port appends. The shipped
/// catalogue loads once here: this controller is the loader's first
/// consumer (AD-16).
///
/// Handling is serialized: one event's read→compute→append runs to
/// completion before the next begins, so a rapid background→resume can
/// never observe "no session open" twice and mint two sessions. The
/// clock and id minter are injectable for tests only, exactly as with
/// [appendCrashEntry]'s id minter — the shell may read the clock; the
/// core never does (AD-3).
class SessionController with WidgetsBindingObserver {
  SessionController({
    required this.store,
    required this.strings,
    this.bundle,
    this.idMinter = const Uuid(),
    this.nowOf = DateTime.now,
    LogWriteQueue? writeQueue,
    this.files,
  }) : writeQueue = writeQueue ?? LogWriteQueue();

  final StorePort store;
  final AppStrings strings;
  final AssetBundle? bundle;
  final Uuid idMinter;
  final DateTime Function() nowOf;
  final LogWriteQueue writeQueue;

  /// The Files seam (Story 5.4): the standing adapter in production,
  /// null in tests that pass no seam. The `app_opened` sweep runs
  /// only through it — a null seam is simply no sweep, the
  /// optional-seam convention every other consumer here follows.
  final FilesPort? files;

  Future<Catalogue>? _catalogue;

  /// The serialized lifecycle: each queued step completes before the
  /// next starts. Failures clear from the chain itself so one throwing
  /// step never wedges the queue.
  Future<void> _settled = Future<void>.value();

  /// Completes after lifecycle work queued so far. Shell readers use this
  /// before deriving a card, so they see the session's persisted deal.
  Future<void> get settled => _settled;

  /// Whether the app left the foreground since the last open. The
  /// launch open belongs to main's explicit call alone: a spurious
  /// launch-time `resumed` finds this false and appends nothing.
  bool _leftForegroundSinceOpen = false;

  Future<void> _enqueue(Future<void> Function() step) {
    final chained = writeQueue.enqueue(step);
    // Readers must observe the current attempt's failure. The shared queue
    // recovers internally so the next lifecycle or Dispenser write can run.
    _settled = chained;
    return chained;
  }

  /// The app came to the foreground (or launched): appends `app_opened`
  /// and — only when no session is open — `session_started` with the
  /// session's first `card_dealt` (AD-3). A pocketed session left open
  /// by process death and fully elapsed closes here first, at this
  /// open's own instant, before any new `session_started` — the reveal,
  /// derived from the log, never scheduled (Story 2.2, AD-19). The
  /// event's instant is minted at entry, before any await, so the
  /// recorded rows — and near 04:00 the charged domestic day — describe
  /// the event, not the reads that followed it. The open also reads the
  /// pool-fact snapshot inside this one queued operation (Story 3.3):
  /// the launch deal sees manual captures, so a standing capture can
  /// be the session's very first card. Since Story 5.4 the queued step
  /// begins with the awaited, quiet scan-cache sweep (AC5, NFR14):
  /// every launch open and every resume sweeps once, before the open's
  /// rows land.
  Future<void> handleAppOpen() {
    final now = nowOf();
    _leftForegroundSinceOpen = false;
    return _enqueue(() async {
      await _sweepScanCache();
      final catalogue = await _loadCatalogue();
      final log = await _readLog();
      final poolFacts = poolFactsOf(await store.readPoolFacts());
      // The bag derives once for the whole operation (2.1) and threads
      // into the command, so the launch deal composes against the Time
      // Bag the log holds — never a default the user never chose.
      final contents = appOpen(
        catalogue: catalogue,
        log: log,
        instantUtcMicros: now.microsecondsSinceEpoch,
        offsetSeconds: now.timeZoneOffset.inSeconds,
        bagMinutes: deriveTimeBagMinutes(log),
        poolFacts: poolFacts,
      );
      await _appendAll(contents, now);
    });
  }

  /// The crash backstop (Story 5.4): a blind sweep of the scan cache
  /// at the start of the open's queued step. Every terminal path and
  /// lifecycle close unlinks its own subdirectory, so a standing
  /// child at open is either a crash leftover or a scan the surface
  /// is still deliberately holding open through a transient occlusion
  /// (an inactive→resumed beat — a notification shade pulled
  /// mid-shoot); the sweep unlinks both alike, fail-closed — an
  /// upload no one consented to can never ride a lingering frame —
  /// and the departure-cancels policy that would keep such a scan's
  /// own files alive is Story 5.6's to govern. The sweep runs at
  /// every open, launch and resume alike, and never on background or
  /// end. Quiet on every error: a backstop may never break the open
  /// it runs inside (the adapter is quiet by contract; this guard
  /// keeps even a throwing seam from surfacing).
  Future<void> _sweepScanCache() async {
    final files = this.files;
    if (files == null) {
      return;
    }
    try {
      await files.sweepScanCache();
    } on Object {
      // Folded into nothing: the open proceeds whatever the sweep met.
    }
  }

  /// The app left the foreground: appends `session_ended` — one of
  /// AD-19's three closing causes, and 1.6's only one. The write is
  /// awaited inside the serialized step, so it is at least initiated
  /// and awaited before the handler's work completes; a process death
  /// mid-write can still lose the row — the crash path's accepted
  /// trade-off, and there is deliberately no synchronous channel.
  Future<void> handleSessionEnd() {
    final now = nowOf();
    return _enqueue(() async {
      final log = await _readLog();
      await _appendAll(sessionEnd(log: log), now);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Only a real return from off-foreground re-opens — the launch
        // open is main's explicit call alone.
        if (_leftForegroundSinceOpen) {
          unawaited(handleAppOpen());
        }
      case AppLifecycleState.inactive:
        // A transient occlusion (a banner, the app switcher's first
        // frame) ends no session, but it is a real departure as far as
        // the next `resumed` is concerned.
        _leftForegroundSinceOpen = true;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _leftForegroundSinceOpen = true;
        unawaited(handleSessionEnd());
    }
  }

  /// The catalogue loads once per controller lifetime. A failed load is
  /// not memoized — the memo clears on error so the next lifecycle event
  /// retries instead of throwing into the crash guard forever.
  Future<Catalogue> _loadCatalogue() =>
      _catalogue ??= _loadCatalogueRetryingAfterFailure();

  Future<Catalogue> _loadCatalogueRetryingAfterFailure() async {
    try {
      return await loadEvergreenCatalogue(strings, bundle: bundle);
    } catch (_) {
      _catalogue = null;
      rethrow;
    }
  }

  Future<List<LogEntry>> _readLog() async =>
      logEntriesOf(await store.readLogEntries());

  /// Completes the contents into records and appends them in order. One
  /// minted instant serves the whole batch — the commands resolved the
  /// day against it, and the records must land on that same day. The
  /// supersede and reveal pairs stay adjacent at that one instant in
  /// store read order, which is what the walk's carried-card rule reads
  /// (Story 2.2).
  Future<void> _appendAll(List<LogEntryContent> contents, DateTime now) async {
    for (final content in contents) {
      await store.appendLogEntry((
        id: idMinter.v7(),
        kind: content.kind.name,
        instantUtcMicros: now.microsecondsSinceEpoch,
        offsetSeconds: now.timeZoneOffset.inSeconds,
        itemId: content.itemId,
        itemOrigin: content.itemOrigin,
        stack: content.stack,
        settingKey: content.settingKey,
        settingValue: content.settingValue,
        settingTextValue: null,
        pocketMinutes: content.pocketMinutes,
        energyLevel: content.energyLevel,
        reportValue: content.reportValue,
        reportWeek: content.reportWeek,
        permission: content.permission?.name,
        sliceCause: content.sliceCause,
      ));
    }
  }
}

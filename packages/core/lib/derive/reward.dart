/// The transformation reward's milestone facts (Story 7.1, FR-17,
/// AD-25): pure derivations over the pool facts and the log, named as
/// facts and writing nothing (AD-3). Three facts, three questions:
///
/// - **Retirement** — does the handed-in `card_done` (the completion
///   path's own item id) retire its group's last step? The project
///   milestone's whole trigger, and
///   FR-26 series (c)'s countable substrate (Epic 9 derives from pool
///   + log alone; this story adds no requirement of a pair for
///   visibility).
/// - **Session milestone** — which slicer-origin space earned the
///   session's one reward: the group with the most steps completed
///   inside the ending session, never one already retired (the
///   project milestone owns that moment), one space per session.
/// - **Before lookup** — which album blob, if any, names the group's
///   persisted Before.
///
/// The group fold is the weave's own (`epicGroupsByStableId`, the one
/// projection of `_epicStepsByGroupKey`), and the retirement read is
/// the walk's own answered fold (`walkLog`'s `answeredItemIds`,
/// `epicBufferedTargets`'s same input) — no second definition of
/// "done" exists here, so the reward and the weave cannot disagree
/// about what retirement means (the story's own frozen boundary).
/// Typed-genesis spaces are indistinguishable from scans in the
/// substrate: they derive milestones too, and their absence of a
/// `before_saved` row is exactly what makes them no-Before spaces.

library;

import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/weave/session.dart';
import 'package:core/weave/weave.dart';

/// One milestone's named space (Story 7.1): the group's stable id —
/// the same id the group's `epic_activated`, `before_saved` and
/// `album_entry_added` rows name — and the group's own origin, the
/// pair every reward row carries (AD-14).
typedef NamedRewardSpace = ({String groupId, Origin origin});

/// The group whose last step the `card_done` naming [completedItemId]
/// just retired (Story 7.1, FR-17, AD-25), or null when that answer
/// names no group step or leaves steps unanswered. The id is the
/// completion path's own fact — the call site knows which item it
/// just completed, so no log-tail inference exists here: a later or
/// racing `card_done` row can never be mistaken for this answer (the
/// explicit contract — the caller hands the log as it stands once the
/// completion's write has landed, and the derivation checks only
/// whether THIS item belongs to a group whose retirement this answer
/// completes). A `card_done` on a synthetic purge id or a non-group
/// item retires nothing here. The retirement read is the walk's own
/// answered fold — all-time, the same input `epicBufferedTargets`
/// reads — so a group retired by this derivation is retired by every
/// other, and never the reverse.
NamedRewardSpace? retiringGroupId(
  List<PoolFact> poolFacts,
  List<LogEntry> log, {
  required String completedItemId,
}) {
  return _groupRetiredBy(poolFacts, log, completedItemId);
}

/// One group's named space when [stepId] belongs to a group whose
/// every step the answered fold holds, else null — retirement's one
/// read.
NamedRewardSpace? _groupRetiredBy(
  List<PoolFact> poolFacts,
  List<LogEntry> log,
  String stepId,
) {
  final group = _groupOfStep(poolFacts, stepId);
  if (group == null) {
    return null;
  }
  final answered = walkLog(log).answeredItemIds;
  final retired = group.steps.every((step) => answered.contains(step.id));
  return retired
      ? (groupId: group.stableId, origin: group.steps.first.origin)
      : null;
}

/// One group's (stable id, steps) when [stepId] is one of its steps.
({String stableId, List<PoolFact> steps})? _groupOfStep(
  List<PoolFact> poolFacts,
  String stepId,
) {
  final groups = epicGroupsByStableId(poolFacts);
  final steps = groups[stepId];
  if (steps != null) {
    return (stableId: stepId, steps: steps);
  }
  for (final entry in groups.entries) {
    if (entry.value.any((step) => step.id == stepId)) {
      return (stableId: entry.key, steps: entry.value);
    }
  }
  return null;
}

/// The session milestone's one space (Story 7.1, FR-17): the
/// slicer-origin group with the most steps completed after the latest
/// `session_started` row at [sessionStartUtcMicros] — the ending session's
/// own start instant, the caller's to hand from the walk's open-session fact
/// before the close row lands — or null when no group holds a completion.
/// The log's append order, not wall-clock order, bounds the session: a user
/// changing the device clock cannot bring an earlier session's completion
/// into this one. A
/// group whose every step is answered (the walk's fold again) is
/// excluded: its retirement was the project milestone's moment, and
/// the session milestone never fires twice for one space. Ties break
/// by earliest group creation instant, then stable id — AD-3's
/// discipline, deterministic over facts that exist, never a clock.
NamedRewardSpace? sessionMilestoneGroupId({
  required List<PoolFact> poolFacts,
  required List<LogEntry> log,
  required int sessionStartUtcMicros,
}) {
  final groups = epicGroupsByStableId(poolFacts);
  if (groups.isEmpty) {
    return null;
  }
  final sessionStartIndex = log.lastIndexWhere(
    (entry) =>
        entry is SessionStartEntry &&
        entry.instantUtcMicros == sessionStartUtcMicros,
  );
  if (sessionStartIndex < 0) {
    return null;
  }
  final stepGroupByStepId = <String, String>{};
  for (final entry in groups.entries) {
    for (final step in entry.value) {
      stepGroupByStepId.putIfAbsent(step.id, () => entry.key);
    }
  }
  final completions = <String, int>{};
  for (final entry in log.skip(sessionStartIndex + 1)) {
    if (entry is ItemActEntry && entry.kind == LogKind.cardDone) {
      final group = stepGroupByStepId[entry.itemId];
      if (group != null) {
        completions[group] = (completions[group] ?? 0) + 1;
      }
    }
  }
  if (completions.isEmpty) {
    return null;
  }
  final answered = walkLog(log).answeredItemIds;
  final groupInstantByStableId = <String, int>{};
  for (final entry in groups.entries) {
    groupInstantByStableId[entry.key] = entry.value.first.instantUtcMicros;
  }
  final candidates = [
    for (final entry in completions.entries)
      if (!groups[entry.key]!.every((step) => answered.contains(step.id)))
        entry.key,
  ];
  if (candidates.isEmpty) {
    return null;
  }
  candidates.sort((a, b) {
    final byCount = completions[b]!.compareTo(completions[a]!);
    if (byCount != 0) {
      return byCount;
    }
    final byInstant = groupInstantByStableId[a]!.compareTo(
      groupInstantByStableId[b]!,
    );
    if (byInstant != 0) {
      return byInstant;
    }
    return a.compareTo(b);
  });
  final stableId = candidates.first;
  return (groupId: stableId, origin: groups[stableId]!.first.origin);
}

/// The group's persisted Before blob name (Stories 7.1/7.2, FR-17,
/// FR-18, AD-13, AD-21) — the LATEST `before_saved` row naming
/// [groupId] in store read order that no later `album_purged` has
/// killed, or null when none stands: the declined, camera-blocked
/// and typed-genesis cases are all the same absence, never a row
/// that asserts one (AD-21), and since Story 7.2 a Before saved
/// before a purge is dead too — the fold never offers a pair whose
/// bytes cannot exist, so a post-purge milestone degrades to `Un
/// trabajo estupendo` until a fresh Before lands. The name is
/// content-addressed (sha256 hex + `.jpg`); the bytes live in the
/// Files `album` scope, never here.
String? spaceBeforeName(List<LogEntry> log, String groupId) {
  String? name;
  var nameIndex = -1;
  var lastPurgeIndex = -1;
  for (var i = 0; i < log.length; i++) {
    final entry = log[i];
    if (entry is BeforeSavedEntry && entry.itemId == groupId) {
      name = entry.blobName;
      nameIndex = i;
    } else if (entry is AlbumPurgedEntry) {
      lastPurgeIndex = i;
    }
  }
  return nameIndex > lastPurgeIndex ? name : null;
}

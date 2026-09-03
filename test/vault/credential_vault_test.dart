// The credential vault's contract (Story 4.3, AD-22) — every matrix
// row: save and replace (atomic, write-queued), delete (idempotent),
// credentialAvailable (full decrypt now, display state only),
// withCredential (granted / unavailable-without-invoking /
// request-time invalidation), the provider-id charset refusal on all
// four operations, and the plaintext discipline (no accessor returns
// it; the operation closure is its only destination).
import 'dart:async';
import 'dart:convert';

import 'package:core/ports/files_port.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/files/app_files.dart';
import 'package:organizer/platform/credentials/credentials_cipher.dart';
import 'package:organizer/vault/credential_vault.dart';

/// An in-memory Files fake: scope/name keyed bytes, refusing nothing
/// (the adapter's traversal refusal is its own test's business). A
/// delete gate holds deletes open; [failWrites] makes the next that
/// many writes throw, once each.
class _FakeFiles implements FilesPort {
  final Map<String, List<int>> blobs = {};
  int writes = 0;
  int failWrites = 0;
  Future<void> Function(String scope, String name)? deleteGate;
  Future<void> Function(String scope, String name, List<int> bytes)? writeGate;

  String _key(String scope, String name) => '$scope/$name';

  @override
  Future<List<int>?> read(String scope, String name) async =>
      blobs[_key(scope, name)];

  @override
  Future<void> write(String scope, String name, List<int> bytes) async {
    final gate = writeGate;
    if (gate != null) {
      await gate(scope, name, bytes);
    }
    if (failWrites > 0) {
      failWrites--;
      throw StateError('disk full');
    }
    writes++;
    blobs[_key(scope, name)] = List.of(bytes);
  }

  @override
  Future<void> delete(String scope, String name) async {
    final gate = deleteGate;
    if (gate != null) {
      await gate(scope, name);
    }
    blobs.remove(_key(scope, name));
  }
}

/// A scripted cipher fake: seals answer through an optional gate (so
/// a test can hold one save's seal open while a second races it);
/// unseal answers walk the scripted queue, so a test can say "the key
/// invalidated between the availability read and the request".
class _FakeCipher implements CredentialsCipher {
  final List<CredentialsUnsealConversion> unsealAnswers = [];
  CredentialsSealConversion sealAnswer = (envelope: [1, 2, 3], failure: null);
  Future<CredentialsSealConversion> Function(List<int>)? sealGate;
  List<List<int>> sealedInputs = [];
  List<List<int>> unsealedInputs = [];

  @override
  Future<CredentialsSealConversion> seal(List<int> plaintext) async {
    sealedInputs.add(plaintext);
    final gate = sealGate;
    if (gate != null) {
      return gate(plaintext);
    }
    return sealAnswer;
  }

  @override
  Future<CredentialsUnsealConversion> unseal(List<int> envelope) async {
    unsealedInputs.add(envelope);
    return unsealAnswers.removeAt(0);
  }
}

void main() {
  late _FakeFiles files;
  late _FakeCipher cipher;
  late CredentialVault vault;

  setUp(() {
    files = _FakeFiles();
    cipher = _FakeCipher();
    vault = CredentialVault(files: files, cipher: cipher);
  });

  group('save — quiet, atomic, serialized', () {
    test('a save seals the plaintext and stores the envelope at the '
        'credentials scope', () async {
      await vault.saveCredential('openai', 'sk-secret-1');

      expect(cipher.sealedInputs, [
        'sk-secret-1'.codeUnits, // utf8 of the plaintext, bytes only
      ]);
      expect(files.blobs.keys, ['$credentialFilesScope/openai']);
      // Plaintext never reaches Files storage: only the envelope.
      expect(files.blobs.values.single, isNot('sk-secret-1'.codeUnits));
    });

    test(
      'a second save replaces the first — the last envelope stands',
      () async {
        cipher.sealAnswer = (envelope: [1], failure: null);
        await vault.saveCredential('openai', 'first');
        cipher.sealAnswer = (envelope: [2], failure: null);
        await vault.saveCredential('openai', 'second');

        expect(files.blobs['$credentialFilesScope/openai'], [2]);
      },
    );

    test('a failed seal writes nothing — the previous envelope stands, '
        'quietly', () async {
      cipher.sealAnswer = (envelope: [1], failure: null);
      await vault.saveCredential('openai', 'first');
      cipher.sealAnswer = (
        envelope: null,
        failure: CredentialsCipherFailure.invalidated,
      );
      await vault.saveCredential('openai', 'second');

      expect(files.blobs['$credentialFilesScope/openai'], [1]);
    });

    test('a write that throws once is quiet with the old envelope '
        'standing; the chain recovers and the next save lands', () async {
      cipher.sealAnswer = (envelope: [1], failure: null);
      await vault.saveCredential('openai', 'first');
      expect(files.blobs['$credentialFilesScope/openai'], [1]);

      files.failWrites = 1;
      cipher.sealAnswer = (envelope: [2], failure: null);
      // Quiet: the failed write never throws to the caller, and the
      // old envelope stands exactly as it was.
      await vault.saveCredential('openai', 'second');
      expect(files.blobs['$credentialFilesScope/openai'], [1]);

      // The chain recovered: a later save lands, and the reads
      // still answer.
      cipher.sealAnswer = (envelope: [3], failure: null);
      await vault.saveCredential('openai', 'third');
      expect(files.blobs['$credentialFilesScope/openai'], [3]);
      cipher.unsealAnswers.add((plaintext: 'x'.codeUnits, failure: null));
      expect(
        await vault.credentialAvailable('openai'),
        CredentialAvailability.available,
      );
    });

    test(
      'saves serialize under the write queue — a held-open first seal '
      'blocks the second save\'s write, and the last envelope wins',
      () async {
        final firstSeal = Completer<CredentialsSealConversion>();
        cipher.sealGate = (plaintext) => utf8.decode(plaintext) == '1'
            ? firstSeal.future
            : Future.value((envelope: [2], failure: null));

        final first = vault.saveCredential('openai', '1');
        final second = vault.saveCredential('openai', '2');
        // Give both saves every chance to interleave: the second's
        // seal has already answered, but its write must queue behind
        // the first's, which is still waiting on its seal.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(files.blobs, isEmpty);

        firstSeal.complete((envelope: [1], failure: null));
        await Future.wait([first, second]);
        expect(files.blobs['$credentialFilesScope/openai'], [2]);
        expect(files.writes, 2);
      },
    );

    test(
      'a cipher seal throwing asynchronously while a write is queued is quiet',
      () async {
        final held = Completer<void>();
        files.writeGate = (scope, name, bytes) => held.future;
        final firstSave = vault.saveCredential('openai', 'first');
        await Future<void>.delayed(Duration.zero);

        cipher.sealGate = (_) => Future.error(
          const FormatException('simulated channel/protocol failure'),
        );
        final secondSave = vault.saveCredential('openai', 'second');

        held.complete();
        await firstSave;
        await expectLater(secondSave, completes);
      },
    );
  });

  group('delete — idempotent', () {
    test('deleting a stored envelope removes it', () async {
      await vault.saveCredential('openai', 'sk-secret-1');
      await vault.deleteCredential('openai');
      expect(files.blobs, isEmpty);
    });

    test('deleting an absent envelope is the same quiet outcome', () async {
      await vault.deleteCredential('openai');
      expect(files.blobs, isEmpty);
    });

    test('a failed delete is swallowed — the same quiet discipline as a '
        'failed save, and the next operation still answers', () async {
      await vault.saveCredential('openai', 'sk-secret-1');
      files.deleteGate = (scope, name) => throw StateError('fs refused');
      await vault.deleteCredential('openai');
      // The envelope still stands (the delete failed), and the
      // chain recovered.
      expect(files.blobs['$credentialFilesScope/openai'], isNotNull);

      files.deleteGate = null;
      await vault.deleteCredential('openai');
      expect(files.blobs, isEmpty);
    });
  });

  group('credentialAvailable — full decrypt now, display state only', () {
    test('a healthy envelope reads available', () async {
      await vault.saveCredential('openai', 'sk-secret-1');
      cipher.unsealAnswers.add((plaintext: 'x'.codeUnits, failure: null));
      expect(
        await vault.credentialAvailable('openai'),
        CredentialAvailability.available,
      );
    });

    test('no envelope reads missing', () async {
      expect(
        await vault.credentialAvailable('openai'),
        CredentialAvailability.missing,
      );
    });

    test('an envelope that does not decrypt reads corrupt', () async {
      await vault.saveCredential('openai', 'sk-secret-1');
      cipher.unsealAnswers.add((
        plaintext: null,
        failure: CredentialsCipherFailure.corrupt,
      ));
      expect(
        await vault.credentialAvailable('openai'),
        CredentialAvailability.corrupt,
      );
    });

    test('an invalidated wrapping key reads invalidated', () async {
      await vault.saveCredential('openai', 'sk-secret-1');
      cipher.unsealAnswers.add((
        plaintext: null,
        failure: CredentialsCipherFailure.invalidated,
      ));
      expect(
        await vault.credentialAvailable('openai'),
        CredentialAvailability.invalidated,
      );
    });

    test('an envelope decrypting to malformed UTF-8 reads corrupt', () async {
      await vault.saveCredential('openai', 'sk-secret-1');
      cipher.unsealAnswers.add((plaintext: const [0xFF, 0xFE], failure: null));
      expect(
        await vault.credentialAvailable('openai'),
        CredentialAvailability.corrupt,
      );
    });
  });

  group('withCredential — the request scope', () {
    test('granted: the operation sees the plaintext, its result returns '
        'unchanged', () async {
      await vault.saveCredential('openai', 'sk-secret-1');
      cipher.unsealAnswers.add((
        plaintext: 'sk-secret-1'.codeUnits,
        failure: null,
      ));

      final access = await vault.withCredential<String>(
        'openai',
        (plaintext) => 'used:$plaintext',
      );
      expect(access, isA<AccessGranted<String>>());
      expect((access as AccessGranted<String>).result, 'used:sk-secret-1');
    });

    test('missing: the operation is not invoked — nothing is sent', () async {
      var invoked = false;
      final access = await vault.withCredential<int>('openai', (plaintext) {
        invoked = true;
        return 1;
      });
      expect(access, isA<AccessUnavailable<int>>());
      expect(
        (access as AccessUnavailable<int>).cause,
        CredentialAccessCause.missing,
      );
      expect(invoked, isFalse);
      expect(cipher.unsealedInputs, isEmpty);
    });

    test('corrupt: unavailable, operation not invoked', () async {
      await vault.saveCredential('openai', 'sk-secret-1');
      cipher.unsealAnswers.add((
        plaintext: null,
        failure: CredentialsCipherFailure.corrupt,
      ));
      var invoked = false;
      final access = await vault.withCredential<int>('openai', (_) {
        invoked = true;
        return 1;
      });
      expect(
        (access as AccessUnavailable<int>).cause,
        CredentialAccessCause.corrupt,
      );
      expect(invoked, isFalse);
    });

    test('invalidated: unavailable, operation not invoked', () async {
      await vault.saveCredential('openai', 'sk-secret-1');
      cipher.unsealAnswers.add((
        plaintext: null,
        failure: CredentialsCipherFailure.invalidated,
      ));
      var invoked = false;
      final access = await vault.withCredential<int>('openai', (_) {
        invoked = true;
        return 1;
      });
      expect(
        (access as AccessUnavailable<int>).cause,
        CredentialAccessCause.invalidated,
      );
      expect(invoked, isFalse);
    });

    test('malformed UTF-8: corrupt cause, operation not invoked', () async {
      await vault.saveCredential('openai', 'sk-secret-1');
      cipher.unsealAnswers.add((plaintext: const [0xFF, 0xFE], failure: null));
      var invoked = false;
      final access = await vault.withCredential<int>('openai', (_) {
        invoked = true;
        return 1;
      });
      expect(
        (access as AccessUnavailable<int>).cause,
        CredentialAccessCause.corrupt,
      );
      expect(invoked, isFalse);
    });

    test(
      'request-time invalidation: available said ok, the request\'s own '
      'unseal says invalidated — unavailable, nothing sent, no retry',
      () async {
        await vault.saveCredential('openai', 'sk-secret-1');
        cipher.unsealAnswers.add((plaintext: 'x'.codeUnits, failure: null));
        expect(
          await vault.credentialAvailable('openai'),
          CredentialAvailability.available,
        );
        // The key invalidates between the display read and the request.
        cipher.unsealAnswers.add((
          plaintext: null,
          failure: CredentialsCipherFailure.invalidated,
        ));
        var invoked = false;
        final access = await vault.withCredential<int>('openai', (_) {
          invoked = true;
          return 1;
        });
        expect(
          (access as AccessUnavailable<int>).cause,
          CredentialAccessCause.invalidated,
        );
        expect(invoked, isFalse);
        // One unseal per read: the display's and the request's own —
        // the request never consulted the display's answer.
        expect(cipher.unsealedInputs, hasLength(2));
      },
    );

    test(
      'the operation\'s errors propagate unchanged — wrapped in nothing',
      () async {
        await vault.saveCredential('openai', 'sk-secret-1');
        cipher.unsealAnswers.add((
          plaintext: 'sk-secret-1'.codeUnits,
          failure: null,
        ));

        await expectLater(
          vault.withCredential<int>(
            'openai',
            (plaintext) => throw StateError('egress refused'),
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'granted after a queued save: the request drains the write chain '
      'before it reads — held open, it waits, then sees the new envelope',
      () async {
        // An initial envelope stands ([1, 2, 3], the fake's default
        // seal answer).
        await vault.saveCredential('openai', 'old');

        // A save whose seal is held open pins the write chain: the
        // request behind it must not read past it.
        final held = Completer<CredentialsSealConversion>();
        cipher.sealGate = (plaintext) => utf8.decode(plaintext) == 'held'
            ? held.future
            : Future.value((envelope: [7], failure: null));
        final saving = vault.saveCredential('openai', 'held');
        await Future<void>.delayed(Duration.zero);

        var resolved = false;
        final request = vault
            .withCredential<int>('openai', (plaintext) => 1)
            .then((access) {
              resolved = true;
              return access;
            });
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(
          resolved,
          isFalse,
          reason:
              'the request waits behind the '
              'queued save, never reads a superseded envelope',
        );

        held.complete((envelope: [7], failure: null));
        await saving;
        cipher.unsealAnswers.add((plaintext: 'x'.codeUnits, failure: null));
        final access = await request;
        expect(access, isA<AccessGranted<int>>());
        // The read saw the held save's envelope, not the one it
        // superseded.
        expect(cipher.unsealedInputs.last, [7]);
      },
    );

    test('a queued delete drains before a request: the request measures '
        'missing, the operation is not invoked', () async {
      await vault.saveCredential('openai', 'sk-secret-1');

      // Hold the delete open: the envelope still stands while the
      // queue is pinned, and the request behind it must wait.
      final released = Completer<void>();
      files.deleteGate = (scope, name) => released.future;
      final deleting = vault.deleteCredential('openai');
      await Future<void>.delayed(Duration.zero);

      var invoked = false;
      var resolved = false;
      final request = vault
          .withCredential<int>('openai', (plaintext) {
            invoked = true;
            return 1;
          })
          .then((access) {
            resolved = true;
            return access;
          });
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        resolved,
        isFalse,
        reason:
            'the request waits behind the '
            'queued delete, never sends just-revoked material',
      );

      released.complete();
      await deleting;
      final access = await request;
      expect(
        (access as AccessUnavailable<int>).cause,
        CredentialAccessCause.missing,
      );
      expect(invoked, isFalse);
    });
  });

  group('the provider-id charset — all four operations refuse quietly', () {
    for (final provider in ['../evil', 'UPPER', '', 'a' * 65]) {
      test('\'$provider\' is refused by every operation', () async {
        // Save: nothing sealed, nothing stored.
        await vault.saveCredential(provider, 'sk-secret-1');
        expect(cipher.sealedInputs, isEmpty);
        expect(files.blobs, isEmpty);

        // Delete: quiet, nothing stored to begin with.
        await vault.deleteCredential(provider);
        expect(files.blobs, isEmpty);

        // credentialAvailable: missing — an unstorable id can never
        // have a stored envelope.
        expect(
          await vault.credentialAvailable(provider),
          CredentialAvailability.missing,
        );

        // withCredential: unavailable(missing), operation not invoked.
        var invoked = false;
        final access = await vault.withCredential<int>(provider, (_) {
          invoked = true;
          return 1;
        });
        expect(
          (access as AccessUnavailable<int>).cause,
          CredentialAccessCause.missing,
        );
        expect(invoked, isFalse);
      });
    }
  });
}

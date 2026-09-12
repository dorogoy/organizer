// The photo-frame widget's contract (Story 7.1, FR-17, UX-DR29): the
// app's first image surface — 3:4 whatever the width, a 1px hairline,
// a parametric corner, and the empty right-shape plate on
// `surface-base` while the bytes load, when they are absent, and when
// they fail to decode. No spinner, no shimmer, no gradient — ever.
import 'dart:async';

import 'package:core/ports/files_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/ui/photo_frame.dart';
import 'package:organizer/ui/theme.dart';

class _FakeFiles implements FilesPort {
  _FakeFiles(this._bytesByName, {this.readGate});

  final Map<String, List<int>> _bytesByName;

  /// When set, every read parks on this completer — the loading state's
  /// own window.
  final Completer<void>? readGate;

  @override
  Future<List<int>?> read(String scope, String name) async {
    final gate = readGate;
    if (gate != null) {
      await gate.future;
    }
    return _bytesByName[name];
  }

  @override
  Future<void> write(String scope, String name, List<int> bytes) async {}

  @override
  Future<void> delete(String scope, String name) async {}

  @override
  Future<String> writeScanFrame(String scanId, List<int> bytes) async => '';

  @override
  Future<void> unlinkScan(String scanId) async {}

  @override
  Future<String> writeScanCappedCopy(String scanId, List<int> bytes) async =>
      '';

  @override
  Future<void> sweepScanCache() async {}
}

Widget _frame(FilesPort files) => MaterialApp(
  theme: OrganizerTheme.light(),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 300,
        child: PhotoFrame(files: files, name: 'hash-a.jpg'),
      ),
    ),
  ),
);

void main() {
  testWidgets('the shape is 3:4 whatever the width — 300 wide reads 400 '
      'tall', (tester) async {
    await tester.pumpWidget(_frame(_FakeFiles({})));
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(PhotoFrame));
    expect(size.width, 300);
    expect(size.height, 400);
  });

  testWidgets('while the read stands, the empty plate on surface-base '
      'holds — no spinner, no shimmer, no gradient (UX-DR29)', (tester) async {
    final gate = Completer<void>();
    await tester.pumpWidget(_frame(_FakeFiles({}, readGate: gate)));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    // The shape holds through the wait.
    expect(tester.getSize(find.byType(PhotoFrame)).height, 400);
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('an absent blob renders the same empty plate — absence is a '
      'quiet state, never an error surface', (tester) async {
    await tester.pumpWidget(_frame(_FakeFiles({})));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('decodable bytes render the image inside the hairline', (
    tester,
  ) async {
    await tester.pumpWidget(
      _frame(
        _FakeFiles({
          'hash-a.jpg': [
            137,
            80,
            78,
            71,
            13,
            10,
            26,
            10,
            0,
            0,
            0,
            13,
            73,
            72,
            68,
            82,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            1,
            8,
            6,
            0,
            0,
            0,
            31,
            21,
            196,
            137,
            0,
            0,
            0,
            13,
            73,
            68,
            65,
            84,
            120,
            156,
            99,
            250,
            207,
            192,
            80,
            15,
            0,
            4,
            133,
            1,
            128,
            132,
            169,
            139,
            224,
            0,
            0,
            0,
            0,
            73,
            69,
            78,
            68,
            174,
            66,
            96,
            130,
          ],
        }),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('undecodable bytes fold into the empty plate — never a '
      'crash, never an error surface (UX-DR29)', (tester) async {
    await tester.pumpWidget(
      _frame(
        _FakeFiles({
          'hash-a.jpg': [1, 2, 3],
        }),
      ),
    );
    await tester.pumpAndSettle();
    // The decode failure renders the empty plate through the image's
    // own error builder — the shape holds, nothing throws, and no
    // error surface exists anywhere on the frame.
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(PhotoFrame)).height, 400);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

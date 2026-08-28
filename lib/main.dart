import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: OrganizerApp()));
}

/// The shell root: Riverpod's ProviderScope wraps the whole app (shell-only
/// state management; the core is a pure function and holds no state).
///
/// No surface and no strings here — Story 1.2 owns tokens and the ARB, and
/// Story 1.8 owns the Dispenser.
class OrganizerApp extends StatelessWidget {
  const OrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: SizedBox.shrink());
  }
}

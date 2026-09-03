// The store seal's egress fixture, leak direction (Story 4-4): a
// lib/egress/ file reaching for dart:io's file family — the
// exception covers socket classification only, so every identifier
// here is a finding.
import 'dart:io';

void leak() {
  Directory('side');
  final f = File('envelope');
  f.existsSync();
}

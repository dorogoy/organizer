// The egress import seal's socket-identifier fixture: dart:io's
// HttpClient constructed outside the allowlist, no HTTP package import
// at all — the identifier sweep is what catches it.

// ignore_for_file: unused_import
import 'dart:io';

final client = HttpClient();

final int socketOutsideMarker = 0;

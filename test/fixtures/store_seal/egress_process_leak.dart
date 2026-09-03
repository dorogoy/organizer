// The store seal's egress fixture, process-family leak direction
// (Story 4-4): a lib/egress/ file reaching for dart:io's process
// family — the exception covers socket classification only, so
// every identifier here is a finding.
import 'dart:io';

void leak() async {
  final result = await Process.run('cat', ['envelope']);
  sleep(const Duration(seconds: 1));
  exit(result.exitCode);
}

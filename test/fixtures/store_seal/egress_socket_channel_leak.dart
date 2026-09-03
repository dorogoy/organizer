// The store seal's egress fixture, socket-family leak direction
// (Story 4-4): a lib/egress/ file reaching for dart:io's socket
// constructors and stdio getters — the exception covers
// SocketException classification only, so every identifier here is
// a finding. SocketException itself is not this list.
import 'dart:io';

void leak() {
  HttpClient();
  Socket.connect('127.0.0.1', 1);
  stdout.writeln('side');
}

// The store seal's egress fixture, clean direction (Story 4-4): a
// lib/egress/ file importing dart:io for SocketException
// classification alone — legal, and fenced by the file-API rule.
import 'dart:io' show SocketException;

Object? classify(Object cause) => cause is SocketException;

// The egress import seal's second violating fixture: a dio import (a
// named denylist package, not a prefix) outside the allowlist.

// ignore_for_file: unused_import, uri_does_not_exist, depend_on_referenced_packages
import 'package:dio/dio.dart';

final int dioOutsideMarker = 0;

// The egress import seal's violating fixture: an HTTP-client import in
// a file whose path is not on the allowlist.

// ignore_for_file: unused_import, uri_does_not_exist, depend_on_referenced_packages
import 'package:http/http.dart';

final int httpOutsideMarker = 0;

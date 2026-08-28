// The store seal's second violating fixture: a drift_flutter import (the
// drift* prefix) in a file whose path is not on the allowlist.

// ignore_for_file: unused_import
import 'package:drift_flutter/drift_flutter.dart';

final int otherOutsideMarker = 0;

import 'package:core/ports/store_port.dart';

import 'connection.dart';
import 'drift_store.dart';
import 'substrate.dart';

/// Opens the shell's append-only store without exposing raw Drift APIs.
StorePort openStore() => DriftStore(SubstrateDatabase(connectSubstrate()));

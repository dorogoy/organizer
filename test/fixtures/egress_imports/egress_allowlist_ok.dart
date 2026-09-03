// The egress-import guard's clean fixture (story 4-4's review
// round): importing the frozen provider allowlist from outside the
// egress module is the module's one importable surface.
import 'package:organizer/egress/provider_allowlist.dart';

var entry = allowlistEntryById;

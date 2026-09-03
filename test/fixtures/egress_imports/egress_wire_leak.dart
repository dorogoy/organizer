// The egress-import guard's leak fixture (story 4-4's review
// round): importing a wire from outside the egress module — the
// chokepoint's internals must stay inside.
import 'package:organizer/egress/byok_slicer.dart';

var slicer = ByokSlicer;

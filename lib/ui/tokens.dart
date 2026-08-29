// The single token file (UX-DR1): every DESIGN.md colour, type role, radius,
// spacing value and format rule lands exactly once, here, as a named
// constant, and is referenced nowhere else by literal value.
//
// Source of truth: DESIGN.md frontmatter — Colors, Typography, Layout &
// Spacing, Shapes, formats — transcribed by hand once (the spine's
// design-token convention; a generator earns its keep only if the palette
// moves again).
//
// Counted set: 6 field colours, 6 icon-mass colours (L* 76.0), 12 dark
// colours (the dark palette is separately authored, never an inversion;
// the one-time `border-strong-dark` token stays omitted as an orphan —
// UX-DR12), 8 typography roles, 3 radii, 15 spacing values, 2 format rules.
import 'package:flutter/painting.dart';

/// Field tier — palette "Aliento" at its own baseline lightness. Grounds,
/// cards, text, hairlines, the chip and the primary action. Never the colour
/// plate inside a glyph (UX-DR2: the tiers never touch).
abstract final class FieldPalette {
  /// The screen's floor. Cool near-white, not cream (L* 97.51).
  static const Color surfaceBase = Color(0xFFF7F8F9);

  /// The dispenser card and the full-screen decision surfaces. Distinguished
  /// from the base by tone alone, never by shadow.
  static const Color surfaceRaised = Color(0xFFFFFFFF);

  /// Task text, the chip's text, the primary action, every glyph's line layer.
  static const Color inkPrimary = Color(0xFF1E2124);

  /// The secondary action, support copy, the quiet zone marker.
  static const Color inkSecondary = Color(0xFF5C6368);

  /// 1px card, button and chip edges, at the lowest contrast that still
  /// reads as an edge.
  static const Color borderHairline = Color(0xFFE1E5E8);

  /// *Agua clara* (L* 88.31). The sole pastel that may carry text; the fill
  /// of the duration chip, the primary action and the selected size option.
  /// No glyph may ever sit inside it.
  static const Color accentSoft = Color(0xFFD5E0DC);
}

/// Icon-mass tier — every mass at L* 76.0, Δ L* 21.6 against
/// [FieldPalette.surfaceBase]. The colour plate inside a glyph, nowhere
/// else (UX-DR2).
abstract final class IconMassPalette {
  /// `Quedármelo` — first destination. Equal weight, never "the good one".
  static const Color destKeep = Color(0xFF9EC3B5);

  /// `Donar o vender` — second destination.
  static const Color destDonate = Color(0xFFBCB8D4);

  /// `Tirar o soltar` — third destination. A dusty rose, not an alarm.
  static const Color destTrash = Color(0xFFD9B2B6);

  /// Default mass of the utility glyphs (Cámara, Álbum, Reloj, Lápiz) and
  /// the microphone capsule at rest — no semantic hue.
  static const Color iconMassNeutral = Color(0xFFB3BEBA);

  /// The Hoja zone marker's mass — neither the neutral mass nor any
  /// destination hue.
  static const Color iconMassOchre = Color(0xFFCAB9A0);

  /// The system's active-state hue — the selected battery's charge and the
  /// dictating microphone's capsule. State, and state only.
  static const Color iconMassBlue = Color(0xFF9BC1D2);
}

/// Dark mode — separately authored, never an inversion (UX-DR12). The dark
/// mass tier sits at L* 62, chroma ~13. `border-strong-dark` is deliberately
/// absent: nothing needed a strong dark edge that [borderHairline] does not
/// cover.
abstract final class DarkPalette {
  static const Color surfaceBaseDark = Color(0xFF1B1E20);
  static const Color surfaceRaisedDark = Color(0xFF24282A);
  static const Color inkPrimaryDark = Color(0xFFECEAE4);
  static const Color inkSecondaryDark = Color(0xFF99A0A3);
  static const Color borderHairlineDark = Color(0xFF343A3D);
  static const Color accentSoftDark = Color(0xFF313E3B);
  static const Color iconMassNeutralDark = Color(0xFF8E9894);
  static const Color iconMassOchreDark = Color(0xFFA2947E);
  static const Color iconMassBlueDark = Color(0xFF7B9BA9);
  static const Color destKeepDark = Color(0xFF7E9C91);
  static const Color destDonateDark = Color(0xFF9793AA);
  static const Color destTrashDark = Color(0xFFAE8E91);
}

/// The two bundled variable faces (DESIGN.md Typography). Family names land
/// here once, with the roles that use them.
abstract final class FontFamilies {
  /// The serif — the task text's face, the one CONTENT role.
  static const String lora = 'Lora';

  /// The sans — every MECHANISM role's face, and the app default.
  static const String lexend = 'Lexend';
}

/// The eight typography roles (DESIGN.md Typography). Lora for the task text
/// only — the one CONTENT role; Lexend for every MECHANISM role. All sizes
/// are `sp`, all line-heights multipliers — never fixed dp — so the 200%
/// floor is met by growing (UX-DR45).
abstract final class TypeRoles {
  /// The task text — the only role set in Lora.
  static const TextStyle task = TextStyle(
    fontFamily: FontFamilies.lora,
    fontSize: 26,
    fontWeight: FontWeight.w500,
    height: 1.32,
    letterSpacing: 0,
    color: FieldPalette.inkPrimary,
  );

  /// The duration chip — ink-primary on accent-soft, above the task.
  static const TextStyle duration = TextStyle(
    fontFamily: FontFamilies.lexend,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.40,
    letterSpacing: 0.15, // 0.01em
    color: FieldPalette.inkPrimary,
  );

  /// `Hecho` — ink-primary on accent-soft. A single label that never wraps.
  static const TextStyle actionPrimary = TextStyle(
    fontFamily: FontFamilies.lexend,
    fontSize: 19,
    fontWeight: FontWeight.w600,
    height: 1.00,
    letterSpacing: 0.19, // 0.01em
    color: FieldPalette.inkPrimary,
  );

  /// `Otra más fácil / Ahora no` — text only, never ellipsized.
  static const TextStyle actionSecondary = TextStyle(
    fontFamily: FontFamilies.lexend,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.35,
    letterSpacing: 0.15, // 0.01em
    color: FieldPalette.inkSecondary,
  );

  /// Support copy and the quiet zone-marker label.
  static const TextStyle support = TextStyle(
    fontFamily: FontFamilies.lexend,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: 0.26, // 0.02em
    color: FieldPalette.inkSecondary,
  );

  /// Screen titles — a heading wraps, so its line-height is 1.25, never the
  /// button's 1.00.
  static const TextStyle screenHeading = TextStyle(
    fontFamily: FontFamilies.lexend,
    fontSize: 19,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: 0.19, // 0.01em
    color: FieldPalette.inkPrimary,
  );

  /// Dashboard figures — the weight the task and chip use, never the
  /// button's 600; a figure does not wrap.
  static const TextStyle metricNumeral = TextStyle(
    fontFamily: FontFamilies.lexend,
    fontSize: 19,
    fontWeight: FontWeight.w500,
    height: 1.15,
    letterSpacing: 0.19, // 0.01em
    color: FieldPalette.inkPrimary,
  );

  /// The 3-Destination labels — equal, prominent weight, borrowed from no
  /// button role.
  static const TextStyle destinationLabel = TextStyle(
    fontFamily: FontFamilies.lexend,
    fontSize: 19,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: 0.19, // 0.01em
    color: FieldPalette.inkPrimary,
  );
}

/// The three radii (DESIGN.md Shapes). Glyph corners are not governed by
/// these — the icon set draws with round caps and joins.
abstract final class Radii {
  /// The card, the primary action, the consent pair, photo frames at full
  /// size, every rectangular surface.
  static const double radiusDefault = 14;

  /// The pill of the two things that carry a quantity of time: the duration
  /// chip and the size options.
  static const double radiusFull = 9999;

  /// Photo frames at album-thumbnail size — a cut edge, not a small card.
  static const double radiusThumb = 4;
}

/// The spacing scale (DESIGN.md Layout & Spacing). The LAYOUT scale is
/// base 4dp; steps 4 · 8 · 12 · 16 · 24 · 32 · 48, nothing between,
/// nothing above 48 fixed. The glyph sizes below (`glyphDestination`,
/// `glyphDense`, `glyphZoneMarker`) are a separate fixed set — the glyph
/// half of the scale, not layout steps, and their values (36, 64) do not
/// obey the layout ladder. Touch-target height is a platform constant and
/// does not scale with font size.
///
/// The air around the dispenser card is deliberately NOT here: it is a
/// minimum plus flex (never a fixed value), carried on the card component,
/// because a token would be read as a fixed value.
abstract final class Spacing {
  /// The unit; every value below is a multiple of it.
  static const double spacingBase = 4;

  /// The duration chip sits tight under this — proximity is the mechanism.
  static const double chipToTask = 8;

  /// Interior horizontal inset of the duration chip.
  static const double chipPaddingHorizontal = 12;

  /// Interior vertical inset of the duration chip.
  static const double chipPaddingVertical = 4;

  /// Primary action down to the secondary.
  static const double actionGap = 12;

  /// Interior padding of the dispenser card.
  static const double cardPadding = 24;

  /// Card to the screen's left and right edges.
  static const double screenMargin = 24;

  /// Task text down to the first action — the largest interior gap, the
  /// pause between reading and committing.
  static const double taskToActions = 32;

  /// Between the three rows of the 3-Destination Flow.
  static const double destinationRowGap = 32;

  /// The floor for every tappable box; a platform constant.
  static const double touchTargetMin = 48;

  /// The 3-Destination Flow glyphs — a full-screen, one-decision surface.
  static const double glyphDestination = 64;

  /// The interface minimum for the seed glyph anywhere else.
  static const double glyphMin = 48;

  /// Only where density genuinely demands it — marginal for the seed.
  static const double glyphDense = 36;

  /// Only as a zone marker beside a word.
  static const double glyphZoneMarker = 24;

  /// Between the two plates of a Before/After pair.
  static const double photoPairGap = 16;
}

/// The two format rules (DESIGN.md formats), transcribed as patterns. Both
/// land on the densest screen in the app; the non-breaking spaces are
/// load-bearing at 200%.
abstract final class Formats {
  /// Day without leading zero + non-breaking space + three-letter lowercase
  /// Spanish month, no period, no year — `12 ago` · `4 ago` · `28 jul`.
  /// (intl `es` yields the lowercase abbreviated month for `MMM`.)
  static const String shortDateFormat = 'd\u00A0MMM';

  /// Value + non-breaking space + unit; units s / min / h; largest unit
  /// first; no leading zeros; en dash for a range — `30 s` · `3 min` ·
  /// `10–15 min` · `4 h 25 min`.
  static const String durationFormat = 'value\u00A0unit';
}

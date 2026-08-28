import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import 'show_colors.dart';

/// SHOW typography tokens.
///
/// Latin face: **Plus Jakarta Sans** (via google_fonts).
/// Myanmar face: TBD — [myanmarFontFamily] is the single seam to swap it in
/// once specified. When set, callers should apply it via [withMyanmar].
///
/// The scale is biased **larger than typical** because the audience is 40+:
/// body text defaults to 17px, and hierarchy is carried by size/weight rather
/// than boxes or color chips.
class ShowType {
  ShowType._();

  /// Set this once the Myanmar font is chosen & bundled.
  /// e.g. 'Padauk' or 'Noto Sans Myanmar'.
  static String? myanmarFontFamily;

  static TextStyle _base(double size, FontWeight weight,
      {double? height, double? spacing, Color? color}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: color ?? ShowColors.ink,
    );
  }

  // Display / headlines — Swiss style: tight, confident, left-aligned.
  // Scale trimmed a touch: long Burmese strings were overflowing at the old
  // (larger) sizes. Still comfortably legible for a 40+ audience.
  static TextStyle get display => _base(32, FontWeight.w700, height: 1.15, spacing: -0.3);
  static TextStyle get h1 => _base(25, FontWeight.w700, height: 1.2, spacing: -0.2);
  static TextStyle get h2 => _base(21, FontWeight.w600, height: 1.25);
  static TextStyle get h3 => _base(18, FontWeight.w600, height: 1.3);

  // Body — generous for legibility.
  static TextStyle get bodyLarge => _base(17, FontWeight.w400, height: 1.5);
  static TextStyle get body => _base(16, FontWeight.w400, height: 1.5);
  static TextStyle get bodyMuted =>
      _base(16, FontWeight.w400, height: 1.5, color: ShowColors.inkMuted);

  // Supporting.
  static TextStyle get label => _base(14, FontWeight.w600, spacing: 0.2);
  static TextStyle get caption =>
      _base(12, FontWeight.w400, color: ShowColors.inkFaint);

  // Buttons / controls.
  static TextStyle get button => _base(16, FontWeight.w600, spacing: 0.2);

  /// Returns [style] with the Myanmar family applied, if one has been set.
  static TextStyle withMyanmar(TextStyle style) {
    final fam = myanmarFontFamily;
    return fam == null ? style : style.copyWith(fontFamily: fam);
  }
}

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
  static TextStyle get display => _base(40, FontWeight.w700, height: 1.1, spacing: -0.5);
  static TextStyle get h1 => _base(30, FontWeight.w700, height: 1.15, spacing: -0.3);
  static TextStyle get h2 => _base(24, FontWeight.w600, height: 1.2);
  static TextStyle get h3 => _base(20, FontWeight.w600, height: 1.25);

  // Body — generous for legibility.
  static TextStyle get bodyLarge => _base(19, FontWeight.w400, height: 1.5);
  static TextStyle get body => _base(17, FontWeight.w400, height: 1.5);
  static TextStyle get bodyMuted =>
      _base(17, FontWeight.w400, height: 1.5, color: ShowColors.inkMuted);

  // Supporting.
  static TextStyle get label => _base(15, FontWeight.w600, spacing: 0.2);
  static TextStyle get caption =>
      _base(13, FontWeight.w400, color: ShowColors.inkFaint);

  // Buttons / controls.
  static TextStyle get button => _base(17, FontWeight.w600, spacing: 0.2);

  /// Returns [style] with the Myanmar family applied, if one has been set.
  static TextStyle withMyanmar(TextStyle style) {
    final fam = myanmarFontFamily;
    return fam == null ? style : style.copyWith(fontFamily: fam);
  }
}

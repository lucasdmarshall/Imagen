import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import 'show_colors.dart';

/// SHOW typography tokens.
///
/// Latin face: **Plus Jakarta Sans** (via google_fonts).
/// Myanmar face: bundled [myanmarFontFamily] (Noto Sans Myanmar). It is the
/// primary family so CanvasKit shapes Burmese; Latin codepoints fall back to
/// Plus Jakarta because the Myanmar file is a script subset (no ASCII).
///
/// Do not use NamKhoneUnicode here — that face stores shaping in private
/// `zz##` Graphite-era features HarfBuzz never applies, which shows dotted
/// circles on kinzi / asat / medials.
///
/// The scale is biased **larger than typical** because the audience is 40+:
/// body text defaults to 17px, and hierarchy is carried by size/weight rather
/// than boxes or color chips.
class ShowType {
  ShowType._();

  /// Set this once the Myanmar font is chosen & bundled.
  /// e.g. 'NotoSansMyanmar' or 'Padauk'.
  static String? myanmarFontFamily;

  static TextStyle _base(double size, FontWeight weight,
      {double? height, double? spacing, Color? color}) {
    final latin = GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      height: height,
      // Never default-track: letter-spacing splits Myanmar clusters.
      letterSpacing: spacing ?? 0,
      color: color ?? ShowColors.ink,
    );
    final mm = myanmarFontFamily;
    if (mm == null) return latin;
    return latin.copyWith(
      fontFamily: mm,
      fontFamilyFallback: [
        if (latin.fontFamily != null) latin.fontFamily!,
        ...?latin.fontFamilyFallback,
      ],
    );
  }

  // Display / headlines — Swiss style: tight, confident, left-aligned.
  // Scale trimmed a touch: long Burmese strings were overflowing at the old
  // (larger) sizes. Still comfortably legible for a 40+ audience.
  static TextStyle get display => _base(32, FontWeight.w700, height: 1.15);
  static TextStyle get h1 => _base(25, FontWeight.w700, height: 1.2);
  static TextStyle get h2 => _base(21, FontWeight.w600, height: 1.25);
  static TextStyle get h3 => _base(18, FontWeight.w600, height: 1.3);

  // Body — generous for legibility.
  static TextStyle get bodyLarge => _base(17, FontWeight.w400, height: 1.5);
  static TextStyle get body => _base(16, FontWeight.w400, height: 1.5);
  static TextStyle get bodyMuted =>
      _base(16, FontWeight.w400, height: 1.5, color: ShowColors.inkMuted);

  // Supporting.
  static TextStyle get label => _base(14, FontWeight.w600);
  static TextStyle get caption =>
      _base(12, FontWeight.w400, color: ShowColors.inkFaint);

  // Buttons / controls.
  static TextStyle get button => _base(16, FontWeight.w600);

  /// Returns [style] with the Myanmar family as primary, if one has been set.
  ///
  /// Letter-spacing is cleared: even 0.2px splits kinzi / asat clusters.
  static TextStyle withMyanmar(TextStyle style) {
    final fam = myanmarFontFamily;
    if (fam == null) return style.copyWith(letterSpacing: 0);
    return style.copyWith(
      fontFamily: fam,
      fontFamilyFallback: [
        if (style.fontFamily != null && style.fontFamily != fam) style.fontFamily!,
        ...?style.fontFamilyFallback,
      ],
      letterSpacing: 0,
    );
  }
}

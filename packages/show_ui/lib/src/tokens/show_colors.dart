import 'package:flutter/widgets.dart';

/// SHOW color tokens.
///
/// Rules (see PROJECT_OVERVIEW.md §3):
/// - **No gradients.** Every value here is a single flat, matte color.
/// - Greys & black are matte (no gloss).
/// - "White" surfaces are a warm, cream-ish white — never pure #FFFFFF.
/// - Accent colors are allowed but stay flat and muted.
class ShowColors {
  ShowColors._();

  // --- Warm / cream neutrals (surfaces) ---
  /// Primary app background — warm cream, not pure white.
  static const Color cream = Color(0xFFF6F4EE);

  /// Slightly raised surface (still borderless — differentiated by tone only).
  static const Color creamRaised = Color(0xFFFBFAF5);

  /// Sunken / inset tone.
  static const Color creamSunken = Color(0xFFEDEAE1);

  // --- Matte inks (text / near-black) ---
  /// Primary text — matte off-black (never pure #000000).
  static const Color ink = Color(0xFF1C1B19);

  /// Secondary text.
  static const Color inkMuted = Color(0xFF57534E);

  /// Tertiary / hint text.
  static const Color inkFaint = Color(0xFF8A857D);

  // --- Matte grey scale ---
  static const Color grey900 = Color(0xFF262523);
  static const Color grey700 = Color(0xFF4A4844);
  static const Color grey500 = Color(0xFF6E6A63);
  static const Color grey300 = Color(0xFFB7B2A8);
  static const Color grey200 = Color(0xFFD6D2C8);
  static const Color grey100 = Color(0xFFE6E3DA);

  /// Hairline rule — the *only* line the borderless design permits, used
  /// sparingly as a divider, never as a container outline.
  static const Color hairline = Color(0xFFDAD6CC);

  // --- Accent (flat, matte) ---
  /// Primary accent — muted slate blue.
  static const Color accent = Color(0xFF395A73);
  static const Color accentPressed = Color(0xFF2C4859);

  // --- Semantic (flat) ---
  static const Color success = Color(0xFF3F6B4E);
  static const Color warning = Color(0xFF9A6B2E);
  static const Color danger = Color(0xFF9A3B34);

  // --- Dark mode neutrals (matte, warm-leaning) ---
  static const Color darkBg = Color(0xFF171614);
  static const Color darkRaised = Color(0xFF201F1C);
  static const Color darkInk = Color(0xFFEFEBE2);
  static const Color darkInkMuted = Color(0xFFB0ABA1);
  static const Color darkHairline = Color(0xFF35332F);
}

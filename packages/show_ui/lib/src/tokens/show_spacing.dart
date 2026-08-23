/// SHOW spacing & sizing tokens.
///
/// Hierarchy in this design comes from **whitespace and alignment**, not
/// borders or cards — so spacing is a first-class token set. Scale is a
/// consistent 4pt grid, biased slightly larger for the 40+ audience.
class ShowSpacing {
  ShowSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Standard horizontal page inset.
  static const double pageInset = 24;

  /// Grid gutter for the Swiss alignment grid.
  static const double gutter = 16;
}

/// Minimum interactive sizes — enlarged for older users (see UX principles).
class ShowSizing {
  ShowSizing._();

  /// Minimum tap target (Material asks 48; we use 56 for comfort).
  static const double minTouch = 56;

  /// Standard control height (buttons, list rows, fields).
  static const double controlHeight = 56;

  /// Hairline thickness for the rare divider.
  static const double hairline = 1;

  /// Max readable content width on wide/web layouts.
  static const double maxContentWidth = 720;
}

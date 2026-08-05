/// Spacing & radius scale (8pt system). Keeps layouts consistent across screens.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Corner radii
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 20;
  static const double radiusPill = 999;

  // Touch targets (UI/UX Brief §5 — ≥48dp, ≥64dp on alarm screen)
  static const double touchTarget = 48;
  static const double alarmTouchTarget = 64;

  // Screen edge padding
  static const double screenPadding = 20;
}

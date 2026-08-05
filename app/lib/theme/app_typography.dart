import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography — rounded, highly legible geometric sans (Poppins) per UI/UX
/// Brief §2.2. Distance/ETA numerals use tabular figures for at-a-glance
/// reading; alarm text scales up for drowsy readability.
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(TextTheme base) {
    return GoogleFonts.poppinsTextTheme(base).copyWith(
      displayLarge: GoogleFonts.poppins(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.1,
      ),
      headlineLarge: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      // Minimum body text size 16sp (UI/UX Brief §2.2)
      bodyLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.4,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelMedium: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    );
  }

  /// Large tabular-figure numerals for the tracking screen (distance / ETA).
  static TextStyle statNumeral({double fontSize = 48}) => GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Alarm-screen headline — minimum 24sp, high contrast on gradient.
  static TextStyle alarmHeadline() => GoogleFonts.poppins(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        height: 1.1,
      );
}

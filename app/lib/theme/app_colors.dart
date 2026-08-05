import 'package:flutter/material.dart';

/// WakeMate color palette — see UI/UX Brief §2.1.
/// Calm, modern, travel-forward. Navy + Teal core, Amber–Red reserved for the
/// alarm screen only.
class AppColors {
  AppColors._();

  // Core brand
  static const Color primary = Color(0xFF1B2A4A); // Deep Navy Blue
  static const Color accent = Color(0xFF0F7C82); // Teal — actions, active states
  static const Color success = Color(0xFF2E9E5B); // Green — arrival, success

  // Alarm — high-urgency gradient, alarm screen ONLY
  static const Color alarmStart = Color(0xFFF6A623); // Warm amber
  static const Color alarmEnd = Color(0xFFD0342C); // Red
  static const LinearGradient alarmGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [alarmStart, alarmEnd],
  );

  // Surfaces
  static const Color background = Color(0xFFF7F8FA); // Off-white / light grey
  static const Color surface = Color(0xFFFFFFFF); // Cards, sheets, modals

  // Text
  static const Color textPrimary = Color(0xFF1B2A4A);
  static const Color textSecondary = Color(0xFF5B6577);
  static const Color textOnAccent = Color(0xFFFFFFFF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Utility
  static const Color border = Color(0xFFE2E5EB);
  static const Color divider = Color(0xFFEDEFF3);
  static const Color disabled = Color(0xFFB4BAC6);
  static const Color warning = Color(0xFFE08A00); // Battery-optimization warnings
  static const Color danger = Color(0xFFD0342C); // Cancel / destructive
  static const Color accentSoft = Color(0xFFE0F0F1); // Teal tint for chips/fills
}

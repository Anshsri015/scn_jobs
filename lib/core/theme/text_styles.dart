import 'package:flutter/material.dart';

/// Centralized text styles for SCN Jobs.
///
/// Sizes are deliberately larger than typical Material defaults because
/// the audience (semi-skilled, entry-level workers) skews toward older
/// age groups and low-end devices with default system font scaling
/// already high. Minimum body size is 16sp; nothing user-facing goes
/// below that.
class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Roboto';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Absolute minimum size for any user-facing text in this app.
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  /// Full [TextTheme] handed to [ThemeData] so every default Material
  /// widget (AppBar title, ListTile, etc.) inherits the accessible sizing
  /// without each screen re-specifying styles.
  static const TextTheme textTheme = TextTheme(
    displayLarge: displayLarge,
    headlineMedium: headline,
    titleLarge: title,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    labelLarge: button,
    bodySmall: caption,
  );
}

// WHY THIS FILE
// Splitting text styles out of the theme file keeps ThemeData focused on
// color/shape while typography — the thing that most affects readability
// for our low-digital-literacy audience — lives somewhere obviously
// discoverable and testable in isolation.
// Alternative considered: inlining TextStyle literals per-screen.
// Rejected — guarantees inconsistent sizing within two weeks of a team
// growing past one developer.
// Pitfall a junior would hit: setting body text below 16sp because it
// "looks fine" on a large emulator, then failing the accessibility
// contrast/size audit in Section 14 of the plan on a real low-end device.

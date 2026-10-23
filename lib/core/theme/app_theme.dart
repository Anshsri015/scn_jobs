import 'package:flutter/material.dart';

// Fonts are bundled as local assets (see pubspec.yaml `fonts:` section)
// instead of google_fonts, which fetches over the network on first
// launch and leaves the cold-start screen showing fallback type on a
// slow connection.
const _kPoppins = 'Poppins';
const _kInter = 'Inter';

/// Brand palette: deep navy (trust, professional — the "employer/job"
/// side) + warm orange (action/CTA — the "apply now" energy). Chosen to
/// read like a real job-marketplace app (Naukri/Indeed direction)
/// instead of a generic Material default-blue app.
class AppTheme {
  AppTheme._();

  static const navy = Color(0xFF0B3B6F);
  static const orange = Color(0xFFFF7A1A);
  static const bg = Color(0xFFF6F7FB);
  static const errorRed = Color(0xFFD84C3E);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      primary: navy,
      secondary: orange,
      error: errorRed,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: _textTheme(scheme.onSurface, scheme.onSurfaceVariant),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: _kPoppins,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ).copyWith(color: scheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: navy, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: _kPoppins,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: navy,
          textStyle: const TextStyle(
            fontFamily: _kPoppins,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.dark,
      secondary: orange,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: _textTheme(scheme.onSurface, scheme.onSurfaceVariant),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      headlineSmall: TextStyle(
        fontFamily: _kPoppins,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontFamily: _kPoppins,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontFamily: _kPoppins,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: TextStyle(fontFamily: _kInter, fontSize: 15, color: primary),
      bodyMedium: TextStyle(
        fontFamily: _kInter,
        fontSize: 14,
        color: secondary,
      ),
      labelLarge: const TextStyle(
        fontFamily: _kPoppins,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

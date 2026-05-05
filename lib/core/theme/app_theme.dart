import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// iOS Human Interface Guidelines-inspired theme.
/// Clean, minimal, light — feels like a native Apple application.
class AppTheme {
  // ── iOS Color System ──────────────────────────────────────────────────────
  // Backgrounds (iOS grouped / inset grouped)
  static const Color bg0 = Color(0xFFF2F2F7);   // iOS systemGroupedBackground
  static const Color bg1 = Color(0xFFEFEFF4);   // iOS secondarySystemGroupedBackground
  static const Color bg2 = Color(0xFFFFFFFF);   // iOS systemBackground (cards)
  static const Color bg3 = Color(0xFFE5E5EA);   // iOS separator / elevated

  // Primary — indigo, used sparingly
  static const Color primary   = Color(0xFF4F46E5);
  static const Color secondary = Color(0xFF6366F1);
  static const Color accent    = Color(0xFF4F46E5);
  static const Color accentAlt = Color(0xFF818CF8);

  // iOS-style text hierarchy
  static const Color textPrimary   = Color(0xFF000000);   // iOS label
  static const Color textSecondary = Color(0xFF3C3C43);   // iOS secondaryLabel (60% opacity)
  static const Color textMuted     = Color(0xFF8E8E93);   // iOS tertiaryLabel
  static const Color textQuaternary = Color(0xFFC7C7CC);  // iOS quaternaryLabel

  // iOS system colors
  static const Color border    = Color(0xFFE5E7EB);
  static const Color separator = Color(0xFFC6C6C8);       // iOS separator
  static const Color fill      = Color(0xFFEFEFF4);       // iOS systemFill
  static const Color success   = Color(0xFF34C759);       // iOS systemGreen
  static const Color warning   = Color(0xFFFF9500);       // iOS systemOrange
  static const Color error     = Color(0xFFFF3B30);       // iOS systemRed
  static const Color blue      = Color(0xFF007AFF);       // iOS systemBlue

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFFF2F2F7), Color(0xFFEFEFF4)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Shadows — very subtle, iOS-style ─────────────────────────────────────
  static List<BoxShadow> get primaryGlow => [
        BoxShadow(
          color: primary.withOpacity(0.22),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get subtleShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  // ── Card decoration — iOS inset grouped style ─────────────────────────────
  static BoxDecoration glassCard({
    double radius = 12,
    Color? borderColor,
    bool subtle = false,
  }) =>
      BoxDecoration(
        color: bg2,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: subtle ? subtleShadow : cardShadow,
      );

  // iOS inset grouped section (no border, just shadow)
  static BoxDecoration iosCard({double radius = 12}) => BoxDecoration(
        color: bg2,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: subtleShadow,
      );

  // ── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: bg0,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: bg2,
        error: error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
      cardTheme: CardThemeData(
        color: bg2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg2,
        hintStyle: const TextStyle(color: textMuted, fontSize: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textTheme: const TextTheme(
        // iOS Large Title
        displayLarge: TextStyle(
            fontSize: 34, fontWeight: FontWeight.w700,
            color: textPrimary, letterSpacing: -0.5),
        // iOS Title 1
        displayMedium: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w700,
            color: textPrimary, letterSpacing: -0.3),
        // iOS Title 2
        headlineMedium: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w700,
            color: textPrimary, letterSpacing: -0.2),
        // iOS Title 3
        headlineSmall: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600,
            color: textPrimary, letterSpacing: -0.2),
        // iOS Headline
        titleLarge: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w600,
            color: textPrimary, letterSpacing: -0.2),
        // iOS Body
        bodyLarge: TextStyle(fontSize: 17, color: textPrimary, letterSpacing: -0.2),
        // iOS Callout
        bodyMedium: TextStyle(fontSize: 16, color: textSecondary, letterSpacing: -0.2),
        // iOS Subheadline
        bodySmall: TextStyle(fontSize: 15, color: textMuted, letterSpacing: -0.1),
        // iOS Caption
        labelSmall: TextStyle(fontSize: 12, color: textMuted, letterSpacing: 0),
      ),
      dividerTheme: const DividerThemeData(
        color: separator,
        thickness: 0.5,
        indent: 16,
        endIndent: 0,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 8,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? success : bg3,
        ),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}

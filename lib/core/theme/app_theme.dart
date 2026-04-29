import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ── Light Palette ─────────────────────────────────────────────────────────
  static const Color bg0 = Color(0xFFF8FAFC); // page background
  static const Color bg1 = Color(0xFFF1F5F9); // secondary bg / sheets
  static const Color bg2 = Color(0xFFFFFFFF); // card surface
  static const Color bg3 = Color(0xFFE2E8F0); // elevated / border

  static const Color primary   = Color(0xFF4F46E5); // indigo accent
  static const Color secondary = Color(0xFF6366F1); // lighter indigo
  static const Color accent    = Color(0xFF4F46E5);
  static const Color accentAlt = Color(0xFF818CF8);

  static const Color textPrimary   = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF374151);
  static const Color textMuted     = Color(0xFF6B7280);

  static const Color border    = Color(0xFFE5E7EB);
  static const Color success   = Color(0xFF10B981);
  static const Color warning   = Color(0xFFF59E0B);
  static const Color error     = Color(0xFFEF4444);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Shadows ───────────────────────────────────────────────────────────────
  static List<BoxShadow> get primaryGlow => [
        BoxShadow(
          color: primary.withOpacity(0.25),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  // ── Card decoration ───────────────────────────────────────────────────────
  static BoxDecoration glassCard({
    double radius = 16,
    Color? borderColor,
  }) =>
      BoxDecoration(
        color: bg2,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? border,
          width: 1,
        ),
        boxShadow: cardShadow,
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
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: bg2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
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
        fillColor: bg1,
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 30, fontWeight: FontWeight.w700, color: textPrimary),
        displayMedium: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
        headlineMedium: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        headlineSmall: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 15, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 13, color: textSecondary),
        bodySmall: TextStyle(fontSize: 11, color: textMuted),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primary.withOpacity(0.4)
              : bg3,
        ),
      ),
    );
  }

  // Keep darkTheme for compatibility
  static ThemeData get darkTheme => lightTheme;
}

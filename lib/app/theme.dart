import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ═══════════════════════════════════════════════════════════════
/// Artisan Lane — African Craft Market Theme
///
/// Palette extracted from the Artisan Lane logo: the crimson red
/// of the potter's hand, the forest green of growth, the gold of
/// the zigzag band, and the warm mahogany of the clay pot.
/// ═══════════════════════════════════════════════════════════════
class AppTheme {
  AppTheme._();

  // ── Brand Palette (from logo) ─────────────────────────────────
  static const Color terracotta = Color(0xFF7A0000);    // primary – Burgundy
  static const Color ochre = Color(0xFFD4A020);         // warm gold from pot zigzag band
  static const Color indigo = Color(0xFF3E2215);        // deep mahogany (pot neck/dark)
  static const Color baobab = Color(0xFF559826);        // forest green (logo hand)
  static const Color sienna = Color(0xFF8B4513);        // pot body brown
  static const Color bone = Color(0xFFF7E4CC);          // warm cream (logo background)
  static const Color clay = Color(0xFFEDD5BE);          // light clay
  static const Color sand = Color(0xFFDFC4AD);          // warm sand

  // Convenience aliases so the rest of the app keeps compiling
  static const Color primary = terracotta;
  static const Color primaryLight = Color(0xFF990000);
  static const Color primaryDark = Color(0xFF4A0000);
  static const Color secondary = baobab;
  static const Color secondaryLight = Color(0xFF6EAD3F);
  static const Color accent = ochre;
  static const Color error = Color(0xFFB71C1C);
  static const Color success = baobab;
  static const Color warning = ochre;

  // ── Neutrals ─────────────────────────────────────────────────
  static const Color scaffoldBg = Color(0xFFFDF5EC);   // warm cream parchment
  static const Color cardBg = Color(0xFFFFFBF5);        // warm white
  static const Color surfaceColor = bone; // very light grey for contrast if needed
  static const Color textPrimary = Color(0xFF3A1F10);   // dark mahogany
  static const Color textSecondary = Color(0xFF6B5040); // warm brown-grey
  static const Color textHint = Color(0xFF9C8670);      // faded earth
  static const Color dividerColor = clay;
  static const Color borderColor = sand;

  // ── Status Colors ────────────────────────────────────────────
  static const Color statusPending = ochre;
  static const Color statusPaid = Color(0xFF42A5F5);
  static const Color statusShipped = Color(0xFF7E57C2);
  static const Color statusDelivered = baobab;
  static const Color statusCompleted = Color(0xFF2D6A4F);
  static const Color statusDisputed = error;
  static const Color statusCancelled = Color(0xFF9E9E9E);

  static Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return statusPending;
      case 'paid':
        return statusPaid;
      case 'shipped':
        return statusShipped;
      case 'delivered':
        return statusDelivered;
      case 'completed':
        return statusCompleted;
      case 'disputed':
        return statusDisputed;
      case 'cancelled':
        return statusCancelled;
      default:
        return textSecondary;
    }
  }

  // ── Typography ───────────────────────────────────────────────
  // Display / headlines: Playfair Display – elegant serif, artisan feel
  // Body / UI: Poppins – clean, modern readability
  static TextStyle get displayFont => GoogleFonts.playfairDisplay();
  static TextStyle get bodyFont => GoogleFonts.poppins();

  static TextTheme _textTheme() {
    return TextTheme(
      // Display – Playfair Display (the "artisan" voice)
      displayLarge: GoogleFonts.playfairDisplay(
        fontSize: 34, fontWeight: FontWeight.w700, color: textPrimary,
      ),
      displayMedium: GoogleFonts.playfairDisplay(
        fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary,
      ),
      displaySmall: GoogleFonts.playfairDisplay(
        fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary,
      ),
      // Headlines – Playfair Display
      headlineLarge: GoogleFonts.playfairDisplay(
        fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary,
      ),
      headlineSmall: GoogleFonts.playfairDisplay(
        fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary,
      ),
      // Titles – Poppins (UI elements)
      titleLarge: GoogleFonts.poppins(
        fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary,
      ),
      titleSmall: GoogleFonts.poppins(
        fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary,
      ),
      // Body – Poppins
      bodyLarge: GoogleFonts.poppins(
        fontSize: 16, fontWeight: FontWeight.normal, color: textPrimary,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 14, fontWeight: FontWeight.normal, color: textPrimary,
      ),
      bodySmall: GoogleFonts.poppins(
        fontSize: 12, fontWeight: FontWeight.normal, color: textSecondary,
      ),
      // Labels – Poppins
      labelLarge: GoogleFonts.poppins(
        fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white,
      ),
      labelMedium: GoogleFonts.poppins(
        fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary,
      ),
      labelSmall: GoogleFonts.poppins(
        fontSize: 10, fontWeight: FontWeight.w500, color: textHint,
      ),
    );
  }

  // ── Light Theme ──────────────────────────────────────────────
  static ThemeData get lightTheme {
    final textTheme = _textTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primaryLight.withValues(alpha: 0.15),
        secondary: secondary,
        onSecondary: Colors.white,
        secondaryContainer: secondaryLight.withValues(alpha: 0.15),
        tertiary: accent,
        error: error,
        surface: cardBg,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: scaffoldBg,
        foregroundColor: textPrimary,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: dividerColor, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: terracotta,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: terracotta,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: terracotta),
          textStyle: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: terracotta,
          textStyle: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bone,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: sand, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: terracotta, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 1),
        ),
        hintStyle: GoogleFonts.poppins(color: textHint, fontSize: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bone,
        selectedColor: terracotta.withValues(alpha: 0.15),
        labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: sand, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardBg,
        selectedItemColor: terracotta,
        unselectedItemColor: textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.normal,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: clay,
        thickness: 0.5,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}

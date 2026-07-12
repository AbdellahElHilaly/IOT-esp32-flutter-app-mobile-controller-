import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LuminaTheme {
  static const Color primaryColor = Color(0xFF00677D);
  static const Color primaryContainerColor = Color(0xFF00B4D8);
  static const Color secondaryColor = Color(0xFF006D37);
  static const Color secondaryContainerColor = Color(0xFF6BFE9C);
  static const Color tertiaryColor = Color(0xFF006590);
  static const Color tertiaryContainerColor = Color(0xFF55AEE4);
  
  static const Color backgroundColor = Color(0xFFF5FAFD);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color onSurfaceColor = Color(0xFF171C1F);
  static const Color onSurfaceVariantColor = Color(0xFF3D494D);
  static const Color outlineColor = Color(0xFF6D797E);
  static const Color outlineVariantColor = Color(0xFFBCC9CE);
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primaryColor,
        onPrimary: Colors.white,
        primaryContainer: primaryContainerColor,
        onPrimaryContainer: Color(0xFF00414F),
        secondary: secondaryColor,
        onSecondary: Colors.white,
        secondaryContainer: secondaryContainerColor,
        onSecondaryContainer: Color(0xFF00743A),
        tertiary: tertiaryColor,
        onTertiary: Colors.white,
        tertiaryContainer: tertiaryContainerColor,
        onTertiaryContainer: Color(0xFF003F5C),
        error: Color(0xFFBA1A1A),
        onError: Colors.white,
        surface: backgroundColor,
        onSurface: onSurfaceColor,
        onSurfaceVariant: onSurfaceVariantColor,
        outline: outlineColor,
        outlineVariant: outlineVariantColor,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.manrope(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.02,
          color: primaryColor,
        ),
        headlineLarge: GoogleFonts.manrope(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.01,
          color: onSurfaceColor,
        ),
        titleMedium: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: onSurfaceColor,
        ),
        bodyLarge: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariantColor,
        ),
        bodyMedium: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariantColor,
        ),
        labelSmall: GoogleFonts.hankenGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05,
          color: outlineColor,
        ),
      ),
    );
  }
}

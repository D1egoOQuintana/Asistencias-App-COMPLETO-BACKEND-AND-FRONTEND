import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema de diseño centralizado para toda la aplicación
/// Basado en Material Design 3 con paleta personalizada
class AppDesignSystem {
  /// Familia tipográfica global (Manrope), igual que el textTheme del tema.
  static final String? fontFamily = GoogleFonts.manrope().fontFamily;
  // ============================================================================
  // PALETA DE COLORES - Material Design 3
  // ============================================================================

  static const Color primaryColor = Color(0xFF1976D2); // Blue 700
  static const Color primaryLight = Color(0xFF42A5F5); // Blue 400
  static const Color primaryDark = Color(0xFF0D47A1); // Blue 900

  static const Color secondaryColor = Color(0xFF00897B); // Teal 600
  static const Color secondaryLight = Color(0xFF4DB6AC); // Teal 300
  static const Color secondaryDark = Color(0xFF00695C); // Teal 800

  static const Color accentColor = Color(0xFFFF6F00); // Orange 900
  static const Color accentLight = Color(0xFFFF9800); // Orange 500

  static const Color successColor = Color(0xFF2E7D32); // Green 800
  static const Color successLight = Color(0xFF4CAF50); // Green 500

  static const Color warningColor = Color(0xFFF57C00); // Orange 700
  static const Color warningLight = Color(0xFFFFB74D); // Orange 300

  static const Color errorColor = Color(0xFFC62828); // Red 800
  static const Color errorLight = Color(0xFFEF5350); // Red 400

  static const Color infoColor = Color(0xFF1565C0); // Blue 800
  static const Color infoLight = Color(0xFF42A5F5); // Blue 400

  // Colores de superficie
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color backgroundDark = Color(0xFFE8EAF0);

  // Colores de texto
  static const Color textPrimary = Color(0xFF212121); // Grey 900
  static const Color textSecondary = Color(0xFF757575); // Grey 600
  static const Color textDisabled = Color(0xFFBDBDBD); // Grey 400
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Colores de bordes y divisores
  static const Color borderColor = Color(0xFFE0E0E0); // Grey 300
  static const Color dividerColor = Color(0xFFBDBDBD); // Grey 400

  // ============================================================================
  // RESPONSIVE BREAKPOINTS
  // ============================================================================

  static const double breakpointMobile = 600;
  static const double breakpointTablet = 900;
  static const double breakpointDesktop = 1200;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < breakpointMobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= breakpointMobile && width < breakpointTablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= breakpointDesktop;

  static bool isSmallScreen(BuildContext context) =>
      MediaQuery.of(context).size.width < 400;

  // ============================================================================
  // ESPACIADOS ADAPTABLES (basados en % de pantalla o escala)
  // ============================================================================

  static double spacing(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (width < breakpointMobile) return baseSize * 0.8;
    if (width < breakpointTablet) return baseSize;
    return baseSize * 1.2;
  }

  static const double spaceXS = 4;
  static const double spaceSM = 8;
  static const double spaceMD = 16;
  static const double spaceLG = 24;
  static const double spaceXL = 32;
  static const double space2XL = 48;

  static double getSpaceXS(BuildContext context) => spacing(context, spaceXS);
  static double getSpaceSM(BuildContext context) => spacing(context, spaceSM);
  static double getSpaceMD(BuildContext context) => spacing(context, spaceMD);
  static double getSpaceLG(BuildContext context) => spacing(context, spaceLG);
  static double getSpaceXL(BuildContext context) => spacing(context, spaceXL);
  static double getSpace2XL(BuildContext context) => spacing(context, space2XL);

  // Padding adaptable
  static EdgeInsets paddingAll(BuildContext context, double baseSize) {
    return EdgeInsets.all(spacing(context, baseSize));
  }

  static EdgeInsets paddingSymmetric(
    BuildContext context, {
    double horizontal = 0,
    double vertical = 0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: spacing(context, horizontal),
      vertical: spacing(context, vertical),
    );
  }

  // ============================================================================
  // TIPOGRAFÍA ESCALABLE
  // ============================================================================

  static double getFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return baseSize * 0.85; // Pantallas muy pequeñas
    if (width < breakpointMobile) return baseSize * 0.9;
    if (width < breakpointTablet) return baseSize;
    return baseSize * 1.1;
  }

  static TextStyle displayLarge(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: getFontSize(context, 32),
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle displayMedium(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: getFontSize(context, 28),
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  static TextStyle headlineLarge(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: getFontSize(context, 24),
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static TextStyle headlineMedium(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: getFontSize(context, 20),
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static TextStyle titleLarge(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: getFontSize(context, 18),
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static TextStyle titleMedium(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: getFontSize(context, 16),
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  static TextStyle bodyLarge(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: getFontSize(context, 16),
    color: textPrimary,
  );

  static TextStyle bodyMedium(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: getFontSize(context, 14),
    color: textPrimary,
  );

  static TextStyle bodySmall(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: getFontSize(context, 12),
    color: textSecondary,
  );

  static TextStyle labelLarge(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: getFontSize(context, 14),
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  static TextStyle labelMedium(BuildContext context) => TextStyle(
    fontFamily: fontFamily,
    fontSize: getFontSize(context, 12),
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  // ============================================================================
  // BORDER RADIUS
  // ============================================================================

  static const double radiusXS = 4;
  static const double radiusSM = 8;
  static const double radiusMD = 12;
  static const double radiusLG = 16;
  static const double radiusXL = 24;
  static const double radiusFull = 999;

  static BorderRadius borderRadiusXS = BorderRadius.circular(radiusXS);
  static BorderRadius borderRadiusSM = BorderRadius.circular(radiusSM);
  static BorderRadius borderRadiusMD = BorderRadius.circular(radiusMD);
  static BorderRadius borderRadiusLG = BorderRadius.circular(radiusLG);
  static BorderRadius borderRadiusXL = BorderRadius.circular(radiusXL);
  static BorderRadius borderRadiusFull = BorderRadius.circular(radiusFull);

  // ============================================================================
  // ELEVACIONES Y SOMBRAS
  // ============================================================================

  static const double elevationNone = 0;
  static const double elevationSM = 2;
  static const double elevationMD = 4;
  static const double elevationLG = 8;
  static const double elevationXL = 16;

  static BoxShadow getShadowSM({Color? color}) => BoxShadow(
    color: (color ?? Colors.black).withValues(alpha: 0.08),
    blurRadius: 4,
    offset: const Offset(0, 2),
  );

  static BoxShadow getShadowMD({Color? color}) => BoxShadow(
    color: (color ?? Colors.black).withValues(alpha: 0.1),
    blurRadius: 8,
    offset: const Offset(0, 4),
  );

  static BoxShadow getShadowLG({Color? color}) => BoxShadow(
    color: (color ?? Colors.black).withValues(alpha: 0.12),
    blurRadius: 16,
    offset: const Offset(0, 8),
  );

  // ============================================================================
  // GRID ADAPTABLE
  // ============================================================================

  static int getCrossAxisCount(BuildContext context, {int? forceCount}) {
    if (forceCount != null) return forceCount;
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 1;
    if (width < 900) return 2;
    if (width < 1200) return 3;
    return 4;
  }

  static double getChildAspectRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 1.4; // Mobile: más ancho
    if (width < 900) return 1.2; // Tablet
    return 1.3; // Desktop
  }

  // ============================================================================
  // DURATIONS Y CURVES
  // ============================================================================

  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);

  static const Curve curveStandard = Curves.easeInOutCubic;
  static const Curve curveEnter = Curves.easeOut;
  static const Curve curveExit = Curves.easeIn;
  static const Curve curveSnappy = Curves.fastOutSlowIn;

  // ============================================================================
  // UTILIDADES
  // ============================================================================

  /// Obtener color de estado con opacidad
  static Color getStatusColor(bool isActive, {bool light = false}) {
    if (isActive) {
      return light ? successLight : successColor;
    }
    return light ? errorLight : errorColor;
  }

  /// Construir gradiente de fondo
  static LinearGradient getBackgroundGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [backgroundLight, surfaceColor],
    );
  }

  /// Construir gradiente de card
  static LinearGradient getCardGradient(Color color) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
    );
  }
}

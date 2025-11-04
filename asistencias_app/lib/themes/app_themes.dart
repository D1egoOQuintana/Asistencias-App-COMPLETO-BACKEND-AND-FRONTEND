import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// Themes personalizados para cada rol de usuario
/// Docente: Celeste medio oscuro
/// Admin: Gris elegante
class AppThemes {
  // Colores para Docente
  static const Color _docentePrimary = Color(
    0xFF1976D2,
  ); // Celeste medio oscuro
  static const Color _docenteSecondary = Color(0xFF42A5F5);

  // Colores para Admin
  static const Color _adminPrimary = Color(0xFF424242); // Gris oscuro
  static const Color _adminSecondary = Color(0xFF757575);

  /// Theme para Docente - Celeste medio oscuro
  static ThemeData get docenteTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _docentePrimary,
        brightness: Brightness.light,
        primary: _docentePrimary,
        secondary: _docenteSecondary,
        surface: const Color(0xFFF5F5F5),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _docentePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _docentePrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _docenteSecondary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _docentePrimary, width: 2),
        ),
      ),
    );
  }

  /// Theme para Admin - Gris elegante
  static ThemeData get adminTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _adminPrimary,
        brightness: Brightness.light,
        primary: _adminPrimary,
        secondary: _adminSecondary,
        surface: const Color(0xFFF5F5F5),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _adminPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _adminPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _adminSecondary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _adminPrimary, width: 2),
        ),
      ),
    );
  }

  /// Obtener theme según el rol
  static ThemeData getThemeForRole(UserRole role) {
    switch (role) {
      case UserRole.docente:
        return docenteTheme;
      case UserRole.admin:
        return adminTheme;
    }
  }

  /// Colores de degradado para el fondo del login
  static List<Color> getGradientForRole(UserRole role) {
    switch (role) {
      case UserRole.docente:
        return [_docentePrimary, _docenteSecondary];
      case UserRole.admin:
        return [_adminPrimary, _adminSecondary];
    }
  }
}

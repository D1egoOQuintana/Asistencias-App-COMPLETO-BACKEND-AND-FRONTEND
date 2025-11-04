import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Provider de autenticación que maneja el estado global de login
/// Utiliza ChangeNotifier para notificar cambios a la UI
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  /// Usuario actualmente autenticado
  UserModel? get user => _user;

  /// Estado de carga durante operaciones async
  bool get isLoading => _isLoading;

  /// Mensaje de error si algo falla
  String? get errorMessage => _errorMessage;

  /// Verificar si hay un usuario autenticado
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    // Escuchar cambios en el estado de autenticación
    _authService.authStateChanges.listen(_onAuthStateChanged);
    _initializeUser();
  }

  /// Inicializar usuario al arrancar la app
  Future<void> _initializeUser() async {
    _setLoading(true);
    try {
      // Timeout de 5 segundos para evitar que se quede cargando
      _user = await _authService.getCurrentUserData().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('Timeout initializing user - no user logged in');
          return null;
        },
      );
    } catch (e) {
      print('Error initializing user: $e');
      _user = null;
      _errorMessage = null; // No mostrar error en la inicialización
    } finally {
      _setLoading(false);
    }
  }

  /// Manejar cambios en el estado de autenticación
  void _onAuthStateChanged(User? firebaseUser) async {
    try {
      if (firebaseUser == null) {
        _user = null;
        notifyListeners();
      } else {
        // Obtener datos completos del usuario
        _user = await _authService.getCurrentUserData();
        notifyListeners();
      }
    } catch (e) {
      print('Error on auth state change: $e');
      _user = null;
      notifyListeners();
    }
  }

  /// Iniciar sesión con email y contraseña
  Future<bool> signIn({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // Timeout de 10 segundos para login
      _user = await _authService
          .signInWithEmailAndPassword(
            email: email,
            password: password,
            expectedRole: expectedRole,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Tiempo de espera agotado. Verifica tu conexión.',
              );
            },
          );

      _setLoading(false);
      return _user != null;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Cerrar sesión
  Future<void> signOut() async {
    try {
      _setLoading(true);
      await _authService.signOut();
      _user = null;
      _clearError();
      _setLoading(false);
    } catch (e) {
      _setError('Error al cerrar sesión: $e');
      _setLoading(false);
    }
  }

  /// Limpiar mensaje de error
  void clearError() {
    _clearError();
  }

  // Métodos privados para manejo de estado
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

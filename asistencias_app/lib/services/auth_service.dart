import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Servicio de autenticación con Firebase Auth optimizado
/// Maneja el login de docentes y administradores con caché
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache del último usuario para evitar consultas repetidas
  UserModel? _cachedUser;
  String? _cachedUserId;

  /// Usuario actual autenticado
  User? get currentUser => _auth.currentUser;

  /// Stream del estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Iniciar sesión con email y contraseña
  /// Valida que el usuario sea docente o admin en Firestore
  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) async {
    try {
      // Autenticar con Firebase Auth
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (result.user == null) return null;

      // Obtener datos del usuario desde Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(result.user!.uid)
          .get();

      if (!userDoc.exists) {
        await signOut();
        throw Exception('Usuario no encontrado en el sistema');
      }

      final userData = userDoc.data()!;
      final userRole = UserRole.fromString(userData['role']);

      // Validar que el rol coincida con el esperado
      if (userRole != expectedRole) {
        await signOut();
        throw Exception(
          'Acceso denegado. Este usuario no tiene permisos de ${expectedRole.displayName}',
        );
      }

      // Validar que el usuario esté activo
      if (userData['isActive'] != true) {
        await signOut();
        throw Exception('Usuario inactivo. Contacte al administrador');
      }

      return UserModel.fromFirestore(result.user!.uid, userData);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Cerrar sesión y limpiar caché
  Future<void> signOut() async {
    _cachedUser = null;
    _cachedUserId = null;
    await _auth.signOut();
  }

  /// Obtener datos del usuario actual desde Firestore con caché
  Future<UserModel?> getCurrentUserData() async {
    final user = currentUser;
    if (user == null) return null;

    // Si ya tenemos el usuario en caché, devolverlo inmediatamente
    if (_cachedUser != null && _cachedUserId == user.uid) {
      return _cachedUser;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      _cachedUser = UserModel.fromFirestore(user.uid, userData);
      _cachedUserId = user.uid;
      
      return _cachedUser;
    } catch (e) {
      return null;
    }
  }

  /// Manejo de excepciones de Firebase Auth
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No existe una cuenta con este email';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'invalid-email':
        return 'Email inválido';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada';
      case 'too-many-requests':
        return 'Demasiados intentos fallidos. Intente más tarde';
      case 'network-request-failed':
        return 'Error de conexión. Verifique su internet';
      case 'invalid-credential':
        return 'Credenciales inválidas. Verifique email y contraseña';
      default:
        return 'Error de autenticación: ${e.message}';
    }
  }
}

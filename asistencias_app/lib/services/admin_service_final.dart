import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<Map<String, dynamic>> createTeacher({
    required String email,
    required String fullName,
    required String temporaryPassword,
  }) async {
    FirebaseApp? secondaryApp;
    FirebaseAuth? secondaryAuth;

    try {
      // Crear una instancia secundaria de Firebase
      secondaryApp = await Firebase.initializeApp(
        name: 'secondary_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // Crear el usuario en la instancia secundaria
      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: temporaryPassword,
      );

      final newUserUid = userCredential.user!.uid;

      // Crear el documento del docente en Firestore usando la instancia principal
      final parts = fullName.trim().split(RegExp(r"\s+"));
      final firstName = parts.isNotEmpty ? parts.first : '';
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      await _firestore.collection('users').doc(newUserUid).set({
        'uid': newUserUid,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'fullName': fullName,
        'role': 'docente',
        'isActive': true,
        'needsRegistration': true, // compatibilidad legacy
        'mustChangePassword': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdByAdmin': true,
        'temporaryPassword':
            temporaryPassword, // Solo para referencia del admin
      });

      // Cerrar sesión en la instancia secundaria
      await secondaryAuth.signOut();

      return {
        'success': true,
        'message':
            'Docente creado exitosamente. El docente puede iniciar sesión inmediatamente.',
        'teacherUid': newUserUid,
        'teacherEmail': email,
        'temporaryPassword': temporaryPassword,
        'requiresAdminReLogin': false, // ¡El admin mantiene su sesión!
      };
    } catch (e) {
      return {
        'success': false,
        'message': _getErrorMessage(e),
        'error': e.toString(),
      };
    } finally {
      // Limpiar: eliminar la instancia secundaria
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (e) {
          print('Error eliminando app secundaria: $e');
        }
      }
    }
  }

  /// Obtener mensaje de error legible
  static String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'weak-password':
          return 'La contraseña es muy débil (mínimo 6 caracteres)';
        case 'email-already-in-use':
          return 'Ya existe un usuario con este email';
        case 'invalid-email':
          return 'Email inválido';
        case 'operation-not-allowed':
          return 'Operación no permitida';
        default:
          return error.message ?? 'Error de autenticación';
      }
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Permisos insuficientes. Verifica que seas administrador.';
        case 'unavailable':
          return 'Servicio no disponible. Intenta más tarde.';
        default:
          return error.message ?? 'Error de Firestore';
      }
    }
    return 'Error: ${error.toString()}';
  }

  /// Listar todos los docentes
  static Stream<QuerySnapshot> getTeachersStream() {
    return _firestore
        .collection('users')
        .where('role', whereIn: ['docente', 'teacher'])
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Actualizar datos de un docente
  static Future<bool> updateTeacher({
    required String teacherUid,
    required String fullName,
  }) async {
    try {
      await _firestore.collection('users').doc(teacherUid).update({
        'fullName': fullName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating teacher: $e');
      return false;
    }
  }

  /// Desactivar/activar un docente
  static Future<bool> toggleTeacherStatus({
    required String teacherUid,
    required bool isActive,
  }) async {
    try {
      await _firestore.collection('users').doc(teacherUid).update({
        'isActive': isActive,
        'statusChangedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error toggling teacher status: $e');
      return false;
    }
  }

  /// Eliminar un docente (solo desactivar, no eliminar completamente)
  static Future<bool> deleteTeacher(String teacherUid) async {
    try {
      // Solo desactivamos, no eliminamos completamente
      await _firestore.collection('users').doc(teacherUid).update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
        'isDeleted': true,
      });
      return true;
    } catch (e) {
      print('Error deleting teacher: $e');
      return false;
    }
  }
}

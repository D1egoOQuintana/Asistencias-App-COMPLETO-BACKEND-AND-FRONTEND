import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Crear un docente solo en Firestore (sin Firebase Auth)
  /// El admin mantiene su sesión activa
  static Future<Map<String, dynamic>> createTeacher({
    required String email,
    required String fullName,
    required String temporaryPassword,
  }) async {
    try {
      // Crear solo el documento en Firestore con información temporal
      // El docente se registrará en Firebase Auth cuando inicie sesión por primera vez
      await _firestore.collection('users').add({
        'email': email,
        'fullName': fullName,
        'role': 'docente',
        'isActive': false, // Inactivo hasta que complete el registro
        'needsRegistration': true, // Necesita completar el registro
        'temporaryPassword':
            temporaryPassword, // Contraseña temporal para referencia
        'createdAt': FieldValue.serverTimestamp(),
        'createdByAdmin': true,
      });

      return {
        'success': true,
        'message':
            'Docente creado correctamente. El docente debe registrarse en la app con estos datos.',
        'teacherEmail': email,
        'temporaryPassword': temporaryPassword,
        'needsRegistration': true,
      };
    } catch (e) {
      return {
        'success': false,
        'message': _getErrorMessage(e),
        'error': e.toString(),
      };
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
        .where('role', isEqualTo: 'docente')
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

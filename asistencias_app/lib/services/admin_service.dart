import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Base de la API de Cloud Functions usada por operaciones administrativas
  /// que requieren privilegios de servidor (p. ej. forzar cambio de contraseña).
  static const String _baseUrl =
      'https://us-central1-asistencia-alumnos-2025.cloudfunctions.net/api';

  static Future<Map<String, dynamic>> createTeacher({
    required String email,
    required String fullName,
    required String temporaryPassword,
    String? phone,
    String? subject,
    bool isAuxiliar = false,
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
        'isAuxiliar': isAuxiliar,
        'needsRegistration': true, // compatibilidad legacy
        'mustChangePassword': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdByAdmin': true,
        'temporaryPassword':
            temporaryPassword, // Solo para referencia del admin
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (subject != null && subject.trim().isNotEmpty)
          'subject': subject.trim(),
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

  /// Actualizar datos de un docente
  static Future<bool> updateTeacher({
    required String teacherUid,
    required String fullName,
    String? phone,
    String? subject,
    bool? isAuxiliar,
  }) async {
    try {
      final data = <String, dynamic>{
        'fullName': fullName,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (phone != null) data['phone'] = phone.trim();
      if (subject != null) data['subject'] = subject.trim();
      if (isAuxiliar != null) data['isAuxiliar'] = isAuxiliar;
      await _firestore.collection('users').doc(teacherUid).update(data);
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

  /// Stream de docentes activos (para contadores/selectores en el panel).
  static Stream<QuerySnapshot> getActiveTeachers() {
    return _firestore
        .collection('users')
        .where('role', whereIn: ['docente', 'teacher'])
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  /// Forzar cambio de contraseña de un docente vía Cloud Functions (requiere
  /// privilegios de servidor; se autentica con el token del admin actual).
  static Future<Map<String, dynamic>> forcePasswordChange({
    required String teacherUid,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final token = await user.getIdToken();

      final response = await http.post(
        Uri.parse('$_baseUrl/admin/teachers/force-password-change'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'teacherUid': teacherUid}),
      );

      final data = json.decode(response.body);

      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Error desconocido',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }
}

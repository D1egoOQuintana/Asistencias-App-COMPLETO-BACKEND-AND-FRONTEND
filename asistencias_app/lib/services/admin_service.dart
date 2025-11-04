import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  static const String _baseUrl =
      'https://us-central1-asistencia-alumnos-2025.cloudfunctions.net/api';

  /// Crear un nuevo docente usando Cloud Functions
  static Future<Map<String, dynamic>> createTeacher({
    required String email,
    required String fullName,
    required String temporaryPassword,
  }) async {
    try {
      // Obtener el token del usuario actual
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final token = await user.getIdToken();

      final response = await http.post(
        Uri.parse('$_baseUrl/admin/teachers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'email': email,
          'fullName': fullName,
          'temporaryPassword': temporaryPassword,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error desconocido',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  /// Forzar cambio de contraseña de un docente
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

  /// Listar todos los docentes
  static Future<Map<String, dynamic>> listTeachers() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final token = await user.getIdToken();

      final response = await http.get(
        Uri.parse('$_baseUrl/admin/teachers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);

      return {
        'success': data['success'] ?? false,
        'data': data['data'] ?? [],
        'message': data['message'] ?? 'Error desconocido',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e', 'data': []};
    }
  }

  /// Obtener stream de docentes activos desde Firestore
  static Stream<QuerySnapshot> getActiveTeachers() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: ['docente', 'teacher'])
        .where('isActive', isEqualTo: true)
        .snapshots();
  }
}

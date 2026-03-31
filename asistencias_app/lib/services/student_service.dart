import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/student_model.dart';

class StudentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Formatear teléfono peruano con +51
  static String? formatPeruvianPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return null;

    // Limpiar espacios y caracteres especiales
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Si ya tiene +51, devolverlo
    if (cleaned.startsWith('+51')) {
      return cleaned;
    }

    // Si empieza con 51 (sin +), agregar +
    if (cleaned.startsWith('51') && cleaned.length == 11) {
      return '+$cleaned';
    }

    // Si empieza con 9 y tiene 9 dígitos, agregar +51
    if (cleaned.startsWith('9') && cleaned.length == 9) {
      return '+51$cleaned';
    }

    // Si no empieza con 9 pero tiene 9 dígitos, asumir que es peruano
    if (cleaned.length == 9) {
      return '+51$cleaned';
    }

    // Si tiene otros formatos, intentar limpiar y agregar +51
    if (cleaned.length >= 8 && cleaned.length <= 10) {
      return '+51$cleaned';
    }

    // Si no se puede formatear, devolver el original
    return phone;
  }

  /// Crear un nuevo estudiante
  static Future<Map<String, dynamic>> createStudent({
    required String firstName,
    required String lastName,
    String? dni,
    required String classroomId,
    String? parentEmail,
    String? parentPhone,
  }) async {
    try {
      // Verificar que el usuario actual sea docente o admin
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {'success': false, 'message': 'Usuario no autenticado'};
      }

      final normalizedDni = (dni ?? '').trim();

      // Verificar duplicados solo cuando el DNI fue ingresado.
      if (normalizedDni.isNotEmpty) {
        final existingStudent = await _firestore
            .collection('students')
            .where('dni', isEqualTo: normalizedDni)
            .limit(1)
            .get();

        if (existingStudent.docs.isNotEmpty) {
          return {
            'success': false,
            'message': 'Ya existe un estudiante con este DNI',
          };
        }
      }

      // Formatear teléfono con +51
      final formattedPhone = formatPeruvianPhone(parentPhone);

      // Crear el estudiante
      final student = StudentModel(
        firstName: firstName,
        lastName: lastName,
        dni: normalizedDni,
        qrCode: StudentModel.generateQRCode(),
        classroomId: classroomId,
        parentEmail: parentEmail,
        parentPhone: formattedPhone,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );

      print('DEBUG: About to save student to Firestore: ${student.toMap()}');
      // Guardar en Firestore
      final docRef = await _firestore
          .collection('students')
          .add(student.toMap());
      print('DEBUG: Student saved with docRef: ${docRef.id}');

      return {
        'success': true,
        'message': 'Estudiante creado exitosamente',
        'studentId': docRef.id,
        'qrCode': student.qrCode,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al crear estudiante: ${e.toString()}',
      };
    }
  }

  /// Generar enlace de activación de Telegram para un estudiante
  static Future<Map<String, dynamic>> generateTelegramActivationLink({
    required String studentId,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'createTelegramActivationLink',
      );

      final result = await callable.call(<String, dynamic>{
        'studentId': studentId,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      return {'success': true, ...data};
    } on FirebaseFunctionsException catch (e) {
      final code = e.code.toString();
      final rawMessage = (e.message ?? '').trim();
      return {
        'success': false,
        'message': rawMessage.isNotEmpty
            ? '$rawMessage (code: $code)'
            : 'No se pudo generar el enlace de activación (code: $code)',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al generar enlace de activación: ${e.toString()}',
      };
    }
  }

  /// Obtener estudiantes por aula (sin orderBy para no requerir índice)
  static Stream<QuerySnapshot> getStudentsByClassroom(String classroomId) {
    return _firestore
        .collection('students')
        .where('classroomId', isEqualTo: classroomId)
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  /// Obtener todos los estudiantes (solo admin)
  static Stream<QuerySnapshot> getAllStudents() {
    print('DEBUG: StudentService.getAllStudents() called');
    try {
      final stream = _firestore
          .collection('students')
          .where('isActive', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .handleError((error) {
            print('DEBUG: Stream error caught: $error');
            // Reintentar la conexión después de un error
            return _firestore
                .collection('students')
                .where('isActive', isEqualTo: true)
                .orderBy('updatedAt', descending: true)
                .snapshots();
          });
      print('DEBUG: StudentService stream created');
      return stream;
    } catch (e) {
      print('DEBUG: Error creating students stream: $e');
      rethrow;
    }
  }

  /// Método alternativo para obtener estudiantes sin orderBy (para evitar errores de índices)
  static Stream<QuerySnapshot> getAllStudentsSimple() {
    print('DEBUG: StudentService.getAllStudentsSimple() called');
    try {
      final stream = _firestore
          .collection('students')
          .where('isActive', isEqualTo: true)
          .snapshots()
          .handleError((error) {
            print('DEBUG: Simple stream error caught: $error');
          });
      print('DEBUG: StudentService simple stream created');
      return stream;
    } catch (e) {
      print('DEBUG: Error creating simple students stream: $e');
      rethrow;
    }
  }

  /// Actualizar estudiante
  static Future<bool> updateStudent({
    required String studentId,
    required String firstName,
    required String lastName,
    String? dni,
    required String classroomId,
    String? parentEmail,
    String? parentPhone,
  }) async {
    try {
      final normalizedDni = (dni ?? '').trim();

      // Evitar DNI duplicado al editar solo cuando hay valor.
      if (normalizedDni.isNotEmpty) {
        final existingStudent = await _firestore
            .collection('students')
            .where('dni', isEqualTo: normalizedDni)
            .limit(2)
            .get();

        final duplicated = existingStudent.docs.any((d) => d.id != studentId);
        if (duplicated) {
          return false;
        }
      }

      // Formatear teléfono con +51
      final formattedPhone = formatPeruvianPhone(parentPhone);

      await _firestore.collection('students').doc(studentId).update({
        'firstName': firstName,
        'lastName': lastName,
        'dni': normalizedDni,
        'classroomId': classroomId,
        'parentEmail': parentEmail,
        'parentPhone': formattedPhone,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      print('Error updating student: $e');
      return false;
    }
  }

  /// Desactivar estudiante (soft delete)
  static Future<bool> deactivateStudent(String studentId) async {
    try {
      await _firestore.collection('students').doc(studentId).update({
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      print('Error deactivating student: $e');
      return false;
    }
  }

  /// Reactivar estudiante
  static Future<bool> reactivateStudent(String studentId) async {
    try {
      await _firestore.collection('students').doc(studentId).update({
        'isActive': true,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      print('Error reactivating student: $e');
      return false;
    }
  }

  /// Eliminar estudiante permanentemente
  static Future<bool> deleteStudentPermanently(String studentId) async {
    try {
      await _firestore.collection('students').doc(studentId).delete();
      return true;
    } catch (e) {
      print('Error deleting student permanently: $e');
      return false;
    }
  }

  /// Obtener estudiante por ID
  static Future<StudentModel?> getStudentById(String studentId) async {
    try {
      final doc = await _firestore.collection('students').doc(studentId).get();
      if (doc.exists) {
        return StudentModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting student: $e');
      return null;
    }
  }

  /// Buscar estudiantes por nombre o DNI
  static Future<List<StudentModel>> searchStudents(String query) async {
    try {
      final queryLower = query.toLowerCase();

      // Buscar por firstName
      final firstNameQuery = await _firestore
          .collection('students')
          .where('firstName', isGreaterThanOrEqualTo: queryLower)
          .where('firstName', isLessThan: '${queryLower}z')
          .where('isActive', isEqualTo: true)
          .get();

      // Buscar por lastName
      final lastNameQuery = await _firestore
          .collection('students')
          .where('lastName', isGreaterThanOrEqualTo: queryLower)
          .where('lastName', isLessThan: '${queryLower}z')
          .where('isActive', isEqualTo: true)
          .get();

      // Buscar por DNI
      final dniQuery = await _firestore
          .collection('students')
          .where('dni', isEqualTo: query)
          .where('isActive', isEqualTo: true)
          .get();

      // Combinar resultados y eliminar duplicados
      final students = <StudentModel>[];
      final addedIds = <String>{};

      for (final doc in [
        ...firstNameQuery.docs,
        ...lastNameQuery.docs,
        ...dniQuery.docs,
      ]) {
        if (!addedIds.contains(doc.id)) {
          students.add(StudentModel.fromFirestore(doc));
          addedIds.add(doc.id);
        }
      }

      return students;
    } catch (e) {
      print('Error searching students: $e');
      return [];
    }
  }

  /// Transferir estudiante a otra aula
  static Future<bool> transferStudent({
    required String studentId,
    required String newClassroomId,
  }) async {
    try {
      await _firestore.collection('students').doc(studentId).update({
        'classroomId': newClassroomId,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      print('Error transferring student: $e');
      return false;
    }
  }

  /// Obtener estadísticas de estudiantes
  static Future<Map<String, int>> getStudentStats() async {
    try {
      final allStudents = await _firestore.collection('students').get();

      final activeStudents = await _firestore
          .collection('students')
          .where('isActive', isEqualTo: true)
          .get();

      return {
        'total': allStudents.docs.length,
        'active': activeStudents.docs.length,
        'inactive': allStudents.docs.length - activeStudents.docs.length,
      };
    } catch (e) {
      print('Error getting student stats: $e');
      return {'total': 0, 'active': 0, 'inactive': 0};
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/classroom_model.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';

/// Servicio para manejar todas las operaciones de Firestore
class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Colecciones
  static const String _usersCollection = 'users';
  static const String _classroomsCollection = 'classrooms';
  static const String _studentsCollection = 'students';
  static const String _attendanceCollection = 'attendance';

  static CollectionReference<Map<String, dynamic>> _classroomAttendance(
    String classroomId,
  ) => _firestore
      .collection(_classroomsCollection)
      .doc(classroomId)
      .collection(_attendanceCollection);

  static Query<Map<String, dynamic>> _attendanceGroup() =>
      _firestore.collectionGroup(_attendanceCollection);

  // ============================================================================
  // GESTIÓN DE USUARIOS/DOCENTES
  // ============================================================================

  /// Crear o actualizar usuario en Firestore
  static Future<void> createUser(UserModel user) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .set(user.toMap());
    } catch (e) {
      throw Exception('Error al crear usuario: $e');
    }
  }

  /// Obtener usuario por UID
  static Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener usuario: $e');
    }
  }

  /// Obtener todos los docentes
  static Future<List<UserModel>> getAllTeachers() async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          // Soporta ambos roles por compatibilidad
          .where('role', whereIn: ['docente', 'teacher'])
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener docentes: $e');
    }
  }

  /// Eliminar docente
  static Future<void> deleteTeacher(String uid) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).delete();
    } catch (e) {
      throw Exception('Error al eliminar docente: $e');
    }
  }

  // ============================================================================
  // GESTIÓN DE AULAS
  // ============================================================================

  /// Crear nueva aula
  static Future<void> createClassroom(ClassroomModel classroom) async {
    try {
      await _firestore.collection(_classroomsCollection).add(classroom.toMap());
    } catch (e) {
      throw Exception('Error al crear aula: $e');
    }
  }

  /// Obtener todas las aulas
  static Future<List<ClassroomModel>> getAllClassrooms() async {
    try {
      final querySnapshot = await _firestore
          .collection(_classroomsCollection)
          .get();
      return querySnapshot.docs
          .map((doc) => ClassroomModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener aulas: $e');
    }
  }

  /// Obtener aula por ID
  static Future<ClassroomModel?> getClassroom(String classroomId) async {
    try {
      final doc = await _firestore
          .collection(_classroomsCollection)
          .doc(classroomId)
          .get();
      if (doc.exists) {
        return ClassroomModel.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener aula: $e');
    }
  }

  /// Actualizar aula
  static Future<void> updateClassroom(ClassroomModel classroom) async {
    try {
      await _firestore
          .collection(_classroomsCollection)
          .doc(classroom.id)
          .update(classroom.toMap());
    } catch (e) {
      throw Exception('Error al actualizar aula: $e');
    }
  }

  /// Eliminar aula
  static Future<void> deleteClassroom(String classroomId) async {
    try {
      await _firestore
          .collection(_classroomsCollection)
          .doc(classroomId)
          .delete();
    } catch (e) {
      throw Exception('Error al eliminar aula: $e');
    }
  }

  /// Asignar docente a aula
  static Future<void> assignTeacherToClassroom(
    String classroomId,
    String teacherUid,
  ) async {
    try {
      await _firestore
          .collection(_classroomsCollection)
          .doc(classroomId)
          .update({'teacherUid': teacherUid});
    } catch (e) {
      throw Exception('Error al asignar docente: $e');
    }
  }

  /// Obtener aula del docente
  static Future<ClassroomModel?> getTeacherClassroom(String teacherUid) async {
    try {
      final querySnapshot = await _firestore
          .collection(_classroomsCollection)
          .where('teacherUid', isEqualTo: teacherUid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return ClassroomModel.fromMap({...doc.data(), 'id': doc.id});
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener aula del docente: $e');
    }
  }

  // ============================================================================
  // GESTIÓN DE ESTUDIANTES
  // ============================================================================

  /// Crear nuevo estudiante
  static Future<void> createStudent(StudentModel student) async {
    try {
      await _firestore.collection(_studentsCollection).add(student.toMap());
    } catch (e) {
      throw Exception('Error al crear estudiante: $e');
    }
  }

  /// Obtener estudiantes de un aula
  static Future<List<StudentModel>> getStudentsByClassroom(
    String classroomId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_studentsCollection)
          .where('classroomId', isEqualTo: classroomId)
          .orderBy('firstName')
          .get();

      return querySnapshot.docs
          .map((doc) => StudentModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener estudiantes: $e');
    }
  }

  /// Obtener estudiante por código QR
  static Future<StudentModel?> getStudentByQrCode(String qrCode) async {
    try {
      final querySnapshot = await _firestore
          .collection(_studentsCollection)
          .where('qrCode', isEqualTo: qrCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return StudentModel.fromMap({...doc.data(), 'id': doc.id});
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener estudiante por QR: $e');
    }
  }

  /// Actualizar estudiante
  static Future<void> updateStudent(StudentModel student) async {
    try {
      await _firestore
          .collection(_studentsCollection)
          .doc(student.id)
          .update(student.toMap());
    } catch (e) {
      throw Exception('Error al actualizar estudiante: $e');
    }
  }

  /// Eliminar estudiante
  static Future<void> deleteStudent(String studentId) async {
    try {
      await _firestore.collection(_studentsCollection).doc(studentId).delete();
    } catch (e) {
      throw Exception('Error al eliminar estudiante: $e');
    }
  }

  // ============================================================================
  // GESTIÓN DE ASISTENCIAS
  // ============================================================================

  /// Registrar asistencia
  static Future<void> recordAttendance(AttendanceModel attendance) async {
    try {
      if (attendance.classroomId.isEmpty) {
        throw Exception('classroomId requerido para registrar asistencia');
      }

      await _classroomAttendance(attendance.classroomId)
          .add(attendance.toMap());
    } catch (e) {
      throw Exception('Error al registrar asistencia: $e');
    }
  }

  /// Obtener asistencias por fecha y aula
  static Future<List<AttendanceModel>> getAttendanceByDate(
    String classroomId,
    DateTime date,
  ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final querySnapshot = await _firestore
          .collection(_classroomsCollection)
          .doc(classroomId)
          .collection(_attendanceCollection)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .orderBy('timestamp')
          .get();

      return querySnapshot.docs
          .map((doc) => AttendanceModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener asistencias: $e');
    }
  }

  /// Obtener historial de asistencias de un estudiante
  static Future<List<AttendanceModel>> getStudentAttendanceHistory(
    String studentId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
        Query query = _attendanceGroup().where('studentId', isEqualTo: studentId);

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      final querySnapshot = await query
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => AttendanceModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener historial de asistencias: $e');
    }
  }

  /// Verificar si ya existe asistencia del día
  static Future<bool> hasAttendanceToday(
    String studentId,
    String classroomId,
  ) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final querySnapshot = await _firestore
          .collection(_classroomsCollection)
          .doc(classroomId)
          .collection(_attendanceCollection)
          .where('studentId', isEqualTo: studentId)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Error al verificar asistencia: $e');
    }
  }

  // ============================================================================
  // ESTADÍSTICAS Y REPORTES
  // ============================================================================

  /// Obtener estadísticas del sistema
  static Future<Map<String, int>> getSystemStats() async {
    try {
      final teachersDocente = await _firestore
          .collection(_usersCollection)
          .where('role', isEqualTo: 'docente')
          .count()
          .get();

      final teachersTeacher = await _firestore
          .collection(_usersCollection)
          .where('role', isEqualTo: 'teacher')
          .count()
          .get();

      final classroomsCount = await _firestore
          .collection(_classroomsCollection)
          .count()
          .get();

      final studentsCount = await _firestore
          .collection(_studentsCollection)
          .count()
          .get();

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final todayAttendanceCount = await _firestore
          .collectionGroup(_attendanceCollection)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .count()
          .get();

      return {
        'teachers': (teachersDocente.count ?? 0) + (teachersTeacher.count ?? 0),
        'classrooms': classroomsCount.count ?? 0,
        'students': studentsCount.count ?? 0,
        'todayAttendance': todayAttendanceCount.count ?? 0,
      };
    } catch (e) {
      throw Exception('Error al obtener estadísticas: $e');
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Obtener stream de todos los docentes
  static Stream<QuerySnapshot> getTeachersStream() {
    return _db
        .collection('users')
        // Soporta ambos valores de rol por compatibilidad
        .where('role', whereIn: ['docente', 'teacher'])
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  // Obtener un docente por UID
  static Future<Map<String, dynamic>?> getTeacherByUid(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final role = (data['role'] ?? '').toString();
        if (role == 'docente' || role == 'teacher') return data;
      }
      return null;
    } catch (e) {
      print('Error getting teacher: $e');
      return null;
    }
  }

  // Obtener todas las aulas asignadas a un docente
  static Stream<QuerySnapshot> getClassroomsByTeacher(String teacherUid) {
    return _db
        .collection('classrooms')
        .where('teacherUid', isEqualTo: teacherUid)
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  // Verificar si un docente ya tiene aulas asignadas
  static Future<bool> hasAssignedClassrooms(String teacherUid) async {
    try {
      final snapshot = await _db
          .collection('classrooms')
          .where('teacherUid', isEqualTo: teacherUid)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking assigned classrooms: $e');
      return false;
    }
  }

  // Obtener docentes disponibles (sin aulas asignadas)
  static Stream<QuerySnapshot> getAvailableTeachersStream() {
    return _db
        .collection('users')
        .where('role', whereIn: ['docente', 'teacher'])
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  // Contar total de docentes
  static Future<int> getTotalTeachersCount() async {
    try {
      final snapshot = await _db
          .collection('users')
          .where('role', whereIn: ['docente', 'teacher'])
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error counting teachers: $e');
      return 0;
    }
  }
}

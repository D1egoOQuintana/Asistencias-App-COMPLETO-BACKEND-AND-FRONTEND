import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_models.dart';

/// Repositorio central para asistir a consultas/escrituras de asistencia
class AttendanceRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> sessions(String classroomId) =>
      _db.collection('classrooms').doc(classroomId).collection('attendance');

  /// Stream de entradas de asistencia para un día concreto (sincronización con QR)
  Stream<List<AttendanceEntry>> entriesForDayStream({
    required String classroomId,
    required DateTime day,
  }) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return sessions(classroomId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThan: Timestamp.fromDate(end))
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(AttendanceEntry.fromDoc).toList());
  }

  /// Verifica si ya hay registro de la clase en el día (evita duplicados)
  Future<bool> hasSessionForDay({
    required String classroomId,
    required DateTime day,
  }) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final q = await sessions(classroomId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThan: Timestamp.fromDate(end))
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  /// Agregar/actualizar entrada por estudiante para el día (idempotente por día)
  Future<void> upsertEntryForDay({
    required String classroomId,
    required String studentId,
    required AttendanceStatus status,
    String? studentName,
    DateTime? when,
  }) async {
    final now = when ?? DateTime.now();
    final docId = '${now.year}-${now.month}-${now.day}__$studentId';
    await sessions(classroomId).doc(docId).set({
      'studentId': studentId,
      'status': statusToString(status),
      'timestamp': Timestamp.fromDate(now),
      if (studentName != null) 'studentName': studentName,
    }, SetOptions(merge: true));
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_models.dart';

enum QrScanResultType { entryRegistered, exitRegistered, exitAlreadyRegistered }

class QrScanResult {
  final QrScanResultType type;
  final AttendanceStatus status;

  const QrScanResult({required this.type, required this.status});
}

/// Repositorio central para asistir a consultas/escrituras de asistencia
class AttendanceRepository {
  final FirebaseFirestore _db;

  AttendanceRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  String _legacyStatus(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.presente:
        return 'present';
      case AttendanceStatus.tarde:
        return 'late';
      case AttendanceStatus.ausente:
        return 'absent';
    }
  }

  AttendanceStatus _statusFromAny(String value) {
    switch (value.toLowerCase()) {
      case 'late':
      case 'tarde':
        return AttendanceStatus.tarde;
      case 'absent':
      case 'ausente':
        return AttendanceStatus.ausente;
      case 'present':
      case 'presente':
      default:
        return AttendanceStatus.presente;
    }
  }

  CollectionReference<Map<String, dynamic>> _classroomAttendance(
    String classroomId,
  ) => _db.collection('classrooms').doc(classroomId).collection('attendance');

  /// Stream de entradas de asistencia para un día concreto (sincronización con QR)
  Stream<List<AttendanceEntry>> entriesForDayStream({
    required String classroomId,
    required DateTime day,
  }) {
    final dateKey =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return _classroomAttendance(classroomId)
        .where('date', isEqualTo: dateKey)
        .snapshots()
        .map((snap) {
          final items = snap.docs.map(AttendanceEntry.fromDoc).toList();
          items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return items;
        });
  }

  /// Verifica si ya hay registro de la clase en el día (evita duplicados)
  Future<bool> hasSessionForDay({
    required String classroomId,
    required DateTime day,
  }) async {
    final dateKey =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final q = await _classroomAttendance(classroomId)
        .where('date', isEqualTo: dateKey)
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
    final dateKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final legacyId = '${studentId}_$dateKey';
    await _classroomAttendance(classroomId).doc(legacyId).set({
      'classroomId': classroomId,
      'studentId': studentId,
      'status': _legacyStatus(status),
      'timestamp': Timestamp.fromDate(now),
      'entryAt': Timestamp.fromDate(now),
      'date': dateKey,
      if (studentName != null) 'studentName': studentName,
    }, SetOptions(merge: true));
  }

  /// Registra un escaneo QR como entrada/salida en un solo flujo idempotente.
  Future<QrScanResult> registerQrScanForDay({
    required String classroomId,
    required String studentId,
    required AttendanceStatus status,
    String? studentName,
    DateTime? when,
    String? sessionId,
  }) async {
    final now = when ?? DateTime.now();
    final dateKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final attendanceRef =
      _classroomAttendance(classroomId).doc('${studentId}_$dateKey');

    return _db.runTransaction((tx) async {
      final attendanceSnap = await tx.get(attendanceRef);

      if (!attendanceSnap.exists) {
        tx.set(attendanceRef, {
          'classroomId': classroomId,
          'studentId': studentId,
          'status': _legacyStatus(status),
          'timestamp': FieldValue.serverTimestamp(),
          'entryAt': FieldValue.serverTimestamp(),
          'eventDriven': true,
          'source': 'qr',
          'date': dateKey,
          if (sessionId != null) 'sessionId': sessionId,
          if (studentName != null) 'studentName': studentName,
        }, SetOptions(merge: true));

        return QrScanResult(
          type: QrScanResultType.entryRegistered,
          status: status,
        );
      }

      final attendanceData = attendanceSnap.data() ?? <String, dynamic>{};
      if (attendanceData['exitAt'] != null) {
        final currentStatus = _statusFromAny(
          (attendanceData['status'] ?? _legacyStatus(status)).toString(),
        );
        return QrScanResult(
          type: QrScanResultType.exitAlreadyRegistered,
          status: currentStatus,
        );
      }

      final currentStatus = _statusFromAny(
        (attendanceData['status'] ?? _legacyStatus(status)).toString(),
      );

      tx.set(attendanceRef, {
        'exitAt': FieldValue.serverTimestamp(),
        'exitSource': 'qr',
        'timestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'eventDriven': true,
        'source': 'qr',
        'classroomId': classroomId,
        'date': dateKey,
        if (studentName != null) 'studentName': studentName,
        if (sessionId != null) 'sessionId': sessionId,
      }, SetOptions(merge: true));

      return QrScanResult(
        type: QrScanResultType.exitRegistered,
        status: currentStatus,
      );
    });
  }
}

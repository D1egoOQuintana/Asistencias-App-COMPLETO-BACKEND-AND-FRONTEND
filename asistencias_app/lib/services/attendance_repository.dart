import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_models.dart';

enum QrScanResultType { entryRegistered, exitRegistered, exitAlreadyRegistered }

/// Resultado de evaluar la hora del escaneo contra el horario del aula.
/// - [present]: a tiempo (hasta maxLateTime).
/// - [late]: después de maxLateTime pero aún dentro del horario.
/// - [outsideSchedule]: después de endTime → no se debe registrar.
/// - [noSchedule]: el aula no tiene horario válido para hoy → el llamador
///   decide (en el flujo vivo se trata como [present] para no romper aulas
///   sin horario configurado).
enum AttendanceTiming { present, late, outsideSchedule, noSchedule }

/// Combina una fecha con un string 'HH:mm'. Devuelve null si no es parseable.
DateTime? parseHhmmOnDate(DateTime day, String? hhmm) {
  if (hhmm == null) return null;
  final parts = hhmm.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return DateTime(day.year, day.month, day.day, h, m);
}

/// Decide el estado de asistencia según el horario del aula y la hora del
/// escaneo. Lógica portada de `quick_qr_attendance_screen.dart` (pantalla
/// muerta) a una función pura y testeable.
AttendanceTiming evaluateAttendanceTiming({
  required String? maxLateTime,
  required String? endTime,
  required DateTime now,
}) {
  final maxLate = parseHhmmOnDate(now, maxLateTime);
  final end = parseHhmmOnDate(now, endTime);
  if (maxLate == null || end == null) return AttendanceTiming.noSchedule;
  if (now.isAfter(end)) return AttendanceTiming.outsideSchedule;
  if (now.isAfter(maxLate)) return AttendanceTiming.late;
  return AttendanceTiming.present;
}

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

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Marca como AUSENTES a los estudiantes activos que NO tienen documento de
  /// asistencia para [day]. Persiste en la ruta real
  /// `classrooms/{classroomId}/attendance/{studentId}_{dateKey}` con docId
  /// determinístico, por lo que es idempotente: correrlo dos veces no duplica.
  ///
  /// No sobrescribe registros existentes (presente/tarde/ausente): se filtra
  /// por los documentos ya presentes ese día antes de escribir. Devuelve cuántos
  /// ausentes nuevos se crearon.
  ///
  /// Lógica de persistencia portada de `attendance_service.markAbsentStudents`,
  /// corrigiendo la ruta (subcolección en vez de la colección raíz `attendance`),
  /// el `date` (string `dateKey` en vez de Timestamp) y el docId (determinístico
  /// en vez de auto-id, que sí permitía duplicados).
  Future<int> markAbsentStudentsForDay({
    required String classroomId,
    required List<String> activeStudentIds,
    Map<String, String>? studentNames,
    DateTime? day,
  }) async {
    final now = day ?? DateTime.now();
    final dateKey = _dateKey(now);

    // Asistencias ya registradas hoy (cualquier estado) → no se tocan.
    final existing = await _classroomAttendance(classroomId)
        .where('date', isEqualTo: dateKey)
        .get();
    final recorded = existing.docs
        .map((d) => (d.data()['studentId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    final batch = _db.batch();
    int created = 0;
    for (final studentId in activeStudentIds) {
      if (studentId.isEmpty || recorded.contains(studentId)) continue;
      final ref = _classroomAttendance(classroomId).doc('${studentId}_$dateKey');
      batch.set(ref, {
        'classroomId': classroomId,
        'studentId': studentId,
        'status': _legacyStatus(AttendanceStatus.ausente),
        'timestamp': FieldValue.serverTimestamp(),
        'date': dateKey,
        'source': 'auto_absent',
        if (studentNames != null && studentNames[studentId] != null)
          'studentName': studentNames[studentId],
      });
      created++;
    }
    if (created > 0) await batch.commit();
    return created;
  }
}

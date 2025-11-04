import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum para el estado de asistencia
enum AttendanceStatus {
  present('presente', '✅ Presente'),
  absent('ausente', '❌ Ausente'),
  late('tardanza', '⏰ Tardanza'),
  justified('justificado', '📋 Justificado');

  const AttendanceStatus(this.value, this.displayName);
  final String value;
  final String displayName;

  static AttendanceStatus fromString(String status) {
    return AttendanceStatus.values.firstWhere(
      (e) => e.value == status,
      orElse: () => AttendanceStatus.absent,
    );
  }
}

/// Modelo para registros de asistencia
class AttendanceModel {
  final String? id;
  final String studentId;
  final String studentName;
  final String studentDni;
  final String classroomId;
  final String classroomName;
  final String teacherUid;
  final String teacherName;
  final DateTime date;
  final DateTime recordedAt;
  final AttendanceStatus status;
  final String? notes;
  final String? qrCodeScanned; // QR del estudiante escaneado
  final Map<String, dynamic>? metadata; // Info adicional como ubicación, etc.
  final String? source; // Origen del registro (qr, manual, auto, etc.)

  AttendanceModel({
    this.id,
    required this.studentId,
    required this.studentName,
    required this.studentDni,
    required this.classroomId,
    required this.classroomName,
    required this.teacherUid,
    required this.teacherName,
    required this.date,
    required this.recordedAt,
    required this.status,
    this.notes,
    this.qrCodeScanned,
    this.metadata,
    this.source,
  });

  /// Crear desde Firebase Document
  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      studentDni: data['studentDni'] ?? '',
      classroomId: data['classroomId'] ?? '',
      classroomName: data['classroomName'] ?? '',
      teacherUid: data['teacherUid'] ?? '',
      teacherName: data['teacherName'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recordedAt:
          (data['recordedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: AttendanceStatus.fromString(data['status'] ?? 'ausente'),
      notes: data['notes'],
      qrCodeScanned: data['qrCodeScanned'],
      metadata: data['metadata'] as Map<String, dynamic>?,
      source: data['source'] as String?,
    );
  }

  /// Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentDni': studentDni,
      'classroomId': classroomId,
      'classroomName': classroomName,
      'teacherUid': teacherUid,
      'teacherName': teacherName,
      'date': Timestamp.fromDate(date),
      'recordedAt': Timestamp.fromDate(recordedAt),
      'status': status.value,
      'notes': notes,
      'qrCodeScanned': qrCodeScanned,
      'metadata': metadata,
      'source': source,
    };
  }

  /// Crear copia con cambios
  AttendanceModel copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? studentDni,
    String? classroomId,
    String? classroomName,
    String? teacherUid,
    String? teacherName,
    DateTime? date,
    DateTime? recordedAt,
    AttendanceStatus? status,
    String? notes,
    String? qrCodeScanned,
    Map<String, dynamic>? metadata,
    String? source,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentDni: studentDni ?? this.studentDni,
      classroomId: classroomId ?? this.classroomId,
      classroomName: classroomName ?? this.classroomName,
      teacherUid: teacherUid ?? this.teacherUid,
      teacherName: teacherName ?? this.teacherName,
      date: date ?? this.date,
      recordedAt: recordedAt ?? this.recordedAt,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      qrCodeScanned: qrCodeScanned ?? this.qrCodeScanned,
      metadata: metadata ?? this.metadata,
      source: source ?? this.source,
    );
  }

  /// Generar clave única para el día (para evitar duplicados)
  String get uniqueKey => '${studentId}_${_formatDateKey(date)}';

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'AttendanceModel(id: $id, studentName: $studentName, date: $date, status: ${status.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttendanceModel &&
        other.studentId == studentId &&
        other.date.day == date.day &&
        other.date.month == date.month &&
        other.date.year == date.year;
  }

  @override
  int get hashCode => Object.hash(studentId, date.day, date.month, date.year);
}

/// Modelo para estadísticas de asistencia
class AttendanceStats {
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int justifiedCount;
  final double attendancePercentage;
  final DateTime date;

  AttendanceStats({
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.justifiedCount,
    required this.date,
  }) : attendancePercentage = totalStudents > 0
           ? (presentCount / totalStudents) * 100
           : 0.0;

  /// Crear desde conteos
  factory AttendanceStats.fromCounts({
    required int totalStudents,
    required List<AttendanceModel> attendances,
    required DateTime date,
  }) {
    int presentCount = 0;
    int absentCount = 0;
    int lateCount = 0;
    int justifiedCount = 0;

    for (final attendance in attendances) {
      switch (attendance.status) {
        case AttendanceStatus.present:
          presentCount++;
          break;
        case AttendanceStatus.absent:
          absentCount++;
          break;
        case AttendanceStatus.late:
          lateCount++;
          break;
        case AttendanceStatus.justified:
          justifiedCount++;
          break;
      }
    }

    return AttendanceStats(
      totalStudents: totalStudents,
      presentCount: presentCount,
      absentCount: absentCount,
      lateCount: lateCount,
      justifiedCount: justifiedCount,
      date: date,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalStudents': totalStudents,
      'presentCount': presentCount,
      'absentCount': absentCount,
      'lateCount': lateCount,
      'justifiedCount': justifiedCount,
      'attendancePercentage': attendancePercentage,
      'date': Timestamp.fromDate(date),
    };
  }
}

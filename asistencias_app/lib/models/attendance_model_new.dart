import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de estado de asistencia
enum AttendanceStatus {
  present('presente'),
  absent('ausente'),
  late('tardanza');

  const AttendanceStatus(this.displayName);
  final String displayName;
}

/// Modelo para el registro de asistencias
class AttendanceModel {
  final String? id;
  final String studentId;
  final String classroomId;
  final String teacherUid;
  final DateTime date;
  final DateTime timestamp;
  final AttendanceStatus status;
  final String? notes;

  AttendanceModel({
    this.id,
    required this.studentId,
    required this.classroomId,
    required this.teacherUid,
    required this.date,
    required this.timestamp,
    required this.status,
    this.notes,
  });

  /// Crear desde Firebase Document
  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      classroomId: data['classroomId'] ?? '',
      teacherUid: data['teacherUid'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: AttendanceStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => AttendanceStatus.present,
      ),
      notes: data['notes'],
    );
  }

  /// Crear desde Map (para FirestoreService)
  factory AttendanceModel.fromMap(Map<String, dynamic> data) {
    return AttendanceModel(
      id: data['id'],
      studentId: data['studentId'] ?? '',
      classroomId: data['classroomId'] ?? '',
      teacherUid: data['teacherUid'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: AttendanceStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => AttendanceStatus.present,
      ),
      notes: data['notes'],
    );
  }

  /// Convertir a Map para Firebase
  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'classroomId': classroomId,
      'teacherUid': teacherUid,
      'date': Timestamp.fromDate(date),
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status.name,
      'notes': notes,
    };
  }

  /// Crear copia con cambios
  AttendanceModel copyWith({
    String? id,
    String? studentId,
    String? classroomId,
    String? teacherUid,
    DateTime? date,
    DateTime? timestamp,
    AttendanceStatus? status,
    String? notes,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      classroomId: classroomId ?? this.classroomId,
      teacherUid: teacherUid ?? this.teacherUid,
      date: date ?? this.date,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'AttendanceModel(id: $id, student: $studentId, status: ${status.displayName}, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttendanceModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

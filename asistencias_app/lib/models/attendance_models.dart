import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado de asistencia por estudiante
enum AttendanceStatus { presente, tarde, ausente }

AttendanceStatus statusFromString(String value) {
  switch (value.toLowerCase()) {
    case 'presente':
      return AttendanceStatus.presente;
    case 'tarde':
      return AttendanceStatus.tarde;
    case 'ausente':
      return AttendanceStatus.ausente;
    default:
      return AttendanceStatus.presente;
  }
}

String statusToString(AttendanceStatus status) {
  switch (status) {
    case AttendanceStatus.presente:
      return 'presente';
    case AttendanceStatus.tarde:
      return 'tarde';
    case AttendanceStatus.ausente:
      return 'ausente';
  }
}

/// Entrada de asistencia dentro de una sesión
class AttendanceEntry {
  final String studentId;
  final AttendanceStatus status;
  final DateTime timestamp;
  final String? studentName;

  AttendanceEntry({
    required this.studentId,
    required this.status,
    required this.timestamp,
    this.studentName,
  });

  Map<String, dynamic> toMap() => {
    'studentId': studentId,
    'status': statusToString(status),
    'timestamp': Timestamp.fromDate(timestamp),
    if (studentName != null) 'studentName': studentName,
  };

  factory AttendanceEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AttendanceEntry(
      studentId: data['studentId'] ?? doc.id,
      status: statusFromString(data['status'] ?? 'presente'),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      studentName: data['studentName'],
    );
  }
}

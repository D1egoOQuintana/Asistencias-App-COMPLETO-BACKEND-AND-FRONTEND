import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/attendance_model.dart';
import '../models/student_model.dart';
import '../models/classroom_model.dart';

class AttendanceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> _classroomAttendance(
    String classroomId,
  ) => _firestore
      .collection('classrooms')
      .doc(classroomId)
      .collection('attendance');

  /// Registrar asistencia de un estudiante
  static Future<Map<String, dynamic>> recordAttendance({
    required String studentId,
    required AttendanceStatus status,
    String? notes,
    String? qrCodeScanned,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {'success': false, 'message': 'Usuario no autenticado'};
      }

      // Obtener información del estudiante
      final studentDoc = await _firestore
          .collection('students')
          .doc(studentId)
          .get();
      if (!studentDoc.exists) {
        return {'success': false, 'message': 'Estudiante no encontrado'};
      }

      final student = StudentModel.fromFirestore(studentDoc);

      // Obtener información del salón
      final classroomDoc = await _firestore
          .collection('classrooms')
          .doc(student.classroomId)
          .get();
      if (!classroomDoc.exists) {
        return {'success': false, 'message': 'Salón no encontrado'};
      }

      final classroom = ClassroomModel.fromFirestore(classroomDoc);

      // Obtener información del docente
      final teacherDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (!teacherDoc.exists) {
        return {
          'success': false,
          'message': 'Información del docente no encontrada',
        };
      }

      final teacherData = teacherDoc.data() as Map<String, dynamic>;
      final teacherName = teacherData['fullName'] ?? currentUser.email;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Verificar si ya existe asistencia para hoy
        final existingAttendance = await _classroomAttendance(student.classroomId)
          .where('studentId', isEqualTo: studentId)
          .where('date', isEqualTo: Timestamp.fromDate(today))
          .get();

      if (existingAttendance.docs.isNotEmpty) {
        return {
          'success': false,
          'message':
              'Ya existe un registro de asistencia para este estudiante hoy',
          'existingRecord': AttendanceModel.fromFirestore(
            existingAttendance.docs.first,
          ),
        };
      }

      // Crear el registro de asistencia
      final attendance = AttendanceModel(
        studentId: studentId,
        studentName: '${student.firstName} ${student.lastName}',
        studentDni: student.dni,
        classroomId: student.classroomId,
        classroomName: '${classroom.grade} - ${classroom.section}',
        teacherUid: currentUser.uid,
        teacherName: teacherName,
        date: today,
        recordedAt: now,
        status: status,
        notes: notes,
        qrCodeScanned: qrCodeScanned,
        source: qrCodeScanned != null ? 'qr' : 'manual',
        metadata: {
          'createdFrom': qrCodeScanned != null ? 'qr_scan' : 'manual_form',
        },
      );

      // Guardar en Firestore
        final docRef = await _classroomAttendance(student.classroomId)
          .add(attendance.toMap());

      return {
        'success': true,
        'message': 'Asistencia registrada exitosamente',
        'attendanceId': docRef.id,
        'attendance': attendance.copyWith(id: docRef.id),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al registrar asistencia: ${e.toString()}',
      };
    }
  }

  /// Registrar asistencia por código QR
  static Future<Map<String, dynamic>> recordAttendanceByQR({
    required String qrCode,
    required AttendanceStatus status,
    String? notes,
  }) async {
    try {
      // Buscar estudiante por código QR
      final studentQuery = await _firestore
          .collection('students')
          .where('qrCode', isEqualTo: qrCode)
          .where('isActive', isEqualTo: true)
          .get();

      if (studentQuery.docs.isEmpty) {
        return {
          'success': false,
          'message': 'No se encontró estudiante con este código QR',
        };
      }

      final studentDoc = studentQuery.docs.first;
      return await recordAttendance(
        studentId: studentDoc.id,
        status: status,
        notes: notes,
        qrCodeScanned: qrCode,
      );
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al procesar código QR: ${e.toString()}',
      };
    }
  }

  /// Obtener asistencias por fecha y salón
  static Stream<QuerySnapshot> getAttendanceByDateAndClassroom({
    required String classroomId,
    required DateTime date,
  }) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _firestore
      .collection('classrooms')
      .doc(classroomId)
      .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
        .orderBy('date')
        .orderBy('recordedAt')
        .snapshots();
  }

  /// Obtener asistencias de un estudiante en un rango de fechas
  static Future<List<AttendanceModel>> getStudentAttendanceHistory({
    required String studentId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final query = await _firestore
          .collectionGroup('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: true)
          .get();

      return query.docs
          .map((doc) => AttendanceModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting student attendance history: $e');
      return [];
    }
  }

  /// Obtener estadísticas de asistencia por salón y fecha
  static Future<AttendanceStats> getAttendanceStats({
    required String classroomId,
    required DateTime date,
  }) async {
    try {
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

      // Obtener total de estudiantes activos en el salón
      final studentsQuery = await _firestore
          .collection('students')
          .where('classroomId', isEqualTo: classroomId)
          .where('isActive', isEqualTo: true)
          .get();

      final totalStudents = studentsQuery.docs.length;

      // Obtener asistencias del día
      final attendanceQuery = await _firestore
          .collection('attendance')
          .where('classroomId', isEqualTo: classroomId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
          .get();

      final attendances = attendanceQuery.docs
          .map((doc) => AttendanceModel.fromFirestore(doc))
          .toList();

      return AttendanceStats.fromCounts(
        totalStudents: totalStudents,
        attendances: attendances,
        date: date,
      );
    } catch (e) {
      print('Error getting attendance stats: $e');
      return AttendanceStats(
        totalStudents: 0,
        presentCount: 0,
        absentCount: 0,
        lateCount: 0,
        justifiedCount: 0,
        date: date,
      );
    }
  }

  /// Obtener asistencias del docente actual
  static Stream<QuerySnapshot> getMyAttendances() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('attendance')
        .where('teacherUid', isEqualTo: currentUser.uid)
        .orderBy('recordedAt', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Obtener resumen de asistencias por mes
  static Future<Map<String, dynamic>> getMonthlyAttendanceSummary({
    required String classroomId,
    required int year,
    required int month,
  }) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0); // Último día del mes

      final query = await _firestore
          .collection('attendance')
          .where('classroomId', isEqualTo: classroomId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final attendances = query.docs
          .map((doc) => AttendanceModel.fromFirestore(doc))
          .toList();

      // Agrupar por día
      final dailyStats = <int, AttendanceStats>{};

      for (final attendance in attendances) {
        final day = attendance.date.day;
        if (!dailyStats.containsKey(day)) {
          // Obtener total de estudiantes para ese día
          final studentsQuery = await _firestore
              .collection('students')
              .where('classroomId', isEqualTo: classroomId)
              .where('isActive', isEqualTo: true)
              .get();

          final dayAttendances = attendances
              .where((a) => a.date.day == day)
              .toList();

          dailyStats[day] = AttendanceStats.fromCounts(
            totalStudents: studentsQuery.docs.length,
            attendances: dayAttendances,
            date: DateTime(year, month, day),
          );
        }
      }

      return {
        'success': true,
        'dailyStats': dailyStats,
        'totalDays': dailyStats.length,
        'averageAttendance': dailyStats.values.isEmpty
            ? 0.0
            : dailyStats.values
                      .map((s) => s.attendancePercentage)
                      .reduce((a, b) => a + b) /
                  dailyStats.length,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al obtener resumen mensual: $e',
        'dailyStats': <int, AttendanceStats>{},
        'totalDays': 0,
        'averageAttendance': 0.0,
      };
    }
  }

  /// Marcar estudiantes ausentes automáticamente
  static Future<Map<String, dynamic>> markAbsentStudents({
    required String classroomId,
    required DateTime date,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {'success': false, 'message': 'Usuario no autenticado'};
      }

      final dayStart = DateTime(date.year, date.month, date.day);

      // Obtener todos los estudiantes activos del salón
      final studentsQuery = await _firestore
          .collection('students')
          .where('classroomId', isEqualTo: classroomId)
          .where('isActive', isEqualTo: true)
          .get();

      // Obtener asistencias ya registradas para hoy
      final attendanceQuery = await _firestore
          .collection('attendance')
          .where('classroomId', isEqualTo: classroomId)
          .where('date', isEqualTo: Timestamp.fromDate(dayStart))
          .get();

      final recordedStudentIds = attendanceQuery.docs
          .map((doc) => doc.data()['studentId'] as String)
          .toSet();

      // Obtener información del salón y docente
      final classroomDoc = await _firestore
          .collection('classrooms')
          .doc(classroomId)
          .get();
      final classroom = ClassroomModel.fromFirestore(classroomDoc);

      final teacherDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final teacherData = teacherDoc.data() as Map<String, dynamic>;
      final teacherName = teacherData['fullName'] ?? currentUser.email;

      // Marcar como ausentes a los estudiantes sin registro
      final batch = _firestore.batch();
      int absentCount = 0;

      for (final studentDoc in studentsQuery.docs) {
        if (!recordedStudentIds.contains(studentDoc.id)) {
          final student = StudentModel.fromFirestore(studentDoc);

          final attendance = AttendanceModel(
            studentId: studentDoc.id,
            studentName: '${student.firstName} ${student.lastName}',
            studentDni: student.dni,
            classroomId: classroomId,
            classroomName: '${classroom.grade} - ${classroom.section}',
            teacherUid: currentUser.uid,
            teacherName: teacherName,
            date: dayStart,
            recordedAt: DateTime.now(),
            status: AttendanceStatus.absent,
            notes: 'Marcado automáticamente como ausente',
            source: 'auto_absent',
          );

          final docRef = _firestore.collection('attendance').doc();
          batch.set(docRef, attendance.toMap());
          absentCount++;
        }
      }

      await batch.commit();

      return {
        'success': true,
        'message': 'Se marcaron $absentCount estudiantes como ausentes',
        'absentCount': absentCount,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al marcar ausentes: ${e.toString()}',
      };
    }
  }
}

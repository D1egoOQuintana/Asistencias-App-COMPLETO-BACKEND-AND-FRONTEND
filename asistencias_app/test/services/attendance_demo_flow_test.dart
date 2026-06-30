import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asistencias_app/models/attendance_models.dart';
import 'package:asistencias_app/services/attendance_repository.dart';

/// Validación del flujo de demo (tardanza automática) sobre el "Aula Demo
/// Entrevista". Reproduce la MISMA decisión que toma la pantalla viva
/// `qr_attendance_realtime.dart`: calcula el timing con
/// `evaluateAttendanceTiming` y solo registra si no está fuera de horario.
void main() {
  const classroomId = 'demo-entrevista';
  const studentId = 'alumno-demo-1';

  // Horario del Aula Demo Entrevista (lunes): 08:00 - 09:30, tarde > 08:15.
  const maxLate = '08:15';
  const end = '09:30';

  // Espejo del mapeo presente/tarde que hace la pantalla viva.
  AttendanceStatus statusFromTiming(AttendanceTiming t) =>
      t == AttendanceTiming.late
          ? AttendanceStatus.tarde
          : AttendanceStatus.presente;

  Future<String?> simulateScan(
    AttendanceRepository repo,
    DateTime now,
  ) async {
    final timing = evaluateAttendanceTiming(
      maxLateTime: maxLate,
      endTime: end,
      now: now,
    );
    // La pantalla NO registra cuando está fuera de horario.
    if (timing == AttendanceTiming.outsideSchedule) return null;
    await repo.registerQrScanForDay(
      classroomId: classroomId,
      studentId: studentId,
      status: statusFromTiming(timing),
      studentName: 'Alumno Demo',
      when: now,
    );
    return timing == AttendanceTiming.late ? 'late' : 'present';
  }

  Future<Map<String, dynamic>?> readDoc(FakeFirebaseFirestore db) async {
    final doc = await db
        .collection('classrooms')
        .doc(classroomId)
        .collection('attendance')
        .doc('${studentId}_2026-03-30')
        .get();
    return doc.exists ? doc.data() : null;
  }

  test('CASO 1: escaneo 08:10 (<= maxLateTime) => presente', () async {
    final db = FakeFirebaseFirestore();
    final repo = AttendanceRepository(firestore: db);

    final result = await simulateScan(repo, DateTime(2026, 3, 30, 8, 10));

    expect(result, 'present');
    final data = await readDoc(db);
    expect(data, isNotNull);
    expect(data!['status'], 'present');
  });

  test('CASO 2: escaneo 08:20 (entre maxLateTime y endTime) => tarde',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = AttendanceRepository(firestore: db);

    final result = await simulateScan(repo, DateTime(2026, 3, 30, 8, 20));

    expect(result, 'late');
    final data = await readDoc(db);
    expect(data, isNotNull);
    expect(data!['status'], 'late');
  });

  test('CASO 3: escaneo 09:40 (> endTime) => fuera de horario, NO registra',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = AttendanceRepository(firestore: db);

    final result = await simulateScan(repo, DateTime(2026, 3, 30, 9, 40));

    expect(result, isNull); // no se registró
    final data = await readDoc(db);
    expect(data, isNull); // no existe documento de asistencia
  });

  test('SALIDA: segundo escaneo registra salida en el mismo documento',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = AttendanceRepository(firestore: db);

    await simulateScan(repo, DateTime(2026, 3, 30, 8, 10)); // entrada
    await simulateScan(repo, DateTime(2026, 3, 30, 8, 25)); // salida

    final data = await readDoc(db);
    expect(data, isNotNull);
    expect(data!['exitAt'], isNotNull);
    expect(data['exitSource'], 'qr');
  });

  test('SIN DUPLICADOS: 3 escaneos => 1 solo documento del día', () async {
    final db = FakeFirebaseFirestore();
    final repo = AttendanceRepository(firestore: db);

    await simulateScan(repo, DateTime(2026, 3, 30, 8, 10)); // entrada
    await simulateScan(repo, DateTime(2026, 3, 30, 8, 25)); // salida
    await simulateScan(repo, DateTime(2026, 3, 30, 8, 40)); // ya salió: no-op

    final snap = await db
        .collection('classrooms')
        .doc(classroomId)
        .collection('attendance')
        .get();
    expect(snap.docs.length, 1);
  });
}

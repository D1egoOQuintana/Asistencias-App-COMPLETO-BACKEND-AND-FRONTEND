import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asistencias_app/models/attendance_models.dart';
import 'package:asistencias_app/services/attendance_repository.dart';

void main() {
  group('AttendanceRepository root attendance flow', () {
    test('first QR scan stores entry in attendance root collection', () async {
      final fakeDb = FakeFirebaseFirestore();
      final repo = AttendanceRepository(firestore: fakeDb);
      final when = DateTime(2026, 3, 30, 8, 15, 0);

      final result = await repo.registerQrScanForDay(
        classroomId: 'classroom-A',
        studentId: 'student-1',
        studentName: 'Alumno Uno',
        status: AttendanceStatus.presente,
        when: when,
      );

      expect(result.type, QrScanResultType.entryRegistered);

      final dateKey = '2026-03-30';
      final doc = await fakeDb.collection('attendance').doc('student-1_$dateKey').get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['classroomId'], 'classroom-A');
      expect(data['studentId'], 'student-1');
      expect(data['status'], 'present');
      expect(data['date'], dateKey);
      expect(data['entryAt'], isNotNull);
    });

    test('second QR scan stores exit in same attendance document', () async {
      final fakeDb = FakeFirebaseFirestore();
      final repo = AttendanceRepository(firestore: fakeDb);
      final when = DateTime(2026, 3, 30, 8, 15, 0);

      await repo.registerQrScanForDay(
        classroomId: 'classroom-A',
        studentId: 'student-1',
        studentName: 'Alumno Uno',
        status: AttendanceStatus.presente,
        when: when,
      );

      final result = await repo.registerQrScanForDay(
        classroomId: 'classroom-A',
        studentId: 'student-1',
        studentName: 'Alumno Uno',
        status: AttendanceStatus.presente,
        when: when.add(const Duration(minutes: 10)),
      );

      expect(result.type, QrScanResultType.exitRegistered);

      final dateKey = '2026-03-30';
      final doc = await fakeDb.collection('attendance').doc('student-1_$dateKey').get();
      final data = doc.data()!;
      expect(data['exitAt'], isNotNull);
      expect(data['exitSource'], 'qr');
    });
  });
}

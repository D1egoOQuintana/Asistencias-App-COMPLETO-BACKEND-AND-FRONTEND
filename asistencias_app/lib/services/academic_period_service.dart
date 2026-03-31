import 'package:cloud_firestore/cloud_firestore.dart';

class AcademicPeriodService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<Map<String, dynamic>?> getActivePeriod() async {
    final snapshot = await _firestore
        .collection('academic_periods')
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    return {'id': doc.id, ...doc.data()};
  }

  static Future<Map<String, dynamic>> ensureActivePeriod() async {
    final active = await getActivePeriod();
    if (active != null) return active;

    final now = DateTime.now();
    final year = now.year;
    final start = DateTime(year, 1, 1);
    final end = DateTime(year, 12, 31, 23, 59, 59);

    final docRef = await _firestore.collection('academic_periods').add({
      'name': year.toString(),
      'year': year,
      'startDate': Timestamp.fromDate(start),
      'endDate': Timestamp.fromDate(end),
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return {
      'id': docRef.id,
      'name': year.toString(),
      'year': year,
      'status': 'active',
    };
  }

  static Future<Map<String, dynamic>> createNewPeriod({
    required String name,
    required int year,
    required DateTime startDate,
    required DateTime endDate,
    bool closeCurrent = false,
  }) async {
    if (closeCurrent) {
      final active = await getActivePeriod();
      if (active != null) {
        await _firestore.collection('academic_periods').doc(active['id']).update({
          'status': 'closed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    final docRef = await _firestore.collection('academic_periods').add({
      'name': name,
      'year': year,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return {
      'id': docRef.id,
      'name': name,
      'year': year,
      'status': 'active',
    };
  }

  static Future<bool> closeActivePeriodAndArchiveClassrooms() async {
    try {
      final active = await getActivePeriod();
      if (active == null) return false;

      final activeId = active['id'] as String;

      await _firestore.collection('academic_periods').doc(activeId).update({
        'status': 'closed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final classrooms = await _firestore
          .collection('classrooms')
          .where('periodId', isEqualTo: activeId)
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (final doc in classrooms.docs) {
        batch.update(doc.reference, {
          'isActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
          'archivedByPeriodClose': true,
        });
      }
      await batch.commit();

      return true;
    } catch (_) {
      return false;
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> periodsStream() {
    return _firestore
        .collection('academic_periods')
        .orderBy('year', descending: true)
        .snapshots();
  }
}

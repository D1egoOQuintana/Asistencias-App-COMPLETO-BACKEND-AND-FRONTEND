import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/classroom_model.dart';
import 'academic_period_service.dart';

class ClassroomService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Crear un nuevo salón/aula.
  ///
  /// `teacherUids` opcional. Si se omite, se deriva como `[teacherUid]` y
  /// `isPolidocente=false`. Si se pasa, el contrato polidocente queda:
  /// teacherUids único, contiene a teacherUid, isPolidocente = length > 1.
  static Future<Map<String, dynamic>> createClassroom({
    required String name,
    required String grade,
    required String section,
    required int capacity,
    String? description,
    String? teacherUid,
    String? teacherName,
    List<String>? teacherUids,
  }) async {
    try {
      // Verificar que el usuario actual sea docente o admin
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {'success': false, 'message': 'Usuario no autenticado'};
      }

      // Verificar si ya existe un salón con el mismo nombre, grado y sección
        final activePeriod = await AcademicPeriodService.ensureActivePeriod();

      final existingClassroom = await _firestore
          .collection('classrooms')
          .where('name', isEqualTo: name)
          .where('grade', isEqualTo: grade)
          .where('section', isEqualTo: section)
          .where('periodId', isEqualTo: activePeriod['id'])
          .where('isActive', isEqualTo: true)
          .get();

      if (existingClassroom.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'Ya existe un salón con ese nombre, grado y sección',
        };
      }

      // Crear el salón
      final effectiveTeacherUid = teacherUid ?? currentUser.uid;
      // Lista efectiva única, garantiza inclusión del principal.
      final effectiveUids = <String>{
        effectiveTeacherUid,
        ...?teacherUids,
      }.toList();
      final classroom = ClassroomModel(
        name: name,
        grade: grade,
        section: section,
        capacity: capacity,
        description: description,
        teacherUid: effectiveTeacherUid,
        teacherUids: effectiveUids,
        isPolidocente: effectiveUids.length > 1,
        teacherName: teacherName,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
        periodId: activePeriod['id']?.toString(),
        periodName: activePeriod['name']?.toString(),
        periodYear: activePeriod['year'] is int
            ? activePeriod['year'] as int
            : int.tryParse('${activePeriod['year']}'),
      );

      // Guardar en Firestore
      final docRef = await _firestore
          .collection('classrooms')
          .add(classroom.toMap());

      return {
        'success': true,
        'message': 'Salón creado exitosamente',
        'classroomId': docRef.id,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al crear salón: ${e.toString()}',
      };
    }
  }

  /// Busca un aula ACTIVA donde el uid dado sea el tutor (teacherUid).
  /// Devuelve `null` si no hay coincidencia.
  ///
  /// [excludeClassroomId] permite ignorar el aula actual cuando se está
  /// editando, para no marcar conflicto contra sí misma.
  ///
  /// Esta validación aplica SOLO al tutor (teacherUid). El auxiliar
  /// (segundo uid en teacherUids) puede repetirse en varias aulas.
  static Future<ClassroomModel?> findActiveClassroomByTutor(
    String tutorUid, {
    String? excludeClassroomId,
  }) async {
    if (tutorUid.trim().isEmpty) return null;
    final snap = await _firestore
        .collection('classrooms')
        .where('teacherUid', isEqualTo: tutorUid)
        .where('isActive', isEqualTo: true)
        .limit(2) // 2 para detectar conflicto incluso si excluimos uno
        .get();
    for (final doc in snap.docs) {
      if (doc.id == excludeClassroomId) continue;
      return ClassroomModel.fromFirestore(doc);
    }
    return null;
  }

  /// Obtener salones por docente
  static Stream<QuerySnapshot> getClassroomsByTeacher(String teacherUid) {
    try {
      return _firestore
          .collection('classrooms')
          .where('teacherUid', isEqualTo: teacherUid)
          .where('isActive', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .handleError((error) {
            print(
              'DEBUG: Error in getClassroomsByTeacher with orderBy: $error',
            );
            // Si falla con orderBy, intentar sin él
            return _firestore
                .collection('classrooms')
                .where('teacherUid', isEqualTo: teacherUid)
                .where('isActive', isEqualTo: true)
                .snapshots();
          });
    } catch (e) {
      print('DEBUG: Exception in getClassroomsByTeacher: $e');
      // Fallback sin orderBy
      return _firestore
          .collection('classrooms')
          .where('teacherUid', isEqualTo: teacherUid)
          .where('isActive', isEqualTo: true)
          .snapshots();
    }
  }

  /// Método alternativo sin orderBy (más seguro)
  static Stream<QuerySnapshot> getClassroomsByTeacherSimple(String teacherUid) {
    return _firestore
        .collection('classrooms')
        .where('teacherUid', isEqualTo: teacherUid)
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  /// Obtener todos los salones (solo admin)
  static Stream<QuerySnapshot> getAllClassrooms() {
    return _firestore
        .collection('classrooms')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getAllClassroomsByPeriod(String periodId) {
    return _firestore
        .collection('classrooms')
        .where('periodId', isEqualTo: periodId)
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  /// Actualizar salón.
  ///
  /// `teacherUids` opcional: si se omite y se pasa `teacherUid`, se asume
  /// no polidocente y se sincroniza como `[teacherUid]`. Si se pasa la lista,
  /// se garantiza unicidad y que el principal esté incluido.
  static Future<bool> updateClassroom({
    required String classroomId,
    required String name,
    required String grade,
    required String section,
    required int capacity,
    String? description,
    String? teacherUid,
    String? teacherName,
    List<String>? teacherUids,
  }) async {
    try {
      final update = <String, dynamic>{
        'name': name,
        'grade': grade,
        'section': section,
        'capacity': capacity,
        'description': description,
        'teacherUid': teacherUid,
        'teacherName': teacherName,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };
      if (teacherUid != null && teacherUid.isNotEmpty) {
        final effective = <String>{
          teacherUid,
          ...?teacherUids,
        }.toList();
        update['teacherUids'] = effective;
        update['isPolidocente'] = effective.length > 1;
      }
      await _firestore.collection('classrooms').doc(classroomId).update(update);
      return true;
    } catch (e) {
      print('Error updating classroom: $e');
      return false;
    }
  }

  /// Desactivar salón (soft delete)
  static Future<bool> deactivateClassroom(String classroomId) async {
    try {
      await _firestore.collection('classrooms').doc(classroomId).update({
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      print('Error deactivating classroom: $e');
      return false;
    }
  }

  /// Reactivar salón
  static Future<bool> reactivateClassroom(String classroomId) async {
    try {
      await _firestore.collection('classrooms').doc(classroomId).update({
        'isActive': true,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      print('Error reactivating classroom: $e');
      return false;
    }
  }

  /// Obtener salón por ID
  static Future<ClassroomModel?> getClassroomById(String classroomId) async {
    try {
      final doc = await _firestore
          .collection('classrooms')
          .doc(classroomId)
          .get();
      if (doc.exists) {
        return ClassroomModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting classroom: $e');
      return null;
    }
  }

  /// Buscar salones por nombre, grado o sección
  static Future<List<ClassroomModel>> searchClassrooms(String query) async {
    try {
      final queryLower = query.toLowerCase();

      // Buscar por nombre
      final nameQuery = await _firestore
          .collection('classrooms')
          .where('name', isGreaterThanOrEqualTo: queryLower)
          .where('name', isLessThan: '${queryLower}z')
          .where('isActive', isEqualTo: true)
          .get();

      // Buscar por grado
      final gradeQuery = await _firestore
          .collection('classrooms')
          .where('grade', isEqualTo: query)
          .where('isActive', isEqualTo: true)
          .get();

      // Buscar por sección
      final sectionQuery = await _firestore
          .collection('classrooms')
          .where('section', isEqualTo: queryLower)
          .where('isActive', isEqualTo: true)
          .get();

      // Combinar resultados y eliminar duplicados
      final classrooms = <ClassroomModel>[];
      final addedIds = <String>{};

      for (final doc in [
        ...nameQuery.docs,
        ...gradeQuery.docs,
        ...sectionQuery.docs,
      ]) {
        if (!addedIds.contains(doc.id)) {
          classrooms.add(ClassroomModel.fromFirestore(doc));
          addedIds.add(doc.id);
        }
      }

      return classrooms;
    } catch (e) {
      print('Error searching classrooms: $e');
      return [];
    }
  }

  /// Asignar docente a salón
  static Future<bool> assignTeacherToClassroom({
    required String classroomId,
    required String teacherUid,
    required String teacherName,
  }) async {
    try {
      await _firestore.collection('classrooms').doc(classroomId).update({
        'teacherUid': teacherUid,
        'teacherUids': [teacherUid],
        'teacherName': teacherName,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      print('Error assigning teacher to classroom: $e');
      return false;
    }
  }

  /// Obtener estadísticas de salones
  static Future<Map<String, int>> getClassroomStats() async {
    try {
      final allClassrooms = await _firestore.collection('classrooms').get();

      final activeClassrooms = await _firestore
          .collection('classrooms')
          .where('isActive', isEqualTo: true)
          .get();

      // Contar estudiantes por salón
      int totalStudents = 0;
      for (final classroom in activeClassrooms.docs) {
        final students = await _firestore
            .collection('students')
            .where('classroomId', isEqualTo: classroom.id)
            .where('isActive', isEqualTo: true)
            .get();
        totalStudents += students.docs.length;
      }

      return {
        'total': allClassrooms.docs.length,
        'active': activeClassrooms.docs.length,
        'inactive': allClassrooms.docs.length - activeClassrooms.docs.length,
        'totalStudents': totalStudents,
      };
    } catch (e) {
      print('Error getting classroom stats: $e');
      return {'total': 0, 'active': 0, 'inactive': 0, 'totalStudents': 0};
    }
  }

  /// Obtener salones disponibles (sin asignar o del docente actual)
  static Stream<QuerySnapshot> getAvailableClassrooms(
    String currentTeacherUid,
  ) {
    return _firestore
        .collection('classrooms')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }
}

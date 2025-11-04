import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseInitializer {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Inicializar todas las colecciones con datos de ejemplo
  static Future<void> initializeDatabase() async {
    try {
      print('🚀 Iniciando configuración de base de datos...');

      // 1. Crear usuarios administradores y docentes
      await _createUsers();

      // 2. Crear aulas
      await _createClassrooms();

      // 3. Crear estudiantes
      await _createStudents();

      // 4. Crear registros de asistencia de ejemplo
      await _createSampleAttendance();

      print('✅ Base de datos inicializada correctamente');
    } catch (e) {
      print('❌ Error al inicializar base de datos: $e');
      rethrow;
    }
  }

  /// Crear usuarios de ejemplo
  static Future<void> _createUsers() async {
    print('👥 Creando usuarios...');

    final users = [
      // Administrador
      {
        'uid': 'admin-001',
        'email': 'admin@escuela.com',
        'firstName': 'María',
        'lastName': 'González',
        'role': 'admin',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },

      // Docentes
      {
        'uid': 'teacher-001',
        'email': 'carlos.martinez@escuela.com',
        'firstName': 'Carlos',
        'lastName': 'Martínez',
        'role': 'docente',
        'subject': 'Matemáticas',
        'phone': '+51987654321',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },

      {
        'uid': 'teacher-002',
        'email': 'ana.lopez@escuela.com',
        'firstName': 'Ana',
        'lastName': 'López',
        'role': 'docente',
        'subject': 'Comunicación',
        'phone': '+51987654322',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },

      {
        'uid': 'teacher-003',
        'email': 'pedro.silva@escuela.com',
        'firstName': 'Pedro',
        'lastName': 'Silva',
        'role': 'docente',
        'subject': 'Ciencias',
        'phone': '+51987654323',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    ];

    for (final userData in users) {
      await _firestore
          .collection('users')
          .doc(userData['uid'] as String)
          .set(userData);
    }

    print('✅ ${users.length} usuarios creados');
  }

  /// Crear aulas de ejemplo
  static Future<void> _createClassrooms() async {
    print('🏫 Creando aulas...');

    final classrooms = [
      {
        'name': 'Primero A',
        'section': 'A',
        'grade': '1ro',
        'capacity': 25,
        'teacherUid': 'teacher-001',
        'teacherName': 'Carlos Martínez',
        'description': 'Aula de primer grado, sección A',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },

      {
        'name': 'Segundo B',
        'section': 'B',
        'grade': '2do',
        'capacity': 30,
        'teacherUid': 'teacher-002',
        'teacherName': 'Ana López',
        'description': 'Aula de segundo grado, sección B',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },

      {
        'name': 'Tercero A',
        'section': 'A',
        'grade': '3ro',
        'capacity': 28,
        'teacherUid': 'teacher-003',
        'teacherName': 'Pedro Silva',
        'description': 'Aula de tercer grado, sección A',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    ];

    for (final classroomData in classrooms) {
      await _firestore.collection('classrooms').add(classroomData);
    }

    print('✅ ${classrooms.length} aulas creadas');
  }

  /// Crear estudiantes de ejemplo
  static Future<void> _createStudents() async {
    print('👨‍🎓 Creando estudiantes...');

    // Obtener las aulas creadas para asignar estudiantes
    final classroomsSnapshot = await _firestore.collection('classrooms').get();
    final classrooms = classroomsSnapshot.docs;

    if (classrooms.isEmpty) {
      print('⚠️ No hay aulas disponibles, creando estudiantes sin asignar');
      return;
    }

    final students = [
      // Estudiantes para Primero A
      {
        'firstName': 'Juan',
        'lastName': 'Pérez',
        'dni': '12345678',
        'qrCode': 'STU_001_${DateTime.now().millisecondsSinceEpoch}',
        'classroomId': classrooms[0].id,
        'parentEmail': 'juan.perez.padre@gmail.com',
        'parentPhone': '+51987111111',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },

      {
        'firstName': 'María',
        'lastName': 'García',
        'dni': '23456789',
        'qrCode': 'STU_002_${DateTime.now().millisecondsSinceEpoch}',
        'classroomId': classrooms[0].id,
        'parentEmail': 'maria.garcia.padre@gmail.com',
        'parentPhone': '+51987222222',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },

      {
        'firstName': 'Carlos',
        'lastName': 'López',
        'dni': '34567890',
        'qrCode': 'STU_003_${DateTime.now().millisecondsSinceEpoch}',
        'classroomId': classrooms[0].id,
        'parentEmail': 'carlos.lopez.padre@gmail.com',
        'parentPhone': '+51987333333',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },

      // Estudiantes para Segundo B
      {
        'firstName': 'Ana',
        'lastName': 'Martínez',
        'dni': '45678901',
        'qrCode': 'STU_004_${DateTime.now().millisecondsSinceEpoch}',
        'classroomId': classrooms[1].id,
        'parentEmail': 'ana.martinez.padre@gmail.com',
        'parentPhone': '+51987444444',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },

      {
        'firstName': 'Luis',
        'lastName': 'Rodríguez',
        'dni': '56789012',
        'qrCode': 'STU_005_${DateTime.now().millisecondsSinceEpoch}',
        'classroomId': classrooms[1].id,
        'parentEmail': 'luis.rodriguez.padre@gmail.com',
        'parentPhone': '+51987555555',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },

      // Estudiantes para Tercero A
      {
        'firstName': 'Sofía',
        'lastName': 'Fernández',
        'dni': '67890123',
        'qrCode': 'STU_006_${DateTime.now().millisecondsSinceEpoch}',
        'classroomId': classrooms[2].id,
        'parentEmail': 'sofia.fernandez.padre@gmail.com',
        'parentPhone': '+51987666666',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },

      {
        'firstName': 'Diego',
        'lastName': 'Torres',
        'dni': '78901234',
        'qrCode': 'STU_007_${DateTime.now().millisecondsSinceEpoch}',
        'classroomId': classrooms[2].id,
        'parentEmail': 'diego.torres.padre@gmail.com',
        'parentPhone': '+51987777777',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },
    ];

    for (final studentData in students) {
      await _firestore.collection('students').add(studentData);
    }

    print('✅ ${students.length} estudiantes creados');
  }

  /// Crear registros de asistencia de ejemplo
  static Future<void> _createSampleAttendance() async {
    print('📋 Creando registros de asistencia...');

    // Obtener estudiantes y aulas
    final studentsSnapshot = await _firestore.collection('students').get();
    final classroomsSnapshot = await _firestore.collection('classrooms').get();

    if (studentsSnapshot.docs.isEmpty || classroomsSnapshot.docs.isEmpty) {
      print('⚠️ No hay estudiantes o aulas para crear asistencias');
      return;
    }

    final students = studentsSnapshot.docs;
    final classrooms = classroomsSnapshot.docs;

    // Crear asistencias para los últimos 5 días
    final now = DateTime.now();
    final attendanceRecords = <Map<String, dynamic>>[];

    for (int dayOffset = 0; dayOffset < 5; dayOffset++) {
      final date = now.subtract(Duration(days: dayOffset));

      for (final studentDoc in students) {
        final studentData = studentDoc.data();
        final classroomDoc = classrooms.firstWhere(
          (c) => c.id == studentData['classroomId'],
          orElse: () => classrooms.first,
        );
        final classroomData = classroomDoc.data();

        // Simular diferentes estados de asistencia
        final statuses = ['presente', 'ausente', 'tardanza', 'justificado'];
        final randomStatus = statuses[dayOffset % statuses.length];

        attendanceRecords.add({
          'studentId': studentDoc.id,
          'studentName':
              '${studentData['firstName']} ${studentData['lastName']}',
          'studentDni': studentData['dni'],
          'classroomId': classroomDoc.id,
          'classroomName': classroomData['name'],
          'teacherUid': classroomData['teacherUid'],
          'teacherName': classroomData['teacherName'],
          'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
          'recordedAt': Timestamp.fromDate(
            date.add(const Duration(hours: 8, minutes: 15)),
          ),
          'status': randomStatus,
          'notes': randomStatus == 'justificado' ? 'Cita médica' : null,
          'qrCodeScanned': studentData['qrCode'],
          'metadata': {
            'recordedBy': classroomData['teacherUid'],
            'method': 'manual',
          },
        });
      }
    }

    // Insertar en lotes para mejor rendimiento
    final batch = _firestore.batch();
    for (final record in attendanceRecords) {
      final docRef = _firestore.collection('attendance').doc();
      batch.set(docRef, record);
    }

    await batch.commit();
    print('✅ ${attendanceRecords.length} registros de asistencia creados');
  }

  /// Limpiar toda la base de datos (útil para testing)
  static Future<void> clearDatabase() async {
    print('🗑️ Limpiando base de datos...');

    final collections = ['users', 'classrooms', 'students', 'attendance'];

    for (final collection in collections) {
      final snapshot = await _firestore.collection(collection).get();
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('🗑️ Colección $collection limpiada');
    }

    print('✅ Base de datos limpiada completamente');
  }

  /// Verificar el estado de la base de datos
  static Future<void> checkDatabaseStatus() async {
    print('🔍 Verificando estado de la base de datos...');

    final collections = {
      'users': await _firestore.collection('users').get(),
      'classrooms': await _firestore.collection('classrooms').get(),
      'students': await _firestore.collection('students').get(),
      'attendance': await _firestore.collection('attendance').get(),
    };

    for (final entry in collections.entries) {
      print('📊 ${entry.key}: ${entry.value.docs.length} documentos');
    }

    print('✅ Verificación completada');
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo para los horarios de clase
class ClassSchedule {
  final String dayOfWeek; // 'monday', 'tuesday', etc.
  final String startTime; // '08:00'
  final String endTime; // '09:30'
  final String maxLateTime; // '08:15' - máximo tiempo de tardanza

  ClassSchedule({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.maxLateTime,
  });

  factory ClassSchedule.fromMap(Map<String, dynamic> data) {
    return ClassSchedule(
      dayOfWeek: data['dayOfWeek'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      maxLateTime: data['maxLateTime'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'maxLateTime': maxLateTime,
    };
  }
}

/// Modelo para las aulas/salones de clase
class ClassroomModel {
  final String? id;
  final String name;
  final String grade;
  final String section;
  final String? teacherUid;
  final String? teacherName;
  final int capacity;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final Map<String, ClassSchedule>? schedule; // Map con key = dayOfWeek
  final String? periodId;
  final String? periodName;
  final int? periodYear;
  final List<String>? teacherUids;
  final bool isPolidocente;

  ClassroomModel({
    this.id,
    required this.name,
    required this.grade,
    required this.section,
    this.teacherUid,
    this.teacherName,
    required this.capacity,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.schedule,
    this.periodId,
    this.periodName,
    this.periodYear,
    this.teacherUids,
    this.isPolidocente = false,
  });

  /// Crear desde Firebase Document
  factory ClassroomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Procesar schedule si existe
    Map<String, ClassSchedule>? schedule;
    if (data['schedule'] != null) {
      final scheduleData = data['schedule'] as Map<String, dynamic>;
      schedule = scheduleData.map(
        (key, value) =>
            MapEntry(key, ClassSchedule.fromMap(value as Map<String, dynamic>)),
      );
    }

    return ClassroomModel(
      id: doc.id,
      name: data['name'] ?? '',
      grade: data['grade'] ?? '',
      section: data['section'] ?? '',
      teacherUid: data['teacherUid'],
      teacherName: data['teacherName'],
      capacity: data['capacity'] ?? 0,
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      schedule: schedule,
      periodId: data['periodId'],
      periodName: data['periodName'],
      periodYear: data['periodYear'],
      teacherUids: (data['teacherUids'] as List<dynamic>?)?.cast<String>(),
      isPolidocente: data['isPolidocente'] as bool? ?? false,
    );
  }

  /// Crear desde Map (para FirestoreService)
  factory ClassroomModel.fromMap(Map<String, dynamic> data) {
    // Procesar schedule si existe
    Map<String, ClassSchedule>? schedule;
    if (data['schedule'] != null) {
      final scheduleData = data['schedule'] as Map<String, dynamic>;
      schedule = scheduleData.map(
        (key, value) =>
            MapEntry(key, ClassSchedule.fromMap(value as Map<String, dynamic>)),
      );
    }

    return ClassroomModel(
      id: data['id'],
      name: data['name'] ?? '',
      grade: data['grade'] ?? '',
      section: data['section'] ?? '',
      teacherUid: data['teacherUid'],
      teacherName: data['teacherName'],
      capacity: data['capacity'] ?? 0,
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      schedule: schedule,
      periodId: data['periodId'],
      periodName: data['periodName'],
      periodYear: data['periodYear'],
      teacherUids: (data['teacherUids'] as List<dynamic>?)?.cast<String>(),
      isPolidocente: data['isPolidocente'] as bool? ?? false,
    );
  }

  /// Convertir a Map para Firebase
  Map<String, dynamic> toMap() {
    Map<String, dynamic> result = {
      'name': name,
      'grade': grade,
      'section': section,
      'teacherUid': teacherUid,
      'teacherName': teacherName,
      'capacity': capacity,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'periodId': periodId,
      'periodName': periodName,
      'periodYear': periodYear,
    };

    // Agregar schedule si existe
    if (schedule != null) {
      result['schedule'] = schedule!.map(
        (key, value) => MapEntry(key, value.toMap()),
      );
    }

    if (teacherUids != null) result['teacherUids'] = teacherUids;
    result['isPolidocente'] = isPolidocente;

    return result;
  }

  /// Crear copia con cambios
  ClassroomModel copyWith({
    String? id,
    String? name,
    String? grade,
    String? section,
    String? teacherUid,
    String? teacherName,
    int? capacity,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    Map<String, ClassSchedule>? schedule,
    String? periodId,
    String? periodName,
    int? periodYear,
    List<String>? teacherUids,
    bool? isPolidocente,
  }) {
    return ClassroomModel(
      id: id ?? this.id,
      name: name ?? this.name,
      grade: grade ?? this.grade,
      section: section ?? this.section,
      teacherUid: teacherUid ?? this.teacherUid,
      teacherName: teacherName ?? this.teacherName,
      capacity: capacity ?? this.capacity,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      schedule: schedule ?? this.schedule,
      periodId: periodId ?? this.periodId,
      periodName: periodName ?? this.periodName,
      periodYear: periodYear ?? this.periodYear,
      teacherUids: teacherUids ?? this.teacherUids,
      isPolidocente: isPolidocente ?? this.isPolidocente,
    );
  }

  /// Nombre completo del aula
  String get fullName => '$grade$section - $name';

  /// Verificar si tiene docente asignado
  bool get hasTeacher => teacherUid != null && teacherUid!.isNotEmpty;

  /// Verificar si tiene horarios configurados
  bool get hasSchedule => schedule != null && schedule!.isNotEmpty;

  /// Lista efectiva de docentes: teacherUids si existe, fallback a [teacherUid].
  // ponytail: fallback centralizado; cuando existan queries por teacherUids, usar este getter.
  List<String> get effectiveTeacherUids =>
      teacherUids ?? (teacherUid != null ? [teacherUid!] : const []);

  @override
  String toString() {
    return 'ClassroomModel(id: $id, name: $name, grade: $grade, section: $section, teacher: $teacherName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClassroomModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

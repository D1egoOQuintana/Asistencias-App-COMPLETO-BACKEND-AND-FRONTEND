import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  /// Crear desde Firebase Document
  factory ClassroomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
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
    );
  }

  /// Crear desde Map (para FirestoreService)
  factory ClassroomModel.fromMap(Map<String, dynamic> data) {
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
    );
  }

  /// Convertir a Map para Firebase
  Map<String, dynamic> toMap() {
    return {
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
    };
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
    );
  }

  /// Nombre completo del aula
  String get fullName => '$grade$section - $name';

  /// Verificar si tiene docente asignado
  bool get hasTeacher => teacherUid != null && teacherUid!.isNotEmpty;

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

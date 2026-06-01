import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

/// Modelo para los estudiantes/alumnos
class StudentModel {
  final String? id;
  final String firstName;
  final String lastName;
  final String dni;
  final String qrCode;
  final String classroomId;
  final String? parentEmail;
  final String? parentPhone;
  /// chatId de Telegram del apoderado, escrito por el BOT al vincularse.
  /// Solo lectura desde la app (nunca se escribe vía toMap). Sirve para saber
  /// si el apoderado recibirá notificaciones automáticas (entrada/salida/ausencia).
  final dynamic parentTelegramChatId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  StudentModel({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.dni,
    required this.qrCode,
    required this.classroomId,
    this.parentEmail,
    this.parentPhone,
    this.parentTelegramChatId,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  /// Crear desde Firebase Document
  factory StudentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentModel(
      id: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      dni: data['dni'] ?? '',
      qrCode: data['qrCode'] ?? '',
      classroomId: data['classroomId'] ?? '',
      parentEmail: data['parentEmail'],
      parentPhone: data['parentPhone'],
      parentTelegramChatId: data['parentTelegramChatId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  /// Crear desde Map (para FirestoreService)
  factory StudentModel.fromMap(Map<String, dynamic> data) {
    return StudentModel(
      id: data['id'],
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      dni: data['dni'] ?? '',
      qrCode: data['qrCode'] ?? '',
      classroomId: data['classroomId'] ?? '',
      parentEmail: data['parentEmail'],
      parentPhone: data['parentPhone'],
      parentTelegramChatId: data['parentTelegramChatId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  /// Convertir a Map para Firebase
  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'dni': dni,
      'qrCode': qrCode,
      'classroomId': classroomId,
      'parentEmail': parentEmail,
      'parentPhone': parentPhone,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  /// Generar código QR único para el estudiante
  static String generateQRCode() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNumber = random.nextInt(9999);
    return 'STU-$timestamp-$randomNumber';
  }

  /// Nombre completo del estudiante
  String get fullName => '$firstName $lastName';

  /// Crear copia con cambios
  StudentModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? dni,
    String? qrCode,
    String? classroomId,
    String? parentEmail,
    String? parentPhone,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return StudentModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dni: dni ?? this.dni,
      qrCode: qrCode ?? this.qrCode,
      classroomId: classroomId ?? this.classroomId,
      parentEmail: parentEmail ?? this.parentEmail,
      parentPhone: parentPhone ?? this.parentPhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'StudentModel(id: $id, fullName: $fullName, dni: $dni, classroom: $classroomId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Modelo de usuario para la aplicación de asistencias
/// Representa a un docente o administrador autenticado
class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final UserRole role;
  final bool isActive;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.createdAt,
  });

  /// Crear UserModel desde datos de Firestore
  factory UserModel.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      role: UserRole.fromString(data['role'] ?? ''),
      isActive: data['isActive'] ?? false,
      createdAt: data['createdAt']?.toDate(),
    );
  }

  /// Crear UserModel desde Map (para compatibilidad con FirestoreService)
  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      role: UserRole.fromString(data['role'] ?? ''),
      isActive: data['isActive'] ?? false,
      createdAt: data['createdAt']?.toDate(),
    );
  }

  /// Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'fullName': fullName,
      'role': role.value,
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, fullName: $fullName, role: $role)';
  }
}

/// Enum para los roles de usuario en el sistema
enum UserRole {
  admin('admin', 'Administrador'),
  docente('docente', 'Docente');

  const UserRole(this.value, this.displayName);

  final String value;
  final String displayName;

  /// Crear UserRole desde string
  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'docente':
        return UserRole.docente;
      // Compatibilidad con datos donde se usó 'teacher'
      case 'teacher':
        return UserRole.docente;
      default:
        throw ArgumentError('Rol desconocido: $role');
    }
  }
}

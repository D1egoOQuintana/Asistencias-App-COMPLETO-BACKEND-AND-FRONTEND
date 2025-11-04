// Tipos compartidos del sistema

export type UserRole = 'admin' | 'docente' | 'alumno';

export interface AuthenticatedUser {
  uid: string;
  email: string;
  fullName: string;
  role: UserRole;
  isActive: boolean;
}

export interface ApiResponse<T = any> {
  success: boolean;
  message: string;
  data?: T;
}

export interface PaginationParams {
  page?: number;
  limit?: number;
}

export interface TimestampFields {
  createdAt: FirebaseFirestore.Timestamp | Date;
  updatedAt: FirebaseFirestore.Timestamp | Date;
}

import { TimestampFields } from '../../../shared/types';

export interface Salon extends TimestampFields {
  id?: string;
  nombre: string;
  grado: string;
  seccion: string;
  idDocenteCreador: string;
  nombreDocenteCreador: string;
  isActive: boolean;
  deletedAt?: FirebaseFirestore.Timestamp | Date;
  deletedBy?: string;
}

export interface CreateSalonDto {
  nombre: string;
  grado: string;
  seccion: string;
}

export interface UpdateSalonDto {
  nombre?: string;
  grado?: string;
  seccion?: string;
  isActive?: boolean;
}

export interface SalonFilters {
  grado?: string;
  activos?: boolean;
  idDocenteCreador?: string;
}

export interface SalonStats {
  total: number;
  activos: number;
  inactivos: number;
  porGrado: Record<string, { total: number; activos: number }>;
  porDocente: Record<string, { total: number; activos: number }>;
}

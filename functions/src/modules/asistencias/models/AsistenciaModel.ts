export interface Asistencia {
  id?: string;
  idAlumno: string;
  idCurso: string;
  fechaHora: Date;
  estado: 'presente' | 'tarde' | 'ausente';
  docenteRegistrador: string;
  observaciones?: string;
  createdAt?: any;
  updatedAt?: any;
}

export interface AsistenciaInput {
  qrCodeAlumno: string;
  idCurso: string;
  observaciones?: string;
}

export interface EstadisticasAsistencia {
  totalClases: number;
  asistencias: number;
  tardanzas: number;
  ausencias: number;
  porcentajeAsistencia: number;
}

import * as admin from 'firebase-admin';
import { Asistencia, AsistenciaInput, EstadisticasAsistencia } from '../models/AsistenciaModel';

export class AsistenciasService {
  private db = admin.firestore();

  async registrarAsistenciaPorQR(
    qrCodeAlumno: string,
    idCurso: string,
    docenteId: string,
    observaciones?: string
  ): Promise<Asistencia> {
    try {
      // Buscar al alumno por QR
      const alumnosQuery = await this.db.collection('users')
        .where('qrCode', '==', qrCodeAlumno)
        .where('role', '==', 'alumno')
        .limit(1)
        .get();

      if (alumnosQuery.empty) {
        throw new Error('QR no válido o alumno no encontrado');
      }

      const alumnoDoc = alumnosQuery.docs[0];
      const idAlumno = alumnoDoc.id;
      
      // Idempotencia: construir un ID determinístico por (curso, alumno, día)
      // Formato YYYYMMDD usando la zona horaria local del servidor
      const ahora = new Date();
      const y = ahora.getFullYear();
      const m = (ahora.getMonth() + 1).toString().padStart(2, '0');
      const d = ahora.getDate().toString().padStart(2, '0');
      const dateKey = `${y}${m}${d}`;
      const asistenciaDocId = `${idCurso}_${idAlumno}_${dateKey}`;

      // Determinar estado según la hora
      const horaActual = ahora.getHours() * 60 + ahora.getMinutes();
      let estado: 'presente' | 'tarde' | 'ausente' = 'presente';
      
      // Si es después de las 8:15 AM, marcar como tarde
      if (horaActual > 8 * 60 + 15) {
        estado = 'tarde';
      }

      // Crear asistencia
      const asistenciaData: Asistencia = {
        idAlumno,
        idCurso,
        fechaHora: ahora,
        estado,
        docenteRegistrador: docenteId,
        observaciones: observaciones || '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      const docRef = this.db.collection('asistencias').doc(asistenciaDocId);
      try {
        // Intentar crear el documento solo si NO existe
        await docRef.create(asistenciaData as any);
      } catch (err: any) {
        // Si ya existe, devolver el existente sin crear uno nuevo
        if (err?.code === 6 /* ALREADY_EXISTS */ || err?.message?.toLowerCase().includes('already exists')) {
          const existingSnap = await docRef.get();
          const existingData = existingSnap.data() as Asistencia;
          const duplicateError: any = new Error('Asistencia ya registrada');
          duplicateError.code = 'ALREADY_EXISTS';
          duplicateError.existing = { id: existingSnap.id, ...existingData };
          throw duplicateError;
        }
        throw err;
      }

      return {
        id: asistenciaDocId,
        ...asistenciaData
      };
    } catch (error) {
      console.error('Error registrando asistencia:', error);
      throw error;
    }
  }

  async obtenerAsistenciasPorCurso(
    idCurso: string,
    fecha?: Date
  ): Promise<Asistencia[]> {
    try {
      let query = this.db.collection('asistencias')
        .where('idCurso', '==', idCurso);

      if (fecha) {
        const inicioDay = new Date(fecha);
        inicioDay.setHours(0, 0, 0, 0);
        const finDay = new Date(fecha);
        finDay.setHours(23, 59, 59, 999);

        query = query
          .where('fechaHora', '>=', inicioDay)
          .where('fechaHora', '<=', finDay);
      }

      const snapshot = await query.orderBy('fechaHora', 'desc').get();
      
      return snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as Asistencia));
    } catch (error) {
      console.error('Error obteniendo asistencias por curso:', error);
      throw error;
    }
  }

  async obtenerAsistenciasPorAlumno(
    idAlumno: string,
    idCurso?: string
  ): Promise<Asistencia[]> {
    try {
      let query = this.db.collection('asistencias')
        .where('idAlumno', '==', idAlumno);

      if (idCurso) {
        query = query.where('idCurso', '==', idCurso);
      }

      const snapshot = await query.orderBy('fechaHora', 'desc').get();
      
      return snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as Asistencia));
    } catch (error) {
      console.error('Error obteniendo asistencias por alumno:', error);
      throw error;
    }
  }

  async obtenerEstadisticasAlumno(
    idAlumno: string,
    idCurso: string
  ): Promise<EstadisticasAsistencia> {
    try {
      const asistencias = await this.obtenerAsistenciasPorAlumno(idAlumno, idCurso);
      
      const totalClases = asistencias.length;
      const presentes = asistencias.filter(a => a.estado === 'presente').length;
      const tardanzas = asistencias.filter(a => a.estado === 'tarde').length;
      const ausencias = asistencias.filter(a => a.estado === 'ausente').length;
      
      const porcentajeAsistencia = totalClases > 0 
        ? Math.round(((presentes + tardanzas) / totalClases) * 100)
        : 0;

      return {
        totalClases,
        asistencias: presentes,
        tardanzas,
        ausencias,
        porcentajeAsistencia
      };
    } catch (error) {
      console.error('Error obteniendo estadísticas:', error);
      throw error;
    }
  }

  async marcarAusentes(idCurso: string, fecha: Date, docenteId: string): Promise<number> {
    try {
      // Obtener todos los alumnos del curso que no tienen asistencia marcada para la fecha
      const inicioDay = new Date(fecha);
      inicioDay.setHours(0, 0, 0, 0);
      const finDay = new Date(fecha);
      finDay.setHours(23, 59, 59, 999);

      // Obtener asistencias ya registradas
      const asistenciasExistentes = await this.db.collection('asistencias')
        .where('idCurso', '==', idCurso)
        .where('fechaHora', '>=', inicioDay)
        .where('fechaHora', '<=', finDay)
        .get();

      const alumnosConAsistencia = asistenciasExistentes.docs.map(doc => doc.data().idAlumno);

      // Obtener todos los alumnos inscritos en el curso
      // Esto requerirá otra colección para relacionar alumnos con cursos
      // Por ahora, marcaremos como ausentes a los que no registraron asistencia

      let ausentesCreados = 0;
      
      // Este es un placeholder - necesitarás implementar la lógica específica
      // según cómo manejes la inscripción de alumnos a cursos
      
      return ausentesCreados;
    } catch (error) {
      console.error('Error marcando ausentes:', error);
      throw error;
    }
  }
}

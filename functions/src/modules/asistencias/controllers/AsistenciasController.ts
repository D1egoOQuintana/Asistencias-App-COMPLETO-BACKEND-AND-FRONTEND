import { Request, Response } from 'express';
import { AsistenciasService } from '../services/AsistenciasService';
import { AsistenciaInput } from '../models/AsistenciaModel';

export class AsistenciasController {
  private asistenciasService = new AsistenciasService();

  // Registrar asistencia escaneando QR
  registrarPorQR = async (req: Request, res: Response): Promise<void> => {
    try {
      const { qrCodeAlumno, idCurso, observaciones }: AsistenciaInput = req.body;
      const docenteId = req.user!.uid;

      if (!qrCodeAlumno || !idCurso) {
        res.status(400).json({
          success: false,
          message: 'QR del alumno y ID del curso son requeridos'
        });
        return;
      }

      const asistencia = await this.asistenciasService.registrarAsistenciaPorQR(
        qrCodeAlumno,
        idCurso,
        docenteId,
        observaciones
      );

      res.status(201).json({
        success: true,
        message: 'Asistencia registrada exitosamente',
        data: asistencia
      });
    } catch (error: any) {
      console.error('Error en registrarPorQR:', error);
      // Si es duplicado, tratarlo como éxito idempotente
      if (error?.code === 'ALREADY_EXISTS' && error?.existing) {
        res.status(200).json({
          success: true,
          message: 'Asistencia ya había sido registrada (se mantiene el primer registro).',
          data: error.existing
        });
        return;
      }
      res.status(400).json({
        success: false,
        message: error.message || 'Error al registrar asistencia'
      });
    }
  };

  // Obtener asistencias por curso
  obtenerPorCurso = async (req: Request, res: Response): Promise<void> => {
    try {
      const { idCurso } = req.params;
      const { fecha } = req.query;

      if (!idCurso) {
        res.status(400).json({
          success: false,
          message: 'ID del curso es requerido'
        });
        return;
      }

      let fechaFiltro: Date | undefined;
      if (fecha && typeof fecha === 'string') {
        fechaFiltro = new Date(fecha);
      }

      const asistencias = await this.asistenciasService.obtenerAsistenciasPorCurso(
        idCurso,
        fechaFiltro
      );

      res.json({
        success: true,
        data: asistencias
      });
    } catch (error: any) {
      console.error('Error en obtenerPorCurso:', error);
      res.status(500).json({
        success: false,
        message: error.message || 'Error al obtener asistencias'
      });
    }
  };

  // Obtener asistencias por alumno
  obtenerPorAlumno = async (req: Request, res: Response): Promise<void> => {
    try {
      const { idAlumno } = req.params;
      const { idCurso } = req.query;

      if (!idAlumno) {
        res.status(400).json({
          success: false,
          message: 'ID del alumno es requerido'
        });
        return;
      }

      const asistencias = await this.asistenciasService.obtenerAsistenciasPorAlumno(
        idAlumno,
        idCurso as string
      );

      res.json({
        success: true,
        data: asistencias
      });
    } catch (error: any) {
      console.error('Error en obtenerPorAlumno:', error);
      res.status(500).json({
        success: false,
        message: error.message || 'Error al obtener asistencias'
      });
    }
  };

  // Obtener estadísticas de asistencia de un alumno
  obtenerEstadisticas = async (req: Request, res: Response): Promise<void> => {
    try {
      const { idAlumno, idCurso } = req.params;

      if (!idAlumno || !idCurso) {
        res.status(400).json({
          success: false,
          message: 'ID del alumno e ID del curso son requeridos'
        });
        return;
      }

      const estadisticas = await this.asistenciasService.obtenerEstadisticasAlumno(
        idAlumno,
        idCurso
      );

      res.json({
        success: true,
        data: estadisticas
      });
    } catch (error: any) {
      console.error('Error en obtenerEstadisticas:', error);
      res.status(500).json({
        success: false,
        message: error.message || 'Error al obtener estadísticas'
      });
    }
  };

  // Marcar ausentes a los que no registraron asistencia
  marcarAusentes = async (req: Request, res: Response): Promise<void> => {
    try {
      const { idCurso } = req.params;
      const { fecha } = req.body;
      const docenteId = req.user!.uid;

      if (!idCurso || !fecha) {
        res.status(400).json({
          success: false,
          message: 'ID del curso y fecha son requeridos'
        });
        return;
      }

      const fechaObj = new Date(fecha);
      const ausentesCreados = await this.asistenciasService.marcarAusentes(
        idCurso,
        fechaObj,
        docenteId
      );

      res.json({
        success: true,
        message: `Se marcaron ${ausentesCreados} alumnos como ausentes`,
        data: { ausentesCreados }
      });
    } catch (error: any) {
      console.error('Error en marcarAusentes:', error);
      res.status(500).json({
        success: false,
        message: error.message || 'Error al marcar ausentes'
      });
    }
  };
}

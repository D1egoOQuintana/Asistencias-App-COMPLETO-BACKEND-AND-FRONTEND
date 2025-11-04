import { Request, Response } from 'express';
import { SalonesService } from '../services/SalonesService';
import { CreateSalonDto, UpdateSalonDto } from '../models/Salon';
import { ApiResponse } from '../../../shared/types';

export class SalonesController {
  private salonesService = new SalonesService();

  /**
   * Crear salón
   */
  create = async (req: Request, res: Response): Promise<void> => {
    try {
      const { nombre, grado, seccion }: CreateSalonDto = req.body;

      if (!nombre || !grado || !seccion) {
        res.status(400).json({
          success: false,
          message: 'Nombre, grado y sección son requeridos'
        } as ApiResponse);
        return;
      }

      const salon = await this.salonesService.create(
        { nombre, grado, seccion },
        req.user!
      );

      res.status(201).json({
        success: true,
        message: 'Salón creado exitosamente',
        data: { salon }
      } as ApiResponse);

    } catch (error: any) {
      console.error('Error creando salón:', error);
      res.status(500).json({
        success: false,
        message: error.message || 'Error al crear salón'
      } as ApiResponse);
    }
  };

  /**
   * Listar salones
   */
  findAll = async (req: Request, res: Response): Promise<void> => {
    try {
      const { grado, activos = 'true' } = req.query;

      const filters = {
        grado: grado as string | undefined,
        activos: activos === 'true'
      };

      const salones = await this.salonesService.findAll(filters, req.user!);

      res.json({
        success: true,
        message: `${salones.length} salones encontrados`,
        data: {
          salones,
          total: salones.length,
          filtros: {
            grado: grado || 'todos',
            activos: filters.activos
          }
        }
      } as ApiResponse);

    } catch (error: any) {
      console.error('Error obteniendo salones:', error);
      res.status(500).json({
        success: false,
        message: 'Error al obtener lista de salones'
      } as ApiResponse);
    }
  };

  /**
   * Obtener salón por ID
   */
  findById = async (req: Request, res: Response): Promise<void> => {
    try {
      const { id } = req.params;

      const salon = await this.salonesService.findById(id, req.user!);

      if (!salon) {
        res.status(404).json({
          success: false,
          message: 'Salón no encontrado'
        } as ApiResponse);
        return;
      }

      res.json({
        success: true,
        message: 'Salón encontrado',
        data: { salon }
      } as ApiResponse);

    } catch (error: any) {
      console.error('Error obteniendo salón:', error);
      res.status(error.message.includes('permisos') ? 403 : 500).json({
        success: false,
        message: error.message || 'Error al obtener salón'
      } as ApiResponse);
    }
  };

  /**
   * Actualizar salón
   */
  update = async (req: Request, res: Response): Promise<void> => {
    try {
      const { id } = req.params;
      const updateData: UpdateSalonDto = req.body;

      await this.salonesService.update(id, updateData, req.user!);

      // Devolver el salón actualizado para que el frontend pueda refrescar en la misma sesión
      const updatedSalon = await this.salonesService.findById(id, req.user!);

      res.json({
        success: true,
        message: 'Salón actualizado exitosamente',
        data: {
          salon: updatedSalon,
          updatedFields: Object.keys(updateData)
        }
      } as ApiResponse);

    } catch (error: any) {
      console.error('Error actualizando salón:', error);
      
      let statusCode = 500;
      if (error.message.includes('no encontrado')) statusCode = 404;
      if (error.message.includes('permisos') || error.message.includes('creador')) statusCode = 403;
      if (error.message.includes('Ya existe')) statusCode = 400;

      res.status(statusCode).json({
        success: false,
        message: error.message || 'Error al actualizar salón'
      } as ApiResponse);
    }
  };

  /**
   * Eliminar salón
   */
  delete = async (req: Request, res: Response): Promise<void> => {
    try {
      const { id } = req.params;
      const { eliminarPermanente = 'false' } = req.query;

      const result = await this.salonesService.delete(
        id, 
        req.user!, 
        eliminarPermanente === 'true'
      );

      const message = result.tipo === 'eliminacion_permanente' 
        ? 'Salón eliminado permanentemente'
        : 'Salón desactivado exitosamente';

      res.json({
        success: true,
        message,
        data: { id, ...result }
      } as ApiResponse);

    } catch (error: any) {
      console.error('Error eliminando salón:', error);
      
      let statusCode = 500;
      if (error.message.includes('no encontrado')) statusCode = 404;
      if (error.message.includes('permisos') || error.message.includes('creador')) statusCode = 403;

      res.status(statusCode).json({
        success: false,
        message: error.message || 'Error al eliminar salón'
      } as ApiResponse);
    }
  };

  /**
   * Obtener salones por grado
   */
  findByGrado = async (req: Request, res: Response): Promise<void> => {
    try {
      const { grado } = req.params;

      const salones = await this.salonesService.findByGrado(grado, req.user!);

      res.json({
        success: true,
        message: `${salones.length} salones encontrados para ${grado}`,
        data: {
          grado,
          salones,
          total: salones.length
        }
      } as ApiResponse);

    } catch (error: any) {
      console.error('Error obteniendo salones por grado:', error);
      res.status(500).json({
        success: false,
        message: 'Error al obtener salones por grado'
      } as ApiResponse);
    }
  };

  /**
   * Obtener estadísticas (solo admin)
   */
  getStats = async (req: Request, res: Response): Promise<void> => {
    try {
      const stats = await this.salonesService.getStats();

      res.json({
        success: true,
        message: 'Estadísticas de salones obtenidas',
        data: { stats }
      } as ApiResponse);

    } catch (error: any) {
      console.error('Error obteniendo estadísticas:', error);
      res.status(500).json({
        success: false,
        message: 'Error al obtener estadísticas de salones'
      } as ApiResponse);
    }
  };
}

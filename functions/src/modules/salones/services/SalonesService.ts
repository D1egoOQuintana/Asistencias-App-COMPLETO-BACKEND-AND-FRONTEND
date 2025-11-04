import * as admin from 'firebase-admin';
import { 
  Salon, 
  CreateSalonDto, 
  UpdateSalonDto, 
  SalonFilters, 
  SalonStats 
} from '../models/Salon';
import { AuthenticatedUser } from '../../../shared/types';

export class SalonesService {
  private readonly collection = 'salones';

  /**
   * Crear un nuevo salón
   */
  async create(data: CreateSalonDto, user: AuthenticatedUser): Promise<Salon> {
    // Verificar que no existe un salón con el mismo grado y sección
    const existingSalon = await admin.firestore()
      .collection(this.collection)
      .where('grado', '==', data.grado)
      .where('seccion', '==', data.seccion)
      .where('isActive', '==', true)
      .limit(1)
      .get();

    if (!existingSalon.empty) {
      throw new Error(`Ya existe un salón para ${data.grado} sección ${data.seccion}`);
    }

    const salonData: any = {
      nombre: data.nombre.trim(),
      grado: data.grado.trim(),
      seccion: data.seccion.trim(),
      idDocenteCreador: user.uid,
      nombreDocenteCreador: user.fullName,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    const salonRef = await admin.firestore()
      .collection(this.collection)
      .add(salonData);

    return {
      id: salonRef.id,
      ...salonData,
      createdAt: new Date(),
      updatedAt: new Date()
    } as Salon;
  }

  /**
   * Obtener salones con filtros
   */
  async findAll(filters: SalonFilters, user: AuthenticatedUser): Promise<Salon[]> {
    let query: any = admin.firestore().collection(this.collection);

    // Filtrar por grado si se especifica
    if (filters.grado) {
      query = query.where('grado', '==', filters.grado);
    }

    // Filtrar por estado activo
    if (filters.activos !== undefined) {
      query = query.where('isActive', '==', filters.activos);
    }

    // Si es docente, solo ver sus salones (admin ve todos)
    if (user.role === 'docente') {
      query = query.where('idDocenteCreador', '==', user.uid);
    }

    const snapshot = await query
      .orderBy('grado')
      .orderBy('seccion')
      .get();

    return snapshot.docs.map((doc: any) => {
      const data = doc.data();
      return {
        id: doc.id,
        ...data
      } as Salon;
    });
  }

  /**
   * Obtener salón por ID
   */
  async findById(id: string, user: AuthenticatedUser): Promise<Salon | null> {
    const salonDoc = await admin.firestore()
      .collection(this.collection)
      .doc(id)
      .get();

    if (!salonDoc.exists) {
      return null;
    }

    const salonData = salonDoc.data()!;

    // Si es docente, verificar que él creó el salón
    if (user.role === 'docente' && salonData.idDocenteCreador !== user.uid) {
      throw new Error('No tienes permisos para ver este salón');
    }

    return {
      id: id,
      ...salonData
    } as Salon;
  }

  /**
   * Actualizar salón
   */
  async update(id: string, data: UpdateSalonDto, user: AuthenticatedUser): Promise<void> {
    const salon = await this.findById(id, user);
    if (!salon) {
      throw new Error('Salón no encontrado');
    }

    // Solo el docente creador o admin pueden modificar
    if (user.role === 'docente' && salon.idDocenteCreador !== user.uid) {
      throw new Error('Solo el docente creador puede modificar este salón');
    }

    // Si se cambia grado/sección, verificar que no haya conflicto
    if ((data.grado && data.grado !== salon.grado) || 
        (data.seccion && data.seccion !== salon.seccion)) {
      const newGrado = data.grado || salon.grado;
      const newSeccion = data.seccion || salon.seccion;

      const existingSalon = await admin.firestore()
        .collection(this.collection)
        .where('grado', '==', newGrado)
        .where('seccion', '==', newSeccion)
        .where('isActive', '==', true)
        .limit(1)
        .get();

      if (!existingSalon.empty && existingSalon.docs[0].id !== id) {
        throw new Error(`Ya existe un salón para ${newGrado} sección ${newSeccion}`);
      }
    }

    // Preparar datos para actualizar
    const updateData: any = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    if (data.nombre !== undefined) updateData.nombre = data.nombre.trim();
    if (data.grado !== undefined) updateData.grado = data.grado.trim();
    if (data.seccion !== undefined) updateData.seccion = data.seccion.trim();
    if (data.isActive !== undefined) updateData.isActive = data.isActive;

    await admin.firestore()
      .collection(this.collection)
      .doc(id)
      .update(updateData);
  }

  /**
   * Eliminar salón (lógico o físico)
   */
  async delete(id: string, user: AuthenticatedUser, permanent: boolean = false): Promise<{ tipo: string }> {
    const salon = await this.findById(id, user);
    if (!salon) {
      throw new Error('Salón no encontrado');
    }

    // Solo el docente creador o admin pueden eliminar
    if (user.role === 'docente' && salon.idDocenteCreador !== user.uid) {
      throw new Error('Solo el docente creador puede eliminar este salón');
    }

    if (permanent && user.role === 'admin') {
      // Eliminación permanente (solo admin)
      await admin.firestore()
        .collection(this.collection)
        .doc(id)
        .delete();
      
      return { tipo: 'eliminacion_permanente' };
    } else {
      // Eliminación lógica
      await admin.firestore()
        .collection(this.collection)
        .doc(id)
        .update({
          isActive: false,
          deletedAt: admin.firestore.FieldValue.serverTimestamp(),
          deletedBy: user.uid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      
      return { tipo: 'eliminacion_logica' };
    }
  }

  /**
   * Obtener salones por grado
   */
  async findByGrado(grado: string, user: AuthenticatedUser): Promise<Salon[]> {
    return this.findAll({ grado, activos: true }, user);
  }

  /**
   * Obtener estadísticas de salones (solo admin)
   */
  async getStats(): Promise<SalonStats> {
    const salonesSnapshot = await admin.firestore()
      .collection(this.collection)
      .get();

    const stats: SalonStats = {
      total: salonesSnapshot.size,
      activos: 0,
      inactivos: 0,
      porGrado: {},
      porDocente: {}
    };

    salonesSnapshot.docs.forEach((doc: any) => {
      const data = doc.data();
      
      if (data.isActive) {
        stats.activos++;
      } else {
        stats.inactivos++;
      }

      // Estadísticas por grado
      if (!stats.porGrado[data.grado]) {
        stats.porGrado[data.grado] = { total: 0, activos: 0 };
      }
      stats.porGrado[data.grado].total++;
      if (data.isActive) {
        stats.porGrado[data.grado].activos++;
      }

      // Estadísticas por docente
      if (!stats.porDocente[data.nombreDocenteCreador]) {
        stats.porDocente[data.nombreDocenteCreador] = { total: 0, activos: 0 };
      }
      stats.porDocente[data.nombreDocenteCreador].total++;
      if (data.isActive) {
        stats.porDocente[data.nombreDocenteCreador].activos++;
      }
    });

    return stats;
  }
}

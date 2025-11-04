import { Router } from 'express';
import { SalonesController } from '../controllers/SalonesController';
import { 
  verifyFirebaseToken, 
  requireDocenteOrAdmin, 
  requireAdmin 
} from '../../../shared/middleware/auth';

const router = Router();
const salonesController = new SalonesController();

// Todas las rutas requieren autenticación
router.use(verifyFirebaseToken);

// CRUD básico de salones
router.post('/', requireDocenteOrAdmin, salonesController.create);
router.get('/', requireDocenteOrAdmin, salonesController.findAll);
router.get('/stats', requireAdmin, salonesController.getStats);
router.get('/grado/:grado', requireDocenteOrAdmin, salonesController.findByGrado);
router.get('/:id', requireDocenteOrAdmin, salonesController.findById);
router.put('/:id', requireDocenteOrAdmin, salonesController.update);
router.delete('/:id', requireDocenteOrAdmin, salonesController.delete);

export default router;

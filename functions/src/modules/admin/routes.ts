import { Router } from 'express';
import { createTeacher, forcePasswordChange, listTeachers } from './userManagement';

const router = Router();

// Rutas para administración de usuarios
router.post('/teachers', createTeacher);
router.get('/teachers', listTeachers);
router.post('/teachers/force-password-change', forcePasswordChange);

export { router as adminRoutes };

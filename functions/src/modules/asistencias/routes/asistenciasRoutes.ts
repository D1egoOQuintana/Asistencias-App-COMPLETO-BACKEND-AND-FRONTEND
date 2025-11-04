import { Router } from 'express';
import { AsistenciasController } from '../controllers/AsistenciasController';
import { verifyFirebaseToken, requireDocenteOrAdmin } from '../../../shared/middleware/auth';

// Exporta una fábrica que crea el router una vez que Firebase Admin ya fue inicializado
export default function createAsistenciasRoutes(): ReturnType<typeof Router> {
	const router = Router();
	const asistenciasController = new AsistenciasController();

	// Todas las rutas requieren autenticación
	router.use(verifyFirebaseToken);

	// Solo docentes y admins pueden gestionar asistencias
	router.use(requireDocenteOrAdmin);

	// Registrar asistencia por QR (endpoint principal para el escáner)
	router.post('/registrar-qr', asistenciasController.registrarPorQR);

	// Obtener asistencias por curso
	router.get('/curso/:idCurso', asistenciasController.obtenerPorCurso);

	// Obtener asistencias por alumno
	router.get('/alumno/:idAlumno', asistenciasController.obtenerPorAlumno);

	// Obtener estadísticas de asistencia de un alumno en un curso
	router.get('/estadisticas/:idAlumno/:idCurso', asistenciasController.obtenerEstadisticas);

	// Marcar como ausentes a los que no registraron asistencia
	router.post('/marcar-ausentes/:idCurso', asistenciasController.marcarAusentes);

	return router;
}

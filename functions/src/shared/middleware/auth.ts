import { Request, Response, NextFunction } from 'express';
import * as admin from 'firebase-admin';

/**
 * Middleware para verificar token de Firebase Auth
 */
export async function verifyFirebaseToken(req: Request, res: Response, next: NextFunction) {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({
        success: false,
        message: 'Token de autorización requerido'
      });
      return;
    }

    const token = authHeader.split(' ')[1];
    const decodedToken = await admin.auth().verifyIdToken(token);

    // Obtener datos adicionales del usuario desde Firestore
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(decodedToken.uid)
      .get();

    if (!userDoc.exists) {
      res.status(401).json({
        success: false,
        message: 'Usuario no encontrado en el sistema'
      });
      return;
    }

    const userData = userDoc.data()!;

    // Agregar datos del usuario al request
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email!,
      fullName: userData.fullName,
      role: userData.role,
      isActive: userData.isActive
    };

    next();
  } catch (error) {
    console.error('Error verificando token:', error);
    res.status(401).json({
      success: false,
      message: 'Token inválido'
    });
  }
}

/**
 * Middleware para verificar rol de admin
 */
export function requireAdmin(req: Request, res: Response, next: NextFunction) {
  if (!req.user || req.user.role !== 'admin') {
    res.status(403).json({
      success: false,
      message: 'Solo administradores pueden realizar esta acción'
    });
    return;
  }
  next();
}

/**
 * Middleware para verificar rol de docente o admin
 */
export function requireDocenteOrAdmin(req: Request, res: Response, next: NextFunction) {
  if (!req.user || (req.user.role !== 'docente' && req.user.role !== 'admin')) {
    res.status(403).json({
      success: false,
      message: 'Solo docentes y administradores pueden realizar esta acción'
    });
    return;
  }
  next();
}

/**
 * Middleware para bloquear acceso de estudiantes (durante beta)
 */
export function blockStudentAccess(req: Request, res: Response, next: NextFunction) {
  if (req.user && req.user.role === 'alumno') {
    res.status(403).json({
      success: false,
      message: 'Acceso no disponible durante la fase beta'
    });
    return;
  }
  next();
}

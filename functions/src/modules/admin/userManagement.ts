import * as admin from 'firebase-admin';
import { Request, Response } from 'express';

/**
 * Crear un nuevo docente
 * Solo los administradores pueden usar esta función
 */
export async function createTeacher(req: Request, res: Response): Promise<void> {
  try {
    // Verificar que el usuario autenticado es admin
    if (!req.user || req.user.role !== 'admin') {
      res.status(403).json({
        success: false,
        message: 'Solo los administradores pueden crear docentes'
      });
      return;
    }

    const { email, fullName, temporaryPassword } = req.body;

    // Validar datos requeridos
    if (!email || !fullName || !temporaryPassword) {
      res.status(400).json({
        success: false,
        message: 'Email, nombre completo y contraseña temporal son requeridos'
      });
      return;
    }

    // Validar formato de email
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      res.status(400).json({
        success: false,
        message: 'Formato de email inválido'
      });
      return;
    }

    // Validar contraseña temporal (mínimo 6 caracteres)
    if (temporaryPassword.length < 6) {
      res.status(400).json({
        success: false,
        message: 'La contraseña temporal debe tener al menos 6 caracteres'
      });
      return;
    }

    // Crear usuario en Firebase Auth
    const userRecord = await admin.auth().createUser({
      email: email,
      password: temporaryPassword,
      displayName: fullName,
      emailVerified: false, // El docente debe verificar su email
    });

    // Crear documento en Firestore
    await admin.firestore().collection('users').doc(userRecord.uid).set({
      email: email,
      fullName: fullName,
      role: 'docente',
      isActive: true,
      mustChangePassword: true, // Debe cambiar contraseña en primer login
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: req.user.uid,
      createdByAdmin: true,
    });

    // Log de auditoría
    await admin.firestore().collection('audit_logs').add({
      action: 'teacher_created',
      performedBy: req.user.uid,
      performedByEmail: req.user.email,
      targetUser: userRecord.uid,
      targetEmail: email,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      details: {
        teacherName: fullName,
        mustChangePassword: true
      }
    });

    res.status(201).json({
      success: true,
      message: 'Docente creado exitosamente',
      data: {
        uid: userRecord.uid,
        email: email,
        fullName: fullName,
        mustChangePassword: true,
        temporaryPassword: temporaryPassword // Incluir en respuesta para que admin la vea
      }
    });

  } catch (error: any) {
    console.error('Error creating teacher:', error);
    
    // Manejar errores específicos de Firebase Auth
    let errorMessage = 'Error interno del servidor';
    let statusCode = 500;

    if (error.code === 'auth/email-already-exists') {
      errorMessage = 'Ya existe un usuario con este email';
      statusCode = 400;
    } else if (error.code === 'auth/invalid-email') {
      errorMessage = 'Email inválido';
      statusCode = 400;
    } else if (error.code === 'auth/weak-password') {
      errorMessage = 'La contraseña es muy débil';
      statusCode = 400;
    }

    res.status(statusCode).json({
      success: false,
      message: errorMessage,
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
}

/**
 * Forzar cambio de contraseña del docente
 */
export async function forcePasswordChange(req: Request, res: Response): Promise<void> {
  try {
    // Verificar que el usuario autenticado es admin
    if (!req.user || req.user.role !== 'admin') {
      res.status(403).json({
        success: false,
        message: 'Solo los administradores pueden forzar cambio de contraseña'
      });
      return;
    }

    const { teacherUid } = req.body;

    if (!teacherUid) {
      res.status(400).json({
        success: false,
        message: 'UID del docente es requerido'
      });
      return;
    }

    // Verificar que el usuario existe y es docente
    const teacherDoc = await admin.firestore().collection('users').doc(teacherUid).get();
    
    if (!teacherDoc.exists) {
      res.status(404).json({
        success: false,
        message: 'Docente no encontrado'
      });
      return;
    }

    const teacherData = teacherDoc.data();
    if (teacherData?.role !== 'docente') {
      res.status(400).json({
        success: false,
        message: 'El usuario especificado no es un docente'
      });
      return;
    }

    // Marcar que debe cambiar contraseña
    await admin.firestore().collection('users').doc(teacherUid).update({
      mustChangePassword: true,
      passwordChangeRequiredAt: admin.firestore.FieldValue.serverTimestamp(),
      passwordChangeRequiredBy: req.user.uid
    });

    // Log de auditoría
    await admin.firestore().collection('audit_logs').add({
      action: 'password_change_forced',
      performedBy: req.user.uid,
      performedByEmail: req.user.email,
      targetUser: teacherUid,
      targetEmail: teacherData?.email,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    res.json({
      success: true,
      message: 'Se ha marcado al docente para cambiar su contraseña en el próximo inicio de sesión'
    });

  } catch (error: any) {
    console.error('Error forcing password change:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
}

/**
 * Listar todos los docentes (solo admin)
 */
export async function listTeachers(req: Request, res: Response): Promise<void> {
  try {
    if (!req.user || req.user.role !== 'admin') {
      res.status(403).json({
        success: false,
        message: 'Solo los administradores pueden listar docentes'
      });
      return;
    }

    const teachersSnapshot = await admin.firestore()
      .collection('users')
      .where('role', '==', 'docente')
      .orderBy('createdAt', 'desc')
      .get();

    const teachers = teachersSnapshot.docs.map(doc => ({
      uid: doc.id,
      ...doc.data(),
      // No incluir información sensible
      temporaryPassword: undefined
    }));

    res.json({
      success: true,
      data: teachers,
      count: teachers.length
    });

  } catch (error: any) {
    console.error('Error listing teachers:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
}

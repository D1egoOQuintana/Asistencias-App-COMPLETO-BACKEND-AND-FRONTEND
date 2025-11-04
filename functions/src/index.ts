import express from 'express';
import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import { setGlobalOptions } from 'firebase-functions/v2';
import { salonesRoutes } from './modules/salones';
import createAsistenciasRoutes from './modules/asistencias/routes/asistenciasRoutes';
import { adminRoutes } from './modules/admin/routes';

// Extender la interfaz Request para incluir el usuario autenticado
declare global {
  namespace Express {
    interface Request {
      user?: {
        uid: string;
        email: string;
        fullName: string;
        role: 'admin' | 'docente' | 'alumno';
        isActive: boolean;
      };
    }
  }
}

// Inicializar Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Configuración global de Firebase Functions
 */
setGlobalOptions({
  maxInstances: 10,
  timeoutSeconds: 30,
  memory: '256MiB',
  region: 'us-central1'
});

/**
 * Middleware para verificar autenticación Firebase
 */
async function verifyFirebaseToken(req: any, res: any, next: any) {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Token de autorización requerido'
      });
    }

    const token = authHeader.substring(7);
    
    // Verificar token con Firebase Admin
    const decodedToken = await admin.auth().verifyIdToken(token);
    
    // Obtener datos del usuario desde Firestore
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(decodedToken.uid)
      .get();

    if (!userDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Usuario no encontrado'
      });
    }

    const userData = userDoc.data();
    if (!userData?.isActive) {
      return res.status(403).json({
        success: false,
        message: 'Usuario desactivado'
      });
    }

    // Agregar datos del usuario al request
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      ...userData
    };

    next();
  } catch (error) {
    console.error('Error verificando token:', error);
    return res.status(401).json({
      success: false,
      message: 'Token inválido'
    });
  }
}

/**
 * Middleware para verificar rol de admin
 */
function requireAdmin(req: any, res: any, next: any) {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({
      success: false,
      message: 'Solo administradores pueden realizar esta acción'
    });
  }
  next();
}

/**
 * Middleware para verificar rol de docente o admin
 */
function requireDocenteOrAdmin(req: any, res: any, next: any) {
  if (!req.user || (req.user.role !== 'docente' && req.user.role !== 'admin')) {
    return res.status(403).json({
      success: false,
      message: 'Solo docentes y administradores pueden acceder a esta función'
    });
  }
  next();
}

/**
 * Middleware para verificar que los alumnos no puedan acceder (app en beta)
 */
function blockStudentAccess(req: any, res: any, next: any) {
  if (req.user && req.user.role === 'alumno') {
    return res.status(403).json({
      success: false,
      message: 'La aplicación está en versión beta. Los alumnos no tienen acceso por el momento.'
    });
  }
  next();
}

/**
 * Crear aplicación Express con Firebase Auth
 */
function createApp(): express.Application {
  const app = express();

  // Middleware básico
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // CORS
  app.use((req, res, next) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    next();
  });

  // Logging
  app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
    next();
  });

  // ===== RUTAS PÚBLICAS =====

  app.get('/', (req, res) => {
    res.json({
      success: true,
      message: 'API de Asistencias Escolares con Firebase Auth',
      data: {
        version: '1.0.0',
        status: 'beta',
        authentication: 'Firebase Auth',
        roles: {
          admin: 'Gestiona sistema, registra docentes',
          docente: 'Registra alumnos, toma asistencias',
          alumno: 'Solo datos (sin acceso en beta)'
        },
        endpoints: {
          public: {
            health: 'GET /health'
          },
          protected: {
            profile: 'GET /auth/profile',
            verify: 'GET /auth/verify'
          },
          admin: {
            registerDocente: 'POST /auth/register-docente',
            listUsers: 'GET /users'
          },
          docente: {
            registerAlumno: 'POST /estudiantes/register',
            listAlumnos: 'GET /estudiantes',
            getAlumno: 'GET /estudiantes/:uid',
            getAlumnoQR: 'GET /estudiantes/:uid/qr',
            registrarAsistencia: 'POST /asistencias/registrar-qr',
            obtenerAsistenciasCurso: 'GET /asistencias/curso/:idCurso',
            obtenerAsistenciasAlumno: 'GET /asistencias/alumno/:idAlumno',
            obtenerEstadisticas: 'GET /asistencias/estadisticas/:idAlumno/:idCurso',
            gestionSalones: 'CRUD /salones'
          }
        }
      }
    });
  });

  app.get('/health', (req, res) => {
    res.json({
      success: true,
      message: 'Servidor funcionando correctamente',
      data: {
        timestamp: new Date().toISOString(),
        version: '1.0.0',
        firebase: 'connected'
      }
    });
  });

  // ===== RUTAS DE AUTENTICACIÓN =====

  // Registrar docente (solo admin) - usando Firebase Auth
  app.post('/auth/register-docente', verifyFirebaseToken, requireAdmin, async (req, res) => {
    try {
      const { email, password, fullName, profile } = req.body;

      if (!email || !password || !fullName) {
        return res.status(400).json({
          success: false,
          message: 'Email, contraseña y nombre completo son requeridos'
        });
      }

      // Crear usuario en Firebase Auth
      const userRecord = await admin.auth().createUser({
        email: email,
        password: password,
        displayName: fullName,
        emailVerified: false
      });

      // Crear documento en Firestore
      const userData = {
        email: email,
        fullName: fullName,
        role: 'docente',
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        profile: profile || {}
      };

      await admin.firestore()
        .collection('users')
        .doc(userRecord.uid)
        .set(userData);

      // Establecer custom claims
      await admin.auth().setCustomUserClaims(userRecord.uid, {
        role: 'docente',
        isActive: true
      });

      return res.status(201).json({
        success: true,
        message: 'Docente registrado exitosamente',
        data: {
          user: {
            uid: userRecord.uid,
            email: email,
            fullName: fullName,
            role: 'docente',
            isActive: true
          }
        }
      });

    } catch (error: any) {
      console.error('Error registrando docente:', error);
      
      if (error.code === 'auth/email-already-exists') {
        return res.status(400).json({
          success: false,
          message: 'El email ya está registrado'
        });
      }

      return res.status(500).json({
        success: false,
        message: 'Error al registrar docente'
      });
    }
  });

  // Obtener perfil del usuario autenticado (con bloqueo para alumnos)
  app.get('/auth/profile', verifyFirebaseToken, blockStudentAccess, (req: any, res) => {
    res.json({
      success: true,
      data: {
        user: {
          uid: req.user.uid,
          email: req.user.email,
          fullName: req.user.fullName,
          role: req.user.role,
          isActive: req.user.isActive,
          profile: req.user.profile,
          createdAt: req.user.createdAt,
          updatedAt: req.user.updatedAt
        }
      }
    });
  });

  // Verificar token (con bloqueo para alumnos)
  app.get('/auth/verify', verifyFirebaseToken, blockStudentAccess, (req: any, res) => {
    res.json({
      success: true,
      message: 'Token válido',
      data: {
        user: {
          uid: req.user.uid,
          email: req.user.email,
          role: req.user.role,
          isActive: req.user.isActive
        }
      }
    });
  });

  // Recuperación de contraseña (usando Firebase Auth)
  app.post('/auth/reset-password', async (req, res) => {
    try {
      const { email } = req.body;

      if (!email) {
        return res.status(400).json({
          success: false,
          message: 'Email es requerido'
        });
      }

      // Verificar que el usuario existe en Firestore
      const usersQuery = await admin.firestore()
        .collection('users')
        .where('email', '==', email)
        .limit(1)
        .get();

      if (usersQuery.empty) {
        // Por seguridad, siempre responder exitosamente
        return res.json({
          success: true,
          message: 'Si el email existe en nuestro sistema, recibirás un enlace de recuperación'
        });
      }

      // Generar link de reset usando Firebase Auth
      const resetLink = await admin.auth().generatePasswordResetLink(email, {
        url: 'http://localhost:3000/reset-password', // Cambiar por tu URL
        handleCodeInApp: true
      });

      // En producción, aquí enviarías el email
      console.log('Reset link generado:', resetLink);

      return res.json({
        success: true,
        message: 'Si el email existe en nuestro sistema, recibirás un enlace de recuperación'
      });

    } catch (error) {
      console.error('Error en reset password:', error);
      // Siempre responder exitosamente por seguridad
      return res.json({
        success: true,
        message: 'Si el email existe en nuestro sistema, recibirás un enlace de recuperación'
      });
    }
  });

  // Crear primer usuario admin (endpoint temporal para setup)
  app.post('/auth/setup-admin', async (req, res) => {
    try {
      // Solo permitir en desarrollo
      if (process.env.NODE_ENV === 'production') {
        return res.status(403).json({
          success: false,
          message: 'Endpoint no disponible en producción'
        });
      }

      const { email, password } = req.body;

      if (!email || !password) {
        return res.status(400).json({
          success: false,
          message: 'Email y contraseña son requeridos'
        });
      }

      // Crear admin en Firebase Auth
      const userRecord = await admin.auth().createUser({
        email: email,
        password: password,
        displayName: 'Administrador',
        emailVerified: true
      });

      // Crear documento en Firestore
      await admin.firestore()
        .collection('users')
        .doc(userRecord.uid)
        .set({
          email: email,
          fullName: 'Administrador',
          role: 'admin',
          isActive: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

      // Establecer custom claims
      await admin.auth().setCustomUserClaims(userRecord.uid, {
        role: 'admin',
        isActive: true
      });

      return res.json({
        success: true,
        message: 'Administrador creado exitosamente',
        data: {
          uid: userRecord.uid,
          email: email
        }
      });

    } catch (error: any) {
      console.error('Error creando admin:', error);
      return res.status(500).json({
        success: false,
        message: error.message || 'Error al crear administrador'
      });
    }
  });

  // ===== GESTIÓN DE ESTUDIANTES (Solo Docentes y Admin) =====

  // Registrar alumno (solo docentes y admin)
  app.post('/estudiantes/register', verifyFirebaseToken, requireDocenteOrAdmin, async (req, res) => {
    try {
      const { email, password, fullName, matricula, grado, seccion, telefono } = req.body;

      if (!email || !password || !fullName || !matricula) {
        return res.status(400).json({
          success: false,
          message: 'Email, contraseña, nombre completo y matrícula son requeridos'
        });
      }

      // Crear alumno en Firebase Auth
      const userRecord = await admin.auth().createUser({
        email: email,
        password: password,
        displayName: fullName,
        emailVerified: false
      });

      // Generar QR único para el alumno
      const qrCode = `QR_${userRecord.uid}_${Date.now()}`;

      // Crear documento en Firestore
      const alumnoData = {
        email: email,
        fullName: fullName,
        role: 'alumno',
        isActive: true,
        matricula: matricula,
        grado: grado || '',
        seccion: seccion || '',
        telefono: telefono || '',
        qrCode: qrCode, // QR único y permanente
        docenteRegistrador: req.user!.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      await admin.firestore()
        .collection('users')
        .doc(userRecord.uid)
        .set(alumnoData);

      // Establecer custom claims
      await admin.auth().setCustomUserClaims(userRecord.uid, {
        role: 'alumno',
        isActive: true
      });

      return res.status(201).json({
        success: true,
        message: 'Alumno registrado exitosamente',
        data: {
          user: {
            uid: userRecord.uid,
            email: email,
            fullName: fullName,
            role: 'alumno',
            matricula: matricula,
            grado: grado,
            seccion: seccion,
            isActive: true
          }
        }
      });

    } catch (error: any) {
      console.error('Error registrando alumno:', error);
      
      if (error.code === 'auth/email-already-exists') {
        return res.status(400).json({
          success: false,
          message: 'El email ya está registrado'
        });
      }

      return res.status(500).json({
        success: false,
        message: 'Error al registrar alumno'
      });
    }
  });

  // Listar alumnos (solo docentes y admin)
  app.get('/estudiantes', verifyFirebaseToken, requireDocenteOrAdmin, async (req, res) => {
    try {
      let query = admin.firestore()
        .collection('users')
        .where('role', '==', 'alumno')
        .where('isActive', '==', true);

      // Si es docente, solo ver alumnos que él registró
      if (req.user!.role === 'docente') {
        query = query.where('docenteRegistrador', '==', req.user!.uid);
      }

      const snapshot = await query.get();
      
      const alumnos = snapshot.docs.map(doc => {
        const data = doc.data();
        return {
          uid: doc.id,
          email: data.email,
          fullName: data.fullName,
          matricula: data.matricula,
          grado: data.grado,
          seccion: data.seccion,
          telefono: data.telefono,
          qrCode: data.qrCode,
          isActive: data.isActive,
          createdAt: data.createdAt
        };
      });

      return res.json({
        success: true,
        message: `${alumnos.length} alumnos encontrados`,
        data: {
          alumnos: alumnos,
          total: alumnos.length
        }
      });

    } catch (error) {
      console.error('Error obteniendo alumnos:', error);
      return res.status(500).json({
        success: false,
        message: 'Error al obtener lista de alumnos'
      });
    }
  });

  // Obtener alumno por ID (solo docentes y admin)
  app.get('/estudiantes/:uid', verifyFirebaseToken, requireDocenteOrAdmin, async (req, res) => {
    try {
      const { uid } = req.params;

      // Verificar que el alumno existe
      const alumnoDoc = await admin.firestore()
        .collection('users')
        .doc(uid)
        .get();

      if (!alumnoDoc.exists) {
        return res.status(404).json({
          success: false,
          message: 'Alumno no encontrado'
        });
      }

      const alumnoData = alumnoDoc.data()!;

      // Verificar que es un alumno
      if (alumnoData.role !== 'alumno') {
        return res.status(400).json({
          success: false,
          message: 'El usuario no es un alumno'
        });
      }

      // Si es docente, verificar que él registró al alumno
      if (req.user!.role === 'docente' && alumnoData.docenteRegistrador !== req.user!.uid) {
        return res.status(403).json({
          success: false,
          message: 'No tienes permisos para ver este alumno'
        });
      }

      return res.json({
        success: true,
        message: 'Alumno encontrado',
        data: {
          alumno: {
            uid: uid,
            email: alumnoData.email,
            fullName: alumnoData.fullName,
            matricula: alumnoData.matricula,
            grado: alumnoData.grado,
            seccion: alumnoData.seccion,
            telefono: alumnoData.telefono,
            qrCode: alumnoData.qrCode,
            isActive: alumnoData.isActive,
            docenteRegistrador: alumnoData.docenteRegistrador,
            createdAt: alumnoData.createdAt
          }
        }
      });

    } catch (error) {
      console.error('Error obteniendo alumno:', error);
      return res.status(500).json({
        success: false,
        message: 'Error al obtener alumno'
      });
    }
  });

  // Obtener QR de un alumno específico
  app.get('/estudiantes/:uid/qr', verifyFirebaseToken, requireDocenteOrAdmin, async (req, res) => {
    try {
      const { uid } = req.params;

      // Buscar el alumno en Firestore
      const alumnoDoc = await admin.firestore()
        .collection('users')
        .doc(uid)
        .get();

      if (!alumnoDoc.exists) {
        return res.status(404).json({
          success: false,
          message: 'Alumno no encontrado'
        });
      }

      const alumnoData = alumnoDoc.data()!;

      // Verificar que es un alumno
      if (alumnoData.role !== 'alumno') {
        return res.status(400).json({
          success: false,
          message: 'El usuario no es un alumno'
        });
      }

      // Si es docente, verificar que él registró al alumno
      if (req.user!.role === 'docente' && alumnoData.docenteRegistrador !== req.user!.uid) {
        return res.status(403).json({
          success: false,
          message: 'No tienes permisos para ver este alumno'
        });
      }

      if (!alumnoData.qrCode) {
        return res.status(404).json({
          success: false,
          message: 'El alumno no tiene código QR generado'
        });
      }

      return res.json({
        success: true,
        message: 'QR del alumno obtenido',
        data: {
          qrCode: alumnoData.qrCode,
          alumno: {
            uid: uid,
            fullName: alumnoData.fullName,
            matricula: alumnoData.matricula
          }
        }
      });

    } catch (error) {
      console.error('Error obteniendo QR del alumno:', error);
      return res.status(500).json({
        success: false,
        message: 'Error al obtener QR del alumno'
      });
    }
  });

  // Actualizar alumno (solo docentes y admin)
  app.put('/estudiantes/:uid', verifyFirebaseToken, requireDocenteOrAdmin, async (req, res) => {
    try {
      const { uid } = req.params;
      const { fullName, matricula, grado, seccion, telefono, isActive } = req.body;

      // Verificar que el alumno existe
      const alumnoDoc = await admin.firestore()
        .collection('users')
        .doc(uid)
        .get();

      if (!alumnoDoc.exists) {
        return res.status(404).json({
          success: false,
          message: 'Alumno no encontrado'
        });
      }

      const alumnoData = alumnoDoc.data()!;

      // Verificar que es un alumno
      if (alumnoData.role !== 'alumno') {
        return res.status(400).json({
          success: false,
          message: 'El usuario no es un alumno'
        });
      }

      // Si es docente, verificar que él registró al alumno
      if (req.user!.role === 'docente' && alumnoData.docenteRegistrador !== req.user!.uid) {
        return res.status(403).json({
          success: false,
          message: 'No tienes permisos para actualizar este alumno'
        });
      }

      // Preparar datos para actualizar
      const updateData: any = {
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      if (fullName !== undefined) updateData.fullName = fullName;
      if (matricula !== undefined) updateData.matricula = matricula;
      if (grado !== undefined) updateData.grado = grado;
      if (seccion !== undefined) updateData.seccion = seccion;
      if (telefono !== undefined) updateData.telefono = telefono;
      if (isActive !== undefined) updateData.isActive = isActive;

      // Actualizar en Firestore
      await admin.firestore()
        .collection('users')
        .doc(uid)
        .update(updateData);

      // Actualizar custom claims si el estado cambió
      if (isActive !== undefined) {
        await admin.auth().setCustomUserClaims(uid, {
          role: 'alumno',
          isActive: isActive
        });
      }

      // Actualizar displayName en Firebase Auth si el nombre cambió
      if (fullName) {
        await admin.auth().updateUser(uid, {
          displayName: fullName
        });
      }

      return res.json({
        success: true,
        message: 'Alumno actualizado exitosamente',
        data: {
          uid: uid,
          updatedFields: Object.keys(updateData).filter(key => key !== 'updatedAt')
        }
      });

    } catch (error) {
      console.error('Error actualizando alumno:', error);
      return res.status(500).json({
        success: false,
        message: 'Error al actualizar alumno'
      });
    }
  });

  // Eliminar alumno (solo docentes y admin)
  app.delete('/estudiantes/:uid', verifyFirebaseToken, requireDocenteOrAdmin, async (req, res) => {
    try {
      const { uid } = req.params;
      const { permanent = false } = req.query; // Parámetro para eliminación permanente

      // Verificar que el alumno existe
      const alumnoDoc = await admin.firestore()
        .collection('users')
        .doc(uid)
        .get();

      if (!alumnoDoc.exists) {
        return res.status(404).json({
          success: false,
          message: 'Alumno no encontrado'
        });
      }

      const alumnoData = alumnoDoc.data()!;

      // Verificar que es un alumno
      if (alumnoData.role !== 'alumno') {
        return res.status(400).json({
          success: false,
          message: 'El usuario no es un alumno'
        });
      }

      // Si es docente, verificar que él registró al alumno
      if (req.user!.role === 'docente' && alumnoData.docenteRegistrador !== req.user!.uid) {
        return res.status(403).json({
          success: false,
          message: 'No tienes permisos para eliminar este alumno'
        });
      }

      if (permanent === 'true') {
        // Eliminación permanente (solo admin)
        if (req.user!.role !== 'admin') {
          return res.status(403).json({
            success: false,
            message: 'Solo los administradores pueden realizar eliminaciones permanentes'
          });
        }

        // Eliminar de Firebase Auth
        await admin.auth().deleteUser(uid);

        // Eliminar documento de Firestore
        await admin.firestore()
          .collection('users')
          .doc(uid)
          .delete();

        return res.json({
          success: true,
          message: 'Alumno eliminado permanentemente',
          data: {
            uid: uid,
            type: 'permanent_deletion'
          }
        });
      } else {
        // Eliminación lógica (desactivar)
        await admin.firestore()
          .collection('users')
          .doc(uid)
          .update({
            isActive: false,
            deletedAt: admin.firestore.FieldValue.serverTimestamp(),
            deletedBy: req.user!.uid,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });

        // Actualizar custom claims
        await admin.auth().setCustomUserClaims(uid, {
          role: 'alumno',
          isActive: false
        });

        return res.json({
          success: true,
          message: 'Alumno desactivado exitosamente',
          data: {
            uid: uid,
            type: 'logical_deletion'
          }
        });
      }

    } catch (error) {
      console.error('Error eliminando alumno:', error);
      return res.status(500).json({
        success: false,
        message: 'Error al eliminar alumno'
      });
    }
  });

  // ===== GESTIÓN DE USUARIOS GENERAL (Solo Admin) =====

  // Listar todos los usuarios (solo admin)
  app.get('/users', verifyFirebaseToken, requireAdmin, async (req, res) => {
    try {
      const { role, limit = 100, page = 1 } = req.query;

      let query: any = admin.firestore().collection('users');

      // Filtrar por rol si se especifica
      if (role && typeof role === 'string') {
        query = query.where('role', '==', role);
      }

      // Paginación
      const limitNum = parseInt(limit as string);
      const pageNum = parseInt(page as string);
      const offset = (pageNum - 1) * limitNum;

      const snapshot = await query
        .orderBy('createdAt', 'desc')
        .limit(limitNum)
        .offset(offset)
        .get();

      const users = snapshot.docs.map((doc: any) => {
        const data = doc.data();
        return {
          uid: doc.id,
          email: data.email,
          fullName: data.fullName,
          role: data.role,
          isActive: data.isActive,
          matricula: data.matricula || null,
          grado: data.grado || null,
          seccion: data.seccion || null,
          telefono: data.telefono || null,
          docenteRegistrador: data.docenteRegistrador || null,
          createdAt: data.createdAt
        };
      });

      // Contar total de documentos
      const totalSnapshot = await admin.firestore()
        .collection('users')
        .select()
        .get();

      return res.json({
        success: true,
        message: `${users.length} usuarios encontrados`,
        data: {
          users: users,
          pagination: {
            page: pageNum,
            limit: limitNum,
            total: totalSnapshot.size,
            totalPages: Math.ceil(totalSnapshot.size / limitNum)
          }
        }
      });

    } catch (error) {
      console.error('Error obteniendo usuarios:', error);
      return res.status(500).json({
        success: false,
        message: 'Error al obtener lista de usuarios'
      });
    }
  });

  // ===== GESTIÓN DE SALONES (MODULAR) =====
  app.use('/salones', salonesRoutes);

  // ===== GESTIÓN DE ASISTENCIAS (MODULAR) =====
  app.use('/asistencias', createAsistenciasRoutes());

  // ===== ADMINISTRACIÓN DE USUARIOS (MODULAR) =====
  app.use('/admin', verifyFirebaseToken, requireAdmin, adminRoutes);

  // ===== MANEJO DE ERRORES =====

  app.use('*', (req, res) => {
    res.status(404).json({
      success: false,
      message: `Endpoint ${req.method} ${req.originalUrl} no encontrado`
    });
  });

  app.use((error: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
    console.error('Error no manejado:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  });

  return app;
}

/**
 * Cloud Function principal
 */
export const api = onRequest({
  maxInstances: 10,
  timeoutSeconds: 30,
  memory: '256MiB',
  cors: true
}, createApp());

// Export de funciones de Telegram
export { sendTelegramNotification, sendTelegramNotificationLegacy, handleTelegramWebhook } from './telegram';

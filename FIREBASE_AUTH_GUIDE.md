# 🔥 Firebase Auth - Sistema de Asistencias

## ✅ **¡Sistema Implementado con Firebase Auth Nativo!**

### **🎯 Lo que Tienes Ahora:**

✅ **Firebase Authentication** - Sistema completo de autenticación  
✅ **Firebase Admin SDK** - Gestión de usuarios desde el backend  
✅ **Firestore** - Base de datos para perfiles de usuario  
✅ **Custom Claims** - Roles y permisos integrados  
✅ **Password Reset** - Recuperación de contraseña nativa  

---

## 🚀 **Cómo Usar el Sistema**

### **1. Crear Primer Administrador**

**Endpoint de Setup (solo desarrollo):**
```http
POST http://127.0.0.1:5001/asistencia-alumnos-2025/us-central1/api/auth/setup-admin
Content-Type: application/json

{
  "email": "admin@escuela.com",
  "password": "admin123456"
}
```

### **2. Frontend - Autenticación con Firebase**

**En tu app frontend (React/Vue/Angular):**

```javascript
// Instalar Firebase SDK
npm install firebase

// Configurar Firebase
import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword, createUserWithEmailAndPassword } from 'firebase/auth';

const firebaseConfig = {
  apiKey: "tu-api-key",
  authDomain: "asistencia-alumnos-2025.firebaseapp.com",
  projectId: "asistencia-alumnos-2025",
  // ... resto de configuración
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);

// LOGIN - El usuario obtiene token automáticamente
async function login(email, password) {
  try {
    const userCredential = await signInWithEmailAndPassword(auth, email, password);
    const user = userCredential.user;
    
    // Obtener token JWT para usar en backend
    const token = await user.getIdToken();
    
    // Obtener perfil completo del backend
    const response = await fetch('/api/auth/profile', {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });
    
    const profile = await response.json();
    return { user, token, profile };
    
  } catch (error) {
    console.error('Error en login:', error.message);
  }
}

// RESET PASSWORD - Firebase maneja todo automáticamente
import { sendPasswordResetEmail } from 'firebase/auth';

async function resetPassword(email) {
  try {
    await sendPasswordResetEmail(auth, email);
    console.log('Email de recuperación enviado');
  } catch (error) {
    console.error('Error:', error.message);
  }
}
```

### **3. Registrar Docentes (Solo Admin)**

```javascript
// El admin usa su token para registrar docentes
async function registerDocente(adminToken, docenteData) {
  const response = await fetch('/api/auth/register-docente', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${adminToken}`
    },
    body: JSON.stringify({
      email: 'docente@escuela.com',
      password: 'docente123',
      fullName: 'Profesor Juan Pérez',
      profile: {
        department: 'Matemáticas',
        phoneNumber: '+123456789'
      }
    })
  });
  
  return await response.json();
}
```

---

## 📋 **Endpoints Disponibles**

### **🔓 Públicos (sin autenticación):**
- `GET /` - Información de la API
- `GET /health` - Health check
- `POST /auth/setup-admin` - Crear primer admin (solo desarrollo)
- `POST /auth/reset-password` - Solicitar reset (usa Firebase nativo)

### **🔒 Protegidos (requieren token Firebase):**
- `GET /auth/profile` - Obtener perfil del usuario autenticado
- `GET /auth/verify` - Verificar token

### **👑 Solo Administradores:**
- `POST /auth/register-docente` - Registrar nuevo docente

---

## 🔑 **Flujo de Autenticación**

### **Para Usuarios (Docentes):**
1. **Login**: Usar Firebase Auth en frontend
2. **Token**: Firebase genera token JWT automáticamente
3. **Backend**: Usar token para llamadas a API protegidas
4. **Reset**: Firebase maneja recuperación de contraseña

### **Para Administradores:**
1. **Login**: Igual que docentes con Firebase Auth
2. **Registro**: Pueden crear docentes usando endpoint backend
3. **Gestión**: Acceso completo a todas las funciones

---

## 🛡️ **Seguridad Implementada**

### **Firebase Auth Nativo:**
- ✅ Tokens JWT seguros y auto-renovables
- ✅ Verificación de email automática
- ✅ Rate limiting integrado
- ✅ Protección contra ataques comunes

### **Custom Claims:**
- ✅ Roles almacenados en token JWT
- ✅ Verificación de permisos en tiempo real
- ✅ No requiere consultas adicionales a DB

### **Firestore Security Rules:**
```javascript
// Usar las reglas en firestore.rules.new
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null && 
                     (request.auth.uid == userId || 
                      request.auth.token.role == 'admin');
      
      allow create: if request.auth != null && 
                       request.auth.token.role == 'admin';
    }
  }
}
```

---

## 🚀 **Próximos Pasos**

### **1. Configurar Frontend:**
```bash
# Instalar Firebase SDK en tu frontend
npm install firebase

# Configurar con tu config de Firebase
# Implementar login/registro/reset password
```

### **2. Probar Sistema:**
```bash
# 1. Crear admin
curl -X POST http://127.0.0.1:5001/asistencia-alumnos-2025/us-central1/api/auth/setup-admin \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@escuela.com","password":"admin123456"}'

# 2. Login desde frontend y obtener token

# 3. Registrar docente con token de admin
curl -X POST http://127.0.0.1:5001/asistencia-alumnos-2025/us-central1/api/auth/register-docente \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <admin-firebase-token>" \
  -d '{"email":"docente@escuela.com","password":"docente123","fullName":"Profesor Demo"}'
```

### **3. Implementar Funcionalidades:**
- 📝 Gestión de estudiantes
- 📊 Registro de asistencias  
- 📈 Reportes y estadísticas
- 📱 API para app móvil

---

## 💡 **Ventajas de Firebase Auth**

✅ **Sin reinventar la rueda** - Sistema probado y seguro  
✅ **Escalable** - Maneja millones de usuarios  
✅ **Integrado** - SDK para web, móvil, backend  
✅ **Seguro** - Estándares de seguridad de Google  
✅ **Fácil** - Menos código, más funcionalidad  

¡El sistema está listo para usar con autenticación real de Firebase! 🎉

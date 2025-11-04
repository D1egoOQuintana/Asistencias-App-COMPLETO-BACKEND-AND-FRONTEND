# 🏫 Sistema de Asistencias Escolares (Monorepo)

Sistema completo de control de asistencias escolares con backend Firebase y app móvil Flutter en un solo repositorio.

## 📦 Componentes del Proyecto

### 📱 **App Móvil Flutter** (`asistencias_app/`)
- App multiplataforma (Android/iOS)
- Material Design 3
- Navegación moderna con GoRouter
- State management con Provider
- Escaneo QR para registro de asistencias
- Gestión de estudiantes y aulas

### 🔧 **Backend Firebase** (`functions/`)
- Firebase Cloud Functions con TypeScript
- Arquitectura limpia (Domain, Data, Presentation)
- API REST con autenticación JWT
- Firestore para base de datos
- Security Rules basadas en roles

---

## 🚀 Características Principales

### ✅ **Sistema Completo de Asistencias**
- 📸 Registro de asistencias por QR code
- 👥 Gestión de estudiantes por aula
- 🏫 Administración de salones/aulas
- 📊 Estadísticas y reportes en tiempo real
- 📱 Interfaz responsiva moderna

### ✅ **Autenticación y Roles**
- 🔐 Login seguro con email/contraseña
- 👨‍💼 Roles: Admin y Docente
- 🔑 Recuperación de contraseña vía email
- 🛡️ JWT tokens y custom claims
- 📝 Middleware de autorización

### ✅ **Arquitectura Moderna**
- **Flutter**: Material 3, Provider, GoRouter
- **Backend**: Clean Architecture, TypeScript strict
- **Firebase**: Firestore, Auth, Functions, Storage
- **Seguridad**: Security Rules, validaciones estrictas
- **CI/CD**: Scripts automatizados de deploy

---

## 📁 Estructura del Proyecto

```
asistencias-backend/
│
├── 📱 asistencias_app/            # App Flutter
│   ├── lib/
│   │   ├── models/                # Modelos de datos
│   │   ├── providers/             # State management
│   │   ├── screens/               # Pantallas de la app
│   │   │   ├── admin/             # Pantallas de administrador
│   │   │   ├── teacher/           # Pantallas de docente
│   │   │   └── auth/              # Autenticación
│   │   ├── services/              # Servicios Firebase
│   │   ├── widgets/               # Componentes reutilizables
│   │   ├── theme/                 # Tema y estilos
│   │   └── routes/                # Navegación GoRouter
│   ├── assets/                    # Imágenes y recursos
│   ├── android/                   # Configuración Android
│   ├── ios/                       # Configuración iOS
│   └── pubspec.yaml               # Dependencias Flutter
│
├── 🔧 functions/                  # Backend Firebase
│   ├── src/
│   │   ├── domain/                # Capa de Dominio
│   │   │   ├── entities/          # Entidades de negocio
│   │   │   ├── repositories/      # Interfaces
│   │   │   └── usecases/          # Lógica de negocio
│   │   ├── data/                  # Capa de Datos
│   │   │   └── repositories/      # Implementaciones Firebase
│   │   ├── presentation/          # Capa de Presentación
│   │   │   ├── controllers/       # Controladores REST
│   │   │   ├── middleware/        # Auth middleware
│   │   │   └── routes/            # Rutas API
│   │   └── utils/                 # Utilidades
│   ├── tsconfig.json              # Config TypeScript
│   └── package.json               # Dependencias Node
│
├── 📄 firebase.json               # Configuración Firebase
├── 📄 firestore.rules             # Reglas de seguridad
├── 📄 firestore.indexes.json      # Índices Firestore
├── 📄 .firebaserc                 # Proyectos Firebase
└── 📄 README.md                   # Este archivo
```

---

## 🔧 Instalación y Configuración

### **1. Prerrequisitos**
```bash
# Flutter SDK 3.24+
flutter --version

# Node.js 20+ y npm
node --version  # v20.18.0+
npm --version   # 10.8.2+

# Firebase CLI
npm install -g firebase-tools
firebase login
```

### **2. Configurar Backend (Firebase Functions)**
```bash
# Navegar al directorio
cd functions

# Instalar dependencias
npm install

# Compilar TypeScript
npm run build

# Configurar Firebase (si es primera vez)
firebase use --add  # Selecciona tu proyecto Firebase
```

### **3. Configurar App Flutter**
```bash
# Navegar al directorio
cd asistencias_app

# Instalar dependencias
flutter pub get

# Configurar Firebase para Flutter
flutterfire configure

# Ejecutar en emulador/dispositivo
flutter run
```

### **4. Variables de Entorno**

#### Backend (`functions/.env.production`):
```env
# No incluir en Git - usar .env.example como template
AUTH_PASSWORD_RESET_URL=https://tuapp.com/reset
CORS_ALLOWED_ORIGINS=https://tuapp.com
```

#### App Flutter:
- Configurar `google-services.json` (Android)
- Configurar `GoogleService-Info.plist` (iOS)
- **¡No subir estos archivos a GitHub!**

---

## 🚀 Desarrollo y Testing

### **Backend - Scripts disponibles**
```bash
cd functions

npm run build      # Compilar TypeScript
npm run watch      # Compilar en modo watch
npm run serve      # Iniciar emuladores locales
npm run deploy     # Desplegar a Firebase
npm run lint       # Ejecutar ESLint
npm run lint:fix   # Corregir errores automáticamente
```

### **App Flutter - Comandos útiles**
```bash
cd asistencias_app

flutter run                 # Ejecutar en dispositivo
flutter run -d chrome       # Ejecutar en navegador
flutter clean               # Limpiar build cache
flutter pub get             # Actualizar dependencias
flutter build apk           # Build Android APK
flutter build ios           # Build iOS (solo en macOS)
```

### **Emuladores Firebase Locales**
```bash
# Iniciar todos los emuladores
firebase emulators:start

# URLs disponibles:
# - Functions: http://localhost:5001
# - Firestore: http://localhost:8080  
# - Auth: http://localhost:9099
# - UI: http://localhost:4000
```

---

## 📡 API Endpoints (Backend)

### **Autenticación**

#### **📝 Registrar Docente** (Solo Admin)
```http
POST /auth/register-docente
Authorization: Bearer <admin-token>
Content-Type: application/json

{
  "email": "docente@escuela.com",
  "password": "contraseña123",
  "fullName": "Juan Pérez",
  "profile": {
    "department": "Matemáticas",
    "phoneNumber": "+123456789"
  }
}
```

#### **🔑 Iniciar Sesión**
```http
POST /auth/login
Content-Type: application/json

{
  "email": "docente@escuela.com",
  "password": "contraseña123"
}
```

#### **🔄 Recuperar Contraseña**
```http
POST /auth/reset-password
Content-Type: application/json

{
  "email": "docente@escuela.com"
}
```

#### **👤 Obtener Perfil**
```http
GET /auth/profile
Authorization: Bearer <token>
```

#### **✅ Verificar Token**
```http
GET /auth/verify
Authorization: Bearer <token>
```

### **Respuestas de la API**

**Respuesta exitosa:**
```json
{
  "success": true,
  "message": "Operación exitosa",
  "data": {
    "user": {
      "uid": "abc123",
      "email": "docente@escuela.com",
      "fullName": "Juan Pérez",
      "role": "docente",
      "isActive": true
    },
    "accessToken": "eyJhbGciOiJSUzI1NiIs..."
  },
  "meta": {
    "timestamp": "2025-08-20T10:30:00.000Z"
  }
}
```

**Respuesta de error:**
```json
{
  "success": false,
  "message": "Email y contraseña son requeridos",
  "error": {
    "code": "VALIDATION_ERROR"
  },
  "meta": {
    "timestamp": "2025-08-20T10:30:00.000Z"
  }
}
```

## 🔒 Seguridad y Roles

### **Roles del Sistema**
- **`admin`**: Acceso completo, puede registrar docentes
- **`docente`**: Acceso limitado, puede gestionar sus clases

### **Firestore Security Rules**
Las reglas de seguridad están en `firestore.rules.new` y siguen estas políticas:

```javascript
// Ejemplo de reglas de usuarios
match /users/{userId} {
  allow read: if canAccessUserData(userId);
  allow create: if isAdmin();
  allow update: if isOwnerOrAdmin(userId);
  allow delete: if isAdmin();
}
```

### **Middleware de Autenticación**
```typescript
// Proteger rutas que requieren autenticación
app.use('/protected', authMiddleware.authenticate);

// Proteger rutas solo para admin
app.use('/admin', authMiddleware.requireAdmin);

// Proteger rutas para docentes o superior
app.use('/docente', authMiddleware.requireDocente);
```

## 📊 Estructura de Datos

### **Usuario (Firestore)**
```typescript
interface User {
  uid: string;
  email: string;
  fullName: string;
  role: 'admin' | 'docente';
  createdAt: Date;
  updatedAt: Date;
  isActive: boolean;
  profile?: {
    phoneNumber?: string;
    department?: string;
    avatarUrl?: string;
  };
}
```

## 🧪 Testing y Desarrollo

### **Scripts disponibles**
```bash
npm run build      # Compilar TypeScript
npm run watch      # Compilar en modo watch
npm run serve      # Compilar + iniciar emuladores
npm run deploy     # Compilar + desplegar a Firebase
npm run lint       # Ejecutar ESLint
npm run lint:fix   # Corregir errores de lint automáticamente
```

### **URLs de Emuladores Locales**
- **Functions**: http://localhost:5001
- **Firestore**: http://localhost:8080
- **Firebase UI**: http://localhost:4000

---

## 🧹 Limpieza del Proyecto para GitHub

### **Script Automático**
```powershell
# Ver qué se eliminará (simulación)
.\limpiar-github.ps1 -WhatIf

# Ejecutar limpieza real
.\limpiar-github.ps1

# Mantener todas las plataformas Flutter
.\limpiar-github.ps1 -KeepPlatforms
```

### **Archivos que se eliminan automáticamente:**
- ✅ `asistencias_app/.dart_tool/` - Cache de Dart
- ✅ `asistencias_app/build/` - Build output
- ✅ `functions/node_modules/` - Dependencias Node (npm install las regenera)
- ✅ `functions/lib/` - JavaScript compilado (npm run build lo regenera)
- ✅ Plataformas no usadas: linux/, macos/, web/, windows/ (opcional)
- ✅ Archivos temporales y backups

### **Espacio ahorrado:** ~500MB - 1GB

### **⚠️ Nunca subir a GitHub:**
- ❌ `.env` con credenciales reales
- ❌ `google-services.json` (Android)
- ❌ `GoogleService-Info.plist` (iOS)
- ❌ Claves API o tokens

**Ver guía completa:** [`LIMPIAR_PROYECTO.md`](LIMPIAR_PROYECTO.md)

---

## 🚀 Despliegue

### **Desplegar a Firebase**
```bash
# Compilar y desplegar
npm run deploy

# Solo funciones específicas
firebase deploy --only functions:api
firebase deploy --only functions:auth
```

### **Variables de Entorno**
```bash
# Configurar en Firebase
firebase functions:config:set \
  auth.password_reset_url="https://tuapp.com/reset" \
  cors.allowed_origins="https://tuapp.com,https://admin.tuapp.com"

# Ver configuración actual
firebase functions:config:get
```

## 📝 Ejemplos de Uso

### **1. Crear primer usuario admin (desde Firebase Console)**
```javascript
// Ejecutar en Firebase Console
const user = await admin.auth().createUser({
  email: 'admin@escuela.com',
  password: 'admin123456'
});

await admin.auth().setCustomUserClaims(user.uid, {
  role: 'admin',
  isActive: true
});

await admin.firestore().collection('users').doc(user.uid).set({
  email: 'admin@escuela.com',
  fullName: 'Administrador',
  role: 'admin',
  isActive: true,
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  updatedAt: admin.firestore.FieldValue.serverTimestamp()
});
```

### **2. Integración con frontend**
```typescript
// Frontend - Login
const response = await fetch('/auth/login', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    email: 'docente@escuela.com',
    password: 'contraseña123'
  })
});

const { data } = await response.json();
localStorage.setItem('authToken', data.accessToken);
```

## 🤝 Buenas Prácticas Implementadas

✅ **Código limpio y modular** - Separación clara de responsabilidades  
✅ **TypeScript strict mode** - Tipado fuerte en todo el proyecto  
✅ **Firebase Security Rules** - Autorización basada en roles  
✅ **Arquitectura limpia** - Domain, Data, Presentation layers  
✅ **Documentación completa** - JSDoc en cada función  
✅ **Manejo de errores** - Respuestas estandarizadas  
✅ **Validaciones estrictas** - Entrada y salida de datos  

## 📞 Soporte

Para dudas o problemas:
1. Revisar logs: `firebase functions:log`
2. Verificar emuladores locales
3. Consultar documentación de Firebase

---

**Desarrollado con 💚 siguiendo las mejores prácticas 2025**

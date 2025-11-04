# 🚀 Configuración de Base de Datos - Sistema de Asistencias

## 📋 Credenciales de Acceso

### 👨‍💼 Administrador
- **Email:** `admin@escuela.com`
- **Contraseña:** `admin123456`
- **Rol:** Administrador
- **Permisos:** Gestión completa del sistema

### 👩‍🏫 Docentes
1. **Carlos Martínez**
   - **Email:** `carlos.martinez@escuela.com`
   - **Contraseña:** `docente123`
   - **Materia:** Matemáticas
   - **Aula:** Primero A

2. **Ana López**
   - **Email:** `ana.lopez@escuela.com`
   - **Contraseña:** `docente123`
   - **Materia:** Comunicación
   - **Aula:** Segundo B

3. **Pedro Silva**
   - **Email:** `pedro.silva@escuela.com`
   - **Contraseña:** `docente123`
   - **Materia:** Ciencias
   - **Aula:** Tercero A

## 🗄️ Datos que se crearán

### 🏫 Aulas (3)
- **Primero A** - Carlos Martínez (Capacidad: 25)
- **Segundo B** - Ana López (Capacidad: 30)
- **Tercero A** - Pedro Silva (Capacidad: 28)

### 👨‍🎓 Estudiantes (7)
**Primero A:**
- Juan Pérez (DNI: 12345678)
- María García (DNI: 23456789)
- Carlos López (DNI: 34567890)

**Segundo B:**
- Ana Martínez (DNI: 45678901)
- Luis Rodríguez (DNI: 56789012)

**Tercero A:**
- Sofía Fernández (DNI: 67890123)
- Diego Torres (DNI: 78901234)

### 📊 Registros de Asistencia
- Asistencias simuladas de los últimos 5 días
- Diferentes estados: Presente, Ausente, Tardanza, Justificado
- Incluye códigos QR únicos para cada estudiante

## 🛠️ Instrucciones de Uso

### 1. Acceder a la Configuración
1. Inicia sesión como administrador
2. En el menú lateral, busca **"🔧 Configurar BD"**
3. Haz clic para acceder a la pantalla de configuración

### 2. Inicializar Base de Datos
1. En la pantalla de configuración, haz clic en **"Inicializar Base de Datos"**
2. Espera a que se complete el proceso
3. Verás el mensaje de confirmación cuando termine

### 3. Verificar Estado
- Usa **"Verificar Estado"** para ver cuántos registros hay en cada colección
- Revisa la consola del navegador para más detalles

### 4. Limpiar Base de Datos (si es necesario)
- **⚠️ CUIDADO:** Esta acción elimina TODOS los datos
- Solo usar para empezar de nuevo

## 🔍 Cómo Probar el Sistema

### Como Administrador:
1. Ve a **"✅ Estudiantes (Funcional)"** para gestionar estudiantes
2. Ve a **"✅ Aulas (Funcional)"** para gestionar aulas
3. Gestiona docentes en **"Gestión de Docentes"**

### Como Docente:
1. Inicia sesión con credenciales de docente
2. Ve a **"✅ QR Simple (Funcional)"** para simular asistencia QR
3. Usa **"Tomar Asistencia"** para registros manuales

## 📱 URLs de Acceso
- **Aplicación:** http://localhost:8080
- **Firebase Console:** https://console.firebase.google.com/

## 🔧 Características Implementadas

✅ **Pantallas Funcionales:**
- Gestión de estudiantes con formularios y validación
- Gestión de aulas con asignación de profesores
- Simulador de QR para asistencias
- Dashboard con navegación por roles

✅ **Base de Datos:**
- Firestore configurado con reglas de seguridad
- Colecciones: users, classrooms, students, attendance
- Datos de ejemplo listos para usar

✅ **Autenticación:**
- Firebase Auth integrado
- Roles diferenciados (admin/docente)
- Navegación según permisos

## 📞 Soporte
Si tienes problemas:
1. Revisa la consola del navegador para errores
2. Verifica que Firebase esté configurado correctamente
3. Asegúrate de tener conexión a internet

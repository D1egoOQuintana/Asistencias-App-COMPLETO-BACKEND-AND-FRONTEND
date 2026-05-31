# DOCUMENTACIÓN MAESTRA — SISTEMA INTELIGENTE DE ASISTENCIA QR
**Versión:** 1.0  
**Fecha:** 2026-05-23  
**Estado:** Referencia estructural oficial del sistema  
**Audiencia:** Desarrolladores, evaluadores, redactores de manuales, directivos  

---

## ÍNDICE

1. [Visión General del Producto](#1-visión-general-del-producto)
2. [Problema que Resuelve](#2-problema-que-resuelve)
3. [Propuesta de Valor](#3-propuesta-de-valor)
4. [Roles del Sistema](#4-roles-del-sistema)
5. [Arquitectura General](#5-arquitectura-general)
6. [Módulos Principales](#6-módulos-principales)
7. [Flujo Funcional Completo](#7-flujo-funcional-completo)
8. [Flujo QR](#8-flujo-qr)
9. [Flujo Telegram](#9-flujo-telegram)
10. [Flujo de Reportes](#10-flujo-de-reportes)
11. [Flujo de Análisis con IA](#11-flujo-de-análisis-con-ia)
12. [Arquitectura Firebase](#12-arquitectura-firebase)
13. [Estructura Firestore](#13-estructura-firestore)
14. [Navegación de Pantallas](#14-navegación-de-pantallas)
15. [Dependencias Importantes](#15-dependencias-importantes)
16. [Riesgos Operativos Detectados](#16-riesgos-operativos-detectados)
17. [Problemas UX Detectados](#17-problemas-ux-detectados)
18. [Funcionalidades Más Importantes](#18-funcionalidades-más-importantes)
19. [Funcionalidades Más Impactantes para Demo](#19-funcionalidades-más-impactantes-para-demo)
20. [Posibles Mejoras Futuras](#20-posibles-mejoras-futuras)

---

## 1. VISIÓN GENERAL DEL PRODUCTO

### Nombre del sistema
**Sistema Inteligente de Asistencia QR** — Asistencias App

### Descripción ejecutiva
Aplicación móvil y web para la gestión automatizada de asistencia escolar mediante códigos QR, integrada con el sistema de mensajería Telegram para notificaciones instantáneas a padres de familia, y con generación de reportes en formatos oficiales peruanos (SIAGIE / UGEL 06).

### Contexto institucional
Diseñado para instituciones educativas del Perú bajo el marco de la **UGEL 06 — Lima**, con soporte para formatos de reporte oficiales exigidos por el Ministerio de Educación (SIAGIE). El sistema atiende directamente las necesidades operativas de docentes, administradores escolares y padres de familia.

### Estado actual
- **Beta funcional** — acceso habilitado para roles admin y docente
- Rol alumno existe en el modelo de datos pero está **bloqueado** en el backend por política de beta
- Backend en Firebase Functions desplegado en región `us-central1`

### Stack tecnológico
| Capa | Tecnología |
|------|-----------|
| Frontend | Flutter 3.x (Dart), Material Design 3 |
| State management | Provider 6.1.2 + GetX |
| Backend | Firebase Functions v2, Node.js, TypeScript |
| HTTP framework | Express.js |
| Base de datos | Cloud Firestore (NoSQL, tiempo real) |
| Autenticación | Firebase Authentication (JWT) |
| Notificaciones | Telegram Bot API |
| Reportes | `pdf`, `excel` packages (generación on-device) |
| Navegación | GetX Router + PageView |

---

## 2. PROBLEMA QUE RESUELVE

### Contexto del problema
En la mayoría de instituciones educativas peruanas, el registro de asistencia escolar se realiza de forma **manual, en papel**, con las siguientes consecuencias:

| Problema | Impacto |
|----------|---------|
| El docente invierte 5-15 min por clase pasando lista verbalmente | Tiempo lectivo perdido diariamente |
| Los registros en papel se pierden, deterioran o alteran | Pérdida de información institucional |
| Los padres no saben si su hijo llegó al colegio | Inseguridad y comunicación reactiva |
| Generar reportes mensuales tarda horas | Carga administrativa excesiva |
| No existe análisis de patrones de ausentismo | Intervención tardía en casos críticos |
| Los formatos UGEL/SIAGIE requieren llenado manual | Error humano frecuente |

### Usuario afectado principal
- **Docente de aula:** sobrecargado con tareas administrativas
- **Director/Administrador:** sin visión global del ausentismo institucional
- **Padre de familia:** desinformado sobre la asistencia diaria de su hijo

---

## 3. PROPUESTA DE VALOR

### Para el DOCENTE
> "Registra la asistencia de todo tu salón en menos de 2 minutos, desde tu teléfono, con total precisión."

- Escaneo QR rápido por alumno (< 3 segundos por alumno)
- Validación automática de tardanzas según horario configurado
- Correcciones históricas sin necesidad de papel
- Exportación instantánea de reportes oficiales UGEL 06

### Para el ADMINISTRADOR
> "Gestiona docentes, aulas y horarios desde un panel centralizado."

- Alta de docentes y asignación de aulas en minutos
- Configuración de horarios por día de semana y aula
- Vista global de estadísticas del sistema

### Para el PADRE DE FAMILIA
> "Recibe una notificación en Telegram exactamente cuando tu hijo entra al colegio."

- Sin instalar apps adicionales (Telegram ya instalado)
- Vinculación en un solo tap desde un enlace compartido por WhatsApp
- Notificaciones de entrada y salida automáticas

### Diferencial competitivo
1. **QR + Telegram integrados:** sistema de circuito cerrado sin intervención manual del docente post-setup
2. **Formatos UGEL 06 oficiales:** PDF y Excel generados automáticamente, listos para firmar
3. **IA aplicada a educación:** análisis predictivo de ausentismo crónico con recomendaciones automáticas
4. **On-device generation:** los reportes se generan en el dispositivo sin depender de internet en el momento de exportación

---

## 4. ROLES DEL SISTEMA

### 4.1 Docente (`role: 'docente'`)

**Acceso:** Dashboard con navegación inferior — 4 tabs

| Función | Descripción |
|---------|-------------|
| Ver sus aulas asignadas | Solo aulas donde `teacherUid === uid` del docente |
| Iniciar sesión de asistencia | Abre un registro de sesión para el día |
| Escanear QR de alumnos | Registra entrada (y salida) vía cámara |
| Ver asistencias del día | Lista en tiempo real por aula |
| Corregir registros | Cambiar status, agregar/quitar salida |
| Registrar nuevos alumnos | Con DNI, nombre, teléfono apoderado |
| Compartir enlace Telegram | Vincula al padre con el bot |
| Ver historial en calendario | Asistencias por fecha seleccionable |
| Generar análisis IA | Reportes predictivos de ausentismo |
| Exportar PDF | Formato SIAGIE/UGEL 06 mensual |
| Exportar Excel | Formato UGEL 06 mensual con colores |

**Restricciones:**
- Solo ve sus propias aulas (no las de otros docentes)
- No puede crear aulas ni asignar horarios (responsabilidad del admin)
- No puede gestionar otros docentes

---

### 4.2 Administrador (`role: 'admin'`)

**Acceso:** Dashboard con AppBar + navegación inferior — 4 tabs

| Función | Descripción |
|---------|-------------|
| Ver estadísticas globales | Stream de últimas 120 asistencias del sistema |
| Gestionar docentes | Crear, activar, desactivar cuentas de docentes |
| Gestionar estudiantes | Vista global de todos los alumnos del sistema |
| Gestionar aulas | CRUD completo + configuración de horarios |
| Asignar docentes a aulas | Define el `teacherUid` de cada aula |
| Configurar horarios | `ClassSchedule` por día de semana, entrada, salida, máximo tardanza |

**Restricciones actuales (gaps detectados):**
- No tiene acceso a reportes de asistencia (PDF/Excel)
- No puede supervisar sesiones activas en tiempo real
- No tiene vista de ausentismo institucional global

---

### 4.3 Alumno (`role: 'alumno'`) — BLOQUEADO EN BETA

- Existe en el modelo de datos de Firestore
- El middleware `blockStudentAccess` del backend deniega todas las peticiones
- No tiene pantalla de acceso en el frontend actualmente
- El sistema los representa exclusivamente como objetos de datos con código QR

---

## 5. ARQUITECTURA GENERAL

```
┌──────────────────────────────────────────────────────────────────┐
│                      FLUTTER APP (Cliente)                        │
│                  Dart · Material 3 · Provider + GetX              │
│                                                                    │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────────┐   │
│  │  Auth Layer │  │   Providers  │  │      Screens          │   │
│  │  (Firebase) │  │  (State Mgmt)│  │  (UI por rol)         │   │
│  └─────────────┘  └──────────────┘  └───────────────────────┘   │
│                          │                                        │
│              ┌───────────┴───────────┐                           │
│              │       Services        │                           │
│  ┌───────────┴───────────────────────┴───────────┐              │
│  │ AttendanceService │ FirestoreService │ Auth... │              │
│  └───────────────────────────────────────────────┘              │
└─────────────────────────┬────────────────────────────────────────┘
                          │ Firebase SDK (Firestore SDK, Auth SDK,
                          │ Cloud Functions SDK)
          ┌───────────────┼────────────────────┐
          ▼               ▼                    ▼
   Firebase Auth     Firestore           Cloud Functions
   (JWT tokens)    (NoSQL RT DB)       (Node.js/TypeScript)
                                              │
                               ┌──────────────┼──────────────┐
                               ▼              ▼              ▼
                          Express API    Triggers       Callables
                          (REST CRUD)  (Firestore)    (IA/Reportes)
                                            │
                                     Telegram Bot API
                                     (axios → api.telegram.org)
```

### Comunicación cliente-servidor

| Tipo | Tecnología | Cuándo se usa |
|------|-----------|---------------|
| Tiempo real | Firestore Streams | Listas de asistencia, estado del aula |
| Lecturas puntuales | Firestore `.get()` | Cargar datos iniciales |
| Transacciones | Firestore `.runTransaction()` | Registro atómico de QR (anti-duplicados) |
| Funciones callable | `cloud_functions` SDK | Reportes IA, exportación estructurada |
| REST API | Bearer JWT → Express | Gestión CRUD admin (usuarios, aulas) |
| Triggers automáticos | Firestore triggers | Notificaciones Telegram al padre |

---

## 6. MÓDULOS PRINCIPALES

### Frontend (Flutter)

| Módulo | Archivos clave | Responsabilidad |
|--------|---------------|-----------------|
| **Auth** | `auth_provider.dart`, `login_screen.dart` | Login, estado de sesión, AuthWrapper |
| **Dashboard** | `modern_dashboard_screen.dart`, `improved_home_screen.dart` | Navegación por rol, Home con stats en vivo |
| **Asistencia QR** | `classroom_detail_screen.dart`, `quick_qr_attendance_screen.dart` | Escáner, sesiones, validaciones |
| **Correcciones** | `attendance_corrections_screen.dart` | Edición histórica de registros |
| **Estudiantes** | `teacher_students_screen.dart`, `teacher_create_student_screen.dart` | CRUD alumnos + Telegram linking |
| **Reportes** | `teacher_reports_screen.dart` | IA, PDF, Excel, estadísticas |
| **Admin** | `teachers_management_screen.dart`, `improved_classroom_screen.dart`, `improved_student_screen.dart` | Gestión global |
| **Servicios** | `attendance_service.dart`, `attendance_repository.dart`, `firestore_service.dart` | Lógica de negocio central |

### Backend (Firebase Functions)

| Módulo | Archivos | Responsabilidad |
|--------|---------|-----------------|
| **API REST principal** | `index.ts` | Express app, middlewares auth, rutas |
| **Telegram** | `telegram.ts` | Bot, vinculación, notificaciones, triggers |
| **Sincronización** | `attendance-sync.ts` | Mirror colección raíz `attendance` |
| **Salones** | `modules/salones/` | CRUD aulas vía API REST |
| **Asistencias** | `modules/asistencias/` | CRUD asistencias vía API REST |
| **Admin** | `modules/admin/` | Gestión usuarios admin |

---

## 7. FLUJO FUNCIONAL COMPLETO

### 7.1 Flujo completo del DOCENTE

```
[1] INICIO DE SESIÓN
    Pantalla Login
    └── Email + Password → Firebase Auth
    └── JWT generado → AuthWrapper → ModernDashboardScreen

[2] HOME (Tab 0)
    ImprovedHomeScreen
    ├── Reloj en vivo (actualizado cada 5s)
    ├── Tarjetas de aulas del día
    └── Stream últimas asistencias (colección raíz)

[3] MIS AULAS (Tab 1)
    TeacherClassroomsScreen
    └── Lista de aulas donde teacherUid = uid actual
    └── Tap aula → ClassroomDetailScreen
        ├── Horarios configurados del aula
        ├── Botón "Iniciar sesión" (OBLIGATORIO antes de escanear)
        ├── Calendario interactivo (TableCalendar)
        ├── Escáner QR embebido (MobileScanner)
        └── Lista de asistencias del día (Firestore Stream)

[4] ESCANEO QR
    └── Ver sección 8 (Flujo QR)

[5] CORRECCIONES
    └── Botón "Editar" → AttendanceCorrectionsScreen
        ├── Selector de fecha (max 90 días atrás)
        ├── Lista de registros del día
        └── Por registro: cambiar status + toggle salida manual

[6] ALUMNOS (Tab 2)
    TeacherStudentsScreen
    ├── Lista de alumnos del aula
    └── Botón "+" → TeacherCreateStudentScreen
        ├── Formulario: nombre, apellido, DNI, teléfono
        ├── Submit → StudentService.createStudent()
        ├── Auto-genera enlace Telegram (Cloud Function)
        └── Dialog: botón "Enviar por WhatsApp" → wa.me/51{phone}

[7] REPORTES (Tab 3)
    └── Ver sección 10 (Flujo de Reportes)
```

---

### 7.2 Flujo completo del ADMINISTRADOR

```
[1] INICIO DE SESIÓN
    Misma pantalla de login → rol detectado → AppBar "Panel Admin"

[2] HOME (Tab 0)
    ImprovedHomeScreen (buildAdminDashboard)
    ├── Estadísticas globales del sistema
    └── Stream de últimas 120 asistencias (nivel sistema)

[3] DOCENTES (Tab 1)
    TeachersManagementScreen
    ├── Lista de todos los docentes del sistema
    ├── Crear nuevo docente (email + nombre)
    └── Activar / desactivar cuentas (isActive)

[4] ESTUDIANTES (Tab 2)
    ImprovedStudentScreen
    ├── Vista global: TODOS los estudiantes del sistema
    ├── Búsqueda por nombre / DNI
    └── Ver / editar datos individuales

[5] AULAS (Tab 3)
    ImprovedClassroomScreen
    ├── Lista de todas las aulas del sistema
    ├── Crear nueva aula (nombre, grado, sección, capacidad, periodYear)
    ├── Asignar docente (teacherUid)
    ├── Configurar horarios por día de semana:
    │   { dayOfWeek, startTime, endTime, maxLateTime }
    └── Activar / desactivar aulas
```

---

## 8. FLUJO QR

### 8.1 Generación del código QR del alumno

```
StudentService.createStudent()
    └── Firestore genera studentId automático
    └── QR code contenido: JSON codificado
        {
          "type": "student",
          "id": "{studentId}",
          "name": "{firstName} {lastName}",
          "dni": "{dni}",
          "classroom": "{classroomId}"
        }
    └── Se almacena como campo qrCode en el documento del alumno
    └── Se puede mostrar en pantalla y compartir/imprimir
```

### 8.2 Registro de asistencia por QR (flujo detallado)

```
PRECONDICIÓN: Sesión de asistencia activa (attendanceActive = true)

[1] MobileScanner detecta código QR
    └── Debounce: si mismo QR en < 1200ms → ignorar (anti-spam físico)

[2] Decodificación y validación del QR
    ├── jsonDecode(rawValue) → debe ser Map
    ├── type === 'student' → válido
    ├── Contiene 'id' y 'name' → válido
    └── Si falla: modal "QR Inválido" (rojo)

[3] Validación de horario
    ├── Obtener ClassSchedule para el día de semana actual
    ├── Si no hay horario → modal "Sin Horario" (naranja)
    ├── Si ahora < startTime → modal "Fuera de Horario" (naranja)
    └── Si ahora > endTime → modal "Clase Finalizada" (rojo)

[4] Determinación de status
    └── Si ahora <= maxLateTime → status = 'present'
    └── Si ahora > maxLateTime → status = 'late'

[5] Anti-duplicados (doble verificación)
    ├── Pre-check: query Firestore por studentId + dateKey
    └── Si existe → modal "Ya Registrado" (naranja), fin del flujo

[6] Escritura atómica (Firestore Transaction)
    └── runTransaction:
        ├── get(ref) → si ya existe → throw 'YA_REGISTRADO'
        └── set(ref, {
              studentId, studentName, classroomId,
              sessionId, date (YYYY-MM-DD), status,
              timestamp: serverTimestamp(),
              entryAt: serverTimestamp()
            })

[7] Resultado visual
    ├── Modal "✅ Registrado" (verde) con nombre + status
    └── lastScannedCard actualiza con:
        nombre, DNI, aula, correo apoderado, teléfono, hora, status

[8] Trigger automático (Firestore → Cloud Function)
    └── onDocumentCreated → Telegram notifica al padre
        (ver sección 9)
```

### 8.3 Registro de salida por QR

```
FLUJO ALTERNATIVO: si ya existe registro de entrada sin salida

AttendanceRepository.registerQrScanForDay()
    ├── Detecta registro existente para el día
    ├── Si no tiene exitAt → agrega exitAt: serverTimestamp()
    │   → QrScanResultType.exitRegistered
    └── Si ya tiene exitAt → no modifica
        → QrScanResultType.exitAlreadyRegistered
```

### 8.4 Sesión de asistencia

```
INICIO:
    attendance_sessions.add({
      classroomId, teacherUid,
      startTime: serverTimestamp(),
      isActive: true,
      attendanceCount: 0,
      date: 'YYYY-MM-DD'
    })
    → sessionId guardado en estado local

DURANTE:
    Cada registro de QR referencia el sessionId activo

FIN:
    attendance_sessions.update(sessionId, {
      endTime: serverTimestamp(),
      isActive: false,
      attendanceCount: [conteo de docs con ese sessionId]
    })
```

---

## 9. FLUJO TELEGRAM

### 9.1 Vinculación padre-bot

```
[PASO 1] Docente crea alumno → dialog "Alumno creado"
         └── StudentService.generateTelegramActivationLink(studentId)
                 └── Cloud Function: genera código 6 dígitos (100000-999999)
                 └── activation_codes.add({
                       code, studentId, parentPhone (E.164),
                       expiresAt
                     })
                 └── Obtiene botUsername (cache o getMe API)
                 └── Construye URL: https://t.me/{botUsername}?start={code}
                 └── Retorna { startLink, whatsappMessage }

[PASO 2] Docente toca "Enviar por WhatsApp"
         └── Abre wa.me/51{phone}?text=...
         └── Mensaje: "Hola, su link de activacion para: {nombre}\n{startLink}"

[PASO 3] Padre recibe mensaje en WhatsApp
         └── Toca el enlace https://t.me/...?start={code}
         └── Se abre Telegram automáticamente
         └── Bot recibe /start {code}

[PASO 4] Bot procesa vinculación
         └── Busca activation_codes donde code === {code}
         └── Valida expiresAt
         └── Guarda chatId del padre vinculado al studentId
         └── Confirma vinculación al padre por Telegram
```

### 9.2 Notificaciones automáticas al padre

```
TRIGGER: onDocumentCreated('classrooms/{classroomId}/attendance/{docId}')
    └── o onDocumentWritten (para detectar cambios de entrada/salida)

PROCESAMIENTO:
    [1] Leer datos del documento de asistencia
        └── studentId, status, entryAt / exitAt / fechaHora / date

    [2] Obtener datos del estudiante (Firestore: students/{studentId})
        └── firstName, lastName, parentPhone

    [3] Normalizar teléfono a E.164 Perú
        └── toE164Peru(parentPhone):
            ├── 9 dígitos sin prefijo → +51{phone}
            └── Empieza con '51' → +{phone}

    [4] Buscar chatId del padre vinculado
        └── Query por parentPhone normalizado

    [5] Formatear fecha y hora
        └── Zona horaria: America/Lima
        └── Locale: es-PE
        └── Campos preferidos: entryAt → fechaHora → date → ahora()

    [6] Deduplicación por día
        └── getDayKeyLima(date): 'YYYY-MM-DD' en Lima
        └── Evita enviar múltiples notificaciones el mismo día

    [7] Enviar mensaje vía Telegram Bot API
        └── axios.post(https://api.telegram.org/bot{TOKEN}/sendMessage)
        └── { chat_id: chatId, text: "✅ {nombre} ingresó..." }

    [8] Log en telegram_events (diagnóstico)
        └── telegram_events.add({ ...evento, createdAt: now })
```

### 9.3 Formato del mensaje de notificación

```
Entrada:
"✅ Su hijo/a [Nombre Apellido] ingresó al colegio
📅 Fecha: [dd/mm/yyyy]
🕐 Hora: [hh:mm:ss]"

Salida:
"🏫 Su hijo/a [Nombre Apellido] salió del colegio
📅 Fecha: [dd/mm/yyyy]
🕐 Hora: [hh:mm:ss]"
```

---

## 10. FLUJO DE REPORTES

### 10.1 Fuente de datos

```
TeacherReportsScreen._getAttendanceData()
    ├── PRIMARIO: Cloud Function 'exportReportData'
    │   └── Parámetros: { classroomId, startDate, endDate, format: 'structured' }
    │   └── Retorna: { metadata, summary, studentSummaries, attendances, students }
    │
    └── FALLBACK (si Cloud Function falla):
        ├── Firestore: collection('attendances').where('classroomId', ...)
        │   ⚠️ ALERTA: colección 'attendances' puede estar vacía
        │   (la colección correcta es classrooms/{id}/attendance)
        └── Filtra por fecha EN MEMORIA (performance risk)
```

### 10.2 Métricas calculadas

| Métrica | Cálculo |
|---------|---------|
| Asistencia promedio | `(present + late) / total × 100` |
| Ausentismo crónico | Estudiantes con `absent/total >= 20%` |
| Tendencia semanal | 4 semanas del mes, % asistencia por semana |
| Total de sesiones | Días únicos con al menos un registro |

### 10.3 Exportación PDF (SIAGIE/UGEL 06)

```
_generatePDFReport()
    ├── Calcular rango: primer y último día del mes seleccionado
    ├── _getAttendanceData(customStart, customEnd)
    ├── Agrupar por estudiante: Map<studentId, Map<día, status>>
    ├── Crear pw.Document() con pw.MultiPage
    │   ├── Formato: A4 horizontal (landscape)
    │   ├── Margen: 15px todos los lados
    │   ├── Encabezado:
    │   │   ├── "REGISTRO DE ASISTENCIA" (título bold)
    │   │   ├── "Mes: {MMMM YYYY}"
    │   │   ├── "Aula: {nombre aula}"
    │   │   └── "UGEL 06 - LIMA" + fecha de generación
    │   ├── Tabla:
    │   │   ├── Columna N° (30px fijo)
    │   │   ├── Columna APELLIDOS Y NOMBRES (flexible x3)
    │   │   └── Columnas días 1-31 (flexible)
    │   ├── Símbolos: ✓ presente | T tardanza | F falta | J justificada
    │   ├── Leyenda explicativa
    │   └── Sección firmas: Docente | Director(a)
    └── Printing.sharePdf(bytes, filename: 'asistencia_{mes}_{año}.pdf')
```

### 10.4 Exportación Excel (UGEL 06)

```
_generateExcelReport()
    ├── Calcular rango: mes completo seleccionado
    ├── _getAttendanceData(customStart, customEnd)
    ├── Crear excel_pkg.Excel.createExcel()
    ├── Hoja: 'Asistencia {mes} {año}'
    ├── Estructura:
    │   ├── Fila 1: "REGISTRO DE ASISTENCIA - UGEL 06 LIMA"
    │   │          (merge A1 hasta columna daysInMonth+1)
    │   │          Estilo: bold, blanco sobre #1F4E78
    │   ├── Fila 2: "MES: {nombre}" | "AULA: {nombre}"
    │   ├── Fila 4: Headers: N° | APELLIDOS Y NOMBRES | 1 | 2 | ... | 31
    │   ├── Filas 5+: Un alumno por fila con símbolo por día
    │   │   Colores de celda:
    │   │   ├── present → #00B050 (verde)
    │   │   ├── late → #FFC000 (naranja)
    │   │   ├── absent → #FF0000 (rojo)
    │   │   └── justified → #0070C0 (azul)
    │   └── Leyenda: ✓ Presente | T Tardanza | F Falta | J Justificada
    ├── Anchos de columna: N°=5, Nombres=30, Días=4 (cada uno)
    └── Share.shareXFiles([XFile(path)], text: 'Reporte de Asistencia UGEL 06')
```

---

## 11. FLUJO DE ANÁLISIS CON IA

```
Usuario presiona "Generar análisis con IA"

[1] SINCRONIZACIÓN (2 segundos de espera artificial)
    └── Future.delayed(2s) — asegura propagación en Firestore

[2] OBTENER DATOS DE ASISTENCIA
    └── Cloud Function: 'getAttendanceReportData'
        Parámetros: { classroomId, startDate, endDate }
        Retorna: datos estructurados de asistencia

[3] GENERAR ANÁLISIS CON IA
    └── Cloud Function: 'generateReportWithAI'
        Parámetros: { classroomId, startDate, endDate, attendanceData }
        Retorna: {
          summary: String,         — resumen narrativo
          patterns: List<String>,  — patrones detectados
          recommendations: List<String>  — recomendaciones accionables
        }

[4] RENDERIZADO EN UI
    └── Panel "Análisis con IA" (ícono auto_awesome, color púrpura)
        ├── Sección "Resumen"
        ├── Sección "Patrones detectados" (lista con •)
        └── Sección "Recomendaciones" (lista con ícono lightbulb)

CASOS DE USO DETECTADOS POR LA IA:
    └── Estudiantes con ausentismo crónico (>= 20% faltas)
    └── Días de semana con mayor ausentismo
    └── Tendencias mensuales de asistencia
    └── Grupos de riesgo que requieren intervención temprana
```

---

## 12. ARQUITECTURA FIREBASE

### 12.1 Firebase Authentication

```
Proveedor: Email/Password
Flujo:
  1. signInWithEmailAndPassword() → IdToken JWT
  2. AuthProvider escucha authStateChanges()
  3. Frontend: token en memoria (SDK maneja refresh automático)
  4. Backend: Bearer token en header Authorization
  5. admin.auth().verifyIdToken(token) → decodedToken
  6. Cross-check con Firestore users/{uid}.isActive
```

### 12.2 Cloud Firestore

```
Modo: Native mode
Región: us-central1 (misma que Functions)
Reglas: firestore.rules (7KB)
Índices: firestore.indexes.json (compuestos para queries complejas)

Características usadas:
  - Streams (.snapshots()) → tiempo real en listas de asistencia
  - Transacciones (.runTransaction()) → anti-duplicados QR atómico
  - Server timestamps (FieldValue.serverTimestamp())
  - Subcollections (classrooms/{id}/attendance)
  - Compound queries (teacherUid + isActive + periodYear)
```

### 12.3 Cloud Functions v2

```
Región: us-central1
Configuración global:
  maxInstances: 10
  timeoutSeconds: 30
  memory: 256MiB

Funciones exportadas:
  Tipo HTTP (Express app):
    → api: maneja todas las rutas REST (/salones, /asistencias, /admin)

  Tipo Callable:
    → generateReportWithAI({ classroomId, startDate, endDate, attendanceData })
    → getAttendanceReportData({ classroomId, startDate, endDate })
    → exportReportData({ classroomId, startDate, endDate, format })
    → generateTelegramActivationLink({ studentId })

  Tipo Firestore Trigger:
    → onDocumentCreated('classrooms/{id}/attendance/{docId}')
      → notifica al padre via Telegram (entrada)
    → onDocumentWritten('classrooms/{id}/attendance/{docId}')
      → notifica al padre via Telegram (entrada/salida)
    → onDocumentWritten('classrooms/{id}/attendance/{docId}')
      → attendance-sync.ts → actualiza colección raíz
```

### 12.4 Middlewares del backend (index.ts)

```
verifyFirebaseToken:
  → Valida Bearer JWT con Firebase Admin
  → Cruza con Firestore users/{uid}
  → Verifica isActive
  → Adjunta req.user = { uid, email, role, fullName, isActive }

requireAdmin:
  → req.user.role === 'admin' || 403

requireDocenteOrAdmin:
  → req.user.role in ['admin', 'docente'] || 403

blockStudentAccess:
  → req.user.role === 'alumno' → 403 "versión beta"
```

---

## 13. ESTRUCTURA FIRESTORE

### 13.1 Diagrama de colecciones

```
Firestore
│
├── users/{uid}
│   ├── email: String
│   ├── fullName: String
│   ├── role: 'admin' | 'docente' | 'alumno'
│   ├── isActive: Boolean
│   ├── createdAt: Timestamp
│   └── updatedAt: Timestamp
│
├── classrooms/{classroomId}
│   ├── name: String
│   ├── grade: String              — ej: "5"
│   ├── section: String            — ej: "A"
│   ├── capacity: Int
│   ├── teacherUid: String         — FK → users
│   ├── isActive: Boolean
│   ├── periodYear: Int            — ej: 2026
│   ├── schedule: Map {
│   │   monday: { startTime, endTime, maxLateTime } | null
│   │   tuesday: ...
│   │   wednesday: ...
│   │   thursday: ...
│   │   friday: ...
│   │   saturday: ...
│   │   sunday: ...
│   │ }
│   ├── createdAt: Timestamp
│   ├── updatedAt: Timestamp
│   └── /attendance/{attendanceId}
│       ├── studentId: String      — FK → students
│       ├── studentName: String    — desnormalizado para performance
│       ├── classroomId: String    — redundante, facilita queries
│       ├── sessionId: String      — FK → attendance_sessions
│       ├── date: String           — formato 'YYYY-MM-DD'
│       ├── status: 'present' | 'absent' | 'late' | 'justified'
│       ├── timestamp: Timestamp
│       ├── entryAt: Timestamp
│       ├── exitAt: Timestamp | null
│       ├── exitSource: 'qr' | 'manual_correction' | null
│       ├── method: 'qr' | 'manual'
│       ├── updatedAt: Timestamp | null
│       └── editedFrom: String | null  — trazabilidad de correcciones
│
├── students/{studentId}
│   ├── firstName: String
│   ├── lastName: String
│   ├── dni: String
│   ├── classroomId: String        — FK → classrooms
│   ├── parentPhone: String | null — E.164 Perú (+51...)
│   ├── parentEmail: String | null
│   ├── qrCode: String             — JSON codificado del QR
│   ├── isActive: Boolean
│   ├── createdAt: Timestamp
│   └── updatedAt: Timestamp
│
├── attendance_sessions/{sessionId}
│   ├── classroomId: String
│   ├── teacherUid: String
│   ├── startTime: Timestamp
│   ├── endTime: Timestamp | null
│   ├── isActive: Boolean
│   ├── attendanceCount: Int
│   └── date: String               — 'YYYY-MM-DD'
│
├── activation_codes/{code}         — código de 6 dígitos como ID
│   ├── studentId: String
│   ├── parentPhone: String         — E.164
│   └── expiresAt: Timestamp
│
├── telegram_events/                — log de diagnóstico (append-only)
│   └── {autoId}
│       ├── type: String           — tipo de evento
│       ├── studentId: String
│       ├── chatId: String | null
│       ├── success: Boolean
│       ├── error: String | null
│       └── createdAt: Timestamp
│
└── attendance/                     — colección raíz SINCRONIZADA
    └── {attendanceId}              — mirror de classrooms/{id}/attendance
        ├── classroomId: String
        ├── studentId: String
        ├── status: String          — convertido desde formato subcollección
        ├── date: String
        ├── timestamp: Timestamp
        └── [campos adicionales legacy]
```

### 13.2 Índices compuestos requeridos (firestore.indexes.json)

Queries principales que requieren índices:
- `classrooms` where `teacherUid` + `isActive` + orderBy `updatedAt`
- `classrooms` where `teacherUid` + `periodYear`
- `classrooms/{id}/attendance` where `studentId` + `date`
- `classrooms/{id}/attendance` where `sessionId`
- `attendance` orderBy `timestamp` descending

---

## 14. NAVEGACIÓN DE PANTALLAS

### 14.1 Árbol completo de navegación

```
AuthWrapper (main.dart)
│
├── [No autenticado] → LoginScreen
│                       └── login_screen.dart
│                           └── [Login exitoso] → ModernDashboardScreen
│
└── [Autenticado] → ModernDashboardScreen
                    └── modern_dashboard_screen.dart
                        │
                        ├── [role: docente] — PageView con 4 tabs
                        │   ├── Tab 0: ImprovedHomeScreen
                        │   │         └── improved_home_screen.dart
                        │   │             └── Tap aula → TeacherClassroomsScreen
                        │   │
                        │   ├── Tab 1: TeacherClassroomsScreen
                        │   │         └── teacher_classrooms_screen.dart
                        │   │             └── Tap aula → ClassroomDetailScreen
                        │   │                           classroom_detail_screen.dart
                        │   │                           ├── Escáner QR embebido
                        │   │                           ├── Botón "Editar" →
                        │   │                           │   AttendanceCorrectionsScreen
                        │   │                           └── [Sesión activa] →
                        │   │                               AttendanceSessionScreen
                        │   │
                        │   ├── Tab 2: TeacherStudentsScreen
                        │   │         └── teacher_students_screen.dart
                        │   │             └── FAB "+" → TeacherCreateStudentScreen
                        │   │                           teacher_create_student_screen.dart
                        │   │                           └── [Éxito] → Dialog Telegram
                        │   │                               └── Botón WhatsApp (externo)
                        │   │
                        │   └── Tab 3: TeacherReportsScreen
                        │             └── teacher_reports_screen.dart
                        │                 ├── Tab "Resumen"
                        │                 ├── Tab "Listado"
                        │                 └── Tab "Análisis IA"
                        │
                        └── [role: admin] — PageView con 4 tabs
                            ├── Tab 0: ImprovedHomeScreen (admin view)
                            ├── Tab 1: TeachersManagementScreen
                            ├── Tab 2: ImprovedStudentScreen
                            └── Tab 3: ImprovedClassroomScreen
```

### 14.2 Pantallas por importancia operativa

| Prioridad | Pantalla | Rol | Frecuencia de uso |
|-----------|---------|-----|-------------------|
| 🔴 Crítica | `ClassroomDetailScreen` | Docente | Diaria |
| 🔴 Crítica | `LoginScreen` | Ambos | Por sesión |
| 🟠 Alta | `TeacherStudentsScreen` | Docente | Semanal |
| 🟠 Alta | `TeacherCreateStudentScreen` | Docente | Al iniciar año |
| 🟠 Alta | `ImprovedClassroomScreen` | Admin | Al iniciar año |
| 🟡 Media | `TeacherReportsScreen` | Docente | Mensual |
| 🟡 Media | `AttendanceCorrectionsScreen` | Docente | Según necesidad |
| 🟡 Media | `TeachersManagementScreen` | Admin | Al contratar |
| 🟢 Baja | `ImprovedHomeScreen` | Ambos | Referencia |
| 🟢 Baja | `ImprovedStudentScreen` | Admin | Consulta |

---

## 15. DEPENDENCIAS IMPORTANTES

### 15.1 Cadena de dependencias funcionales

```
CONFIGURACIÓN ADMIN (obligatoria antes de que el docente pueda usar el sistema)
    │
    ▼
Aula creada con:
    ├── teacherUid asignado ──────────────────────► Docente ve su aula
    ├── periodYear = año actual ──────────────────► Aula aparece en reportes
    ├── isActive = true ──────────────────────────► Aula visible
    └── schedule configurado ─────────────────────► PERMITE escaneo QR
                                                     (sin schedule → bloqueado)
    │
    ▼
DOCENTE crea alumno con:
    ├── parentPhone provisto ─────────────────────► Habilita Telegram + WhatsApp
    └── DNI provisto ─────────────────────────────► QR generado correctamente
    │
    ▼
DOCENTE inicia sesión de asistencia
    └── sessionId en estado local ────────────────► Permite procesamiento QR
        (sin sesión activa → QR ignorado silenciosamente)
    │
    ▼
ESCANEO QR exitoso
    └── documento creado en classrooms/{id}/attendance
    │
    ├── Trigger Firestore ────────────────────────► telegram.ts
    │       └── parentPhone en Firestore ──────────► Notifica al padre
    │
    └── attendance-sync.ts ───────────────────────► attendance/ (raíz)
            └── Home admin/docente muestra stats ──► Stream actualizado
```

### 15.2 Matriz de dependencias entre módulos

| Módulo | Depende de | Si falla |
|--------|-----------|----------|
| Escaneo QR | `schedule` del aula | Escáner bloqueado |
| Escaneo QR | `attendanceActive` | QR ignorado |
| Telegram notif. | `parentPhone` del alumno | Sin notificación |
| Telegram notif. | Cuenta bot activa | Sin notificación |
| TeacherReportsScreen | Cloud Functions | Usa fallback (puede fallar) |
| Home stats | `attendance-sync.ts` | Datos obsoletos |
| Reportes PDF/Excel | Datos de mes completo en Firestore | Exportación vacía |
| Análisis IA | 3 Cloud Functions en secuencia | Sin análisis |

### 15.3 Dependencia de datos legacy

```
FirestoreService.dart maneja compatibilidad:
    role: 'docente' === role: 'teacher'  → migración en progreso

AttendanceCorrectionsScreen:
    Maneja 3 tipos de campo 'date': String | Timestamp | DateTime
    → compatibilidad con datos históricos de diferentes versiones
```

---

## 16. RIESGOS OPERATIVOS DETECTADOS

### 16.1 Riesgos de uso diario (docente)

| ID | Riesgo | Probabilidad | Impacto | Síntoma visible |
|----|--------|-------------|---------|-----------------|
| R01 | Escanear sin iniciar sesión | **Alta** | Alto | QR no se registra, sin error visible |
| R02 | Aula sin horario configurado | Media | **Alto** | Modal "Sin Horario" bloquea todo escaneo |
| R03 | Olvidar finalizar sesión | Media | Medio | Sesión `isActive: true` indefinidamente |
| R04 | Alumno sin teléfono registrado | Media | Medio | Sin notificaciones Telegram al padre |
| R05 | Docente llega antes del horario | Media | Medio | Rechaza QR "Fuera de Horario" |
| R06 | QR del alumno no es JSON válido | Baja | Medio | Modal "QR Inválido" |
| R07 | Correcciones descargan datos masivos | Baja | Medio | Lentitud en aulas con muchos registros |

### 16.2 Riesgos técnicos (backend)

| ID | Riesgo | Probabilidad | Impacto |
|----|--------|-------------|---------|
| T01 | Cloud Function AI falla → fallback con colección errónea | Media | Alto |
| T02 | attendance-sync.ts falla → Home con datos obsoletos | Baja | Medio |
| T03 | Telegram bot token expira o cambia | Baja | **Alto** |
| T04 | Firestore índice faltante para nueva query | Baja | Alto |
| T05 | maxInstances: 10 insuficiente en hora punta | Baja | Medio |

### 16.3 Riesgos de datos

| ID | Riesgo | Descripción |
|----|--------|-------------|
| D01 | Tres versiones de modelos coexisten | `attendance_model.dart`, `_new`, `_models` — ambigüedad |
| D02 | Tres versiones de admin_service | `.dart`, `_new.dart`, `_final.dart` — cuál es la activa |
| D03 | Migración de role names | `'docente'` vs `'teacher'` en documentos históricos |
| D04 | Colección `attendance` vs `classrooms/{id}/attendance` | Fallback de reportes usa colección incorrecta |

---

## 17. PROBLEMAS UX DETECTADOS

### 17.1 Problemas funcionales

| ID | Problema | Pantalla | Severidad |
|----|---------|---------|-----------|
| UX01 | **Botón en inglés** "Finish Session" en app en español | `ClassroomDetailScreen` | Media |
| UX02 | **Funcionalidad prometida no implementada**: "Próximamente: ingreso manual de código" | Escáner | Media |
| UX03 | **Sesión obligatoria sin indicador claro**: el docente no sabe si la sesión está activa antes de escanear | Escáner | **Alta** |
| UX04 | **Dos pantallas de escaneo paralelas**: `QuickQRAttendanceScreen` y escáner en `ClassroomDetailScreen` — funcionalidades solapadas | Navegación | Media |
| UX05 | **Admin sin reportes**: el administrador escolar carece de la pantalla más importante para su rol | Dashboard admin | **Alta** |
| UX06 | **2 segundos de espera artificial** antes de cargar análisis IA | `TeacherReportsScreen` | Baja |

### 17.2 Inconsistencias visuales

| ID | Problema | Ubicación |
|----|---------|-----------|
| V01 | Texto "Finish Session" en inglés | `ClassroomDetailScreen:413` |
| V02 | Mezcla de fuentes: Manrope, Work Sans, Material defaults | Múltiples pantallas |
| V03 | "Correccion de asistencias" sin tilde en el título | `AttendanceCorrectionsScreen` AppBar |

### 17.3 Problemas de performance

| ID | Problema | Ubicación | Consecuencia |
|----|---------|-----------|-------------|
| P01 | Correcciones descarga TODA la colección y filtra en memoria | `AttendanceCorrectionsScreen` | Lento con > 500 registros |
| P02 | Fallback de reportes filtra timestamps en memoria | `TeacherReportsScreen` | Lento con aulas grandes |

---

## 18. FUNCIONALIDADES MÁS IMPORTANTES

### Para operación diaria (valor real)

1. **Registro de asistencia por QR con sesión activa**
   - Es el núcleo del sistema
   - Reemplaza completamente el proceso manual de pasar lista
   - Automático, preciso, con timestamps de servidor

2. **Notificación automática al padre via Telegram**
   - Comunicación en tiempo real sin intervención del docente
   - Cadena completa: escaneo → Firestore → trigger → Telegram

3. **Corrección histórica de registros**
   - Permite ajustar errores del día anterior o de días pasados
   - Trazabilidad completa (`editedFrom`, `updatedAt`)

4. **Exportación PDF formato SIAGIE/UGEL 06**
   - Cumplimiento normativo automático
   - Genera el documento que el docente entrega mensualmente a dirección

5. **Vinculación Telegram via WhatsApp**
   - Enlace el apoderado al bot con un solo tap
   - Flujo sin fricción técnica para el padre

### Para gestión institucional (valor estratégico)

6. **Análisis de ausentismo crónico (≥20% faltas)**
   - Identifica alumnos en riesgo antes de que sea un problema grave
   - Base para intervención temprana

7. **Validación automática de tardanzas**
   - Sistema determina objetivamente si un alumno llega a tiempo o tarde
   - Elimina subjetividad y conflictos docente-padre

8. **Vista de tendencia semanal de asistencia**
   - 4 semanas del mes en gráfica visual
   - Identifica patrones (lunes/viernes con más ausentismo, etc.)

---

## 19. FUNCIONALIDADES MÁS IMPACTANTES PARA DEMO

### Ranking de impacto visual × valor real

| Rank | Funcionalidad | Duración demo | Por qué impacta |
|------|--------------|---------------|-----------------|
| #1 | **Escaneo QR inmersivo** — alumno scaneado, card con datos aparece instantáneamente | 15 seg | Visual espectacular, solución obvia al problema |
| #2 | **Notificación Telegram al padre** — teléfono del padre muestra mensaje automático | 8 seg | "Wow" tecnológico, beneficio tangible para los padres |
| #3 | **Creación alumno → WhatsApp → Telegram** — flujo completo en 3 pantallas | 10 seg | Muestra integración end-to-end |
| #4 | **Exportar PDF UGEL 06** — botón, 3 segundos, PDF oficial listo | 8 seg | Valor institucional inmediato, soluciona problema real |
| #5 | **Análisis IA** — botón, carga, lista de patrones + recomendaciones | 8 seg | Tecnología de vanguardia aplicada a educación |
| #6 | **Gráfica de tendencia animada** — barras por semana con porcentajes | 5 seg | Visualización profesional de datos |
| #7 | **Dashboard con reloj en vivo** — contexto temporal siempre visible | 3 seg | UX profesional, da credibilidad al producto |

### Guión de demo recomendado (tiempo total: ~60 segundos)

```
[0:00-0:05]  Login → Dashboard carga instantáneo
[0:05-0:12]  Tab Mis Aulas → seleccionar aula → "Iniciar sesión"
[0:12-0:27]  ESCANEO: 3 alumnos → PRESENTE / TARDE / YA REGISTRADO
[0:27-0:35]  Teléfono padre → notificación Telegram aparece
[0:35-0:43]  Tab Reportes → KPIs → botón PDF → PDF UGEL 06 se genera
[0:43-0:51]  "Análisis con IA" → patrones + recomendaciones
[0:51-0:58]  Tab Alumnos → crear alumno → botón WhatsApp
[0:58-1:00]  Logo + cierre
```

### Momentos "wow" del demo

1. **El scan instant**: el card del alumno aparece con su foto/iniciales, nombre, DNI y "PRESENTE ✅" en menos de 2 segundos
2. **La notificación Telegram**: muestra dos pantallas simultáneas — la app del docente y el teléfono del padre recibiendo el mensaje
3. **El PDF UGEL 06**: el documento que antes tardaba horas en llenar aparece completo en segundos
4. **La vinculación en 1 tap**: el padre no escribe nada — toca el enlace y queda vinculado automáticamente

---

## 20. POSIBLES MEJORAS FUTURAS

### 20.1 Correcciones urgentes (bugs activos)

| ID | Corrección | Archivo | Línea |
|----|-----------|---------|-------|
| FIX01 | Cambiar "Finish Session" → "Finalizar sesión" | `classroom_detail_screen.dart` | 413 |
| FIX02 | Eliminar o implementar "ingreso manual de código" | `classroom_detail_screen.dart` | 389 |
| FIX03 | Corregir fallback de reportes a colección correcta `classrooms/{id}/attendance` | `teacher_reports_screen.dart` | 409 |
| FIX04 | Agregar filtro de fecha en servidor para correcciones | `attendance_corrections_screen.dart` | 45-48 |
| FIX05 | Corregir "Correccion" → "Corrección" (tilde) | `attendance_corrections_screen.dart` | AppBar |

### 20.2 Mejoras de UX prioritarias

| ID | Mejora | Impacto |
|----|--------|---------|
| UX-A | **Indicador visual claro de sesión activa** — badge o banner permanente en el escáner indicando si hay sesión o no | Alto |
| UX-B | **Auto-inicio de sesión** — iniciar sesión automáticamente al entrar al escáner dentro del horario | Alto |
| UX-C | **Panel de reportes para administrador** — el admin debe poder ver reportes globales de ausentismo institucional | Alto |
| UX-D | **Modo offline parcial** — cache local de QRs para escanear sin conexión, sincronizar al reconectar | Medio |
| UX-E | **Ingreso manual de ID** — alternativa para alumnos sin código QR disponible | Medio |
| UX-F | **Notificación push app** — además de Telegram, notificación nativa del teléfono | Medio |
| UX-G | **Vista de sesiones activas en tiempo real** — admin ve qué aulas están pasando lista ahora mismo | Medio |

### 20.3 Mejoras técnicas

| ID | Mejora | Impacto |
|----|--------|---------|
| TECH-A | **Consolidar modelos de datos** — unificar `attendance_model.dart`, `_new`, `_models` en uno solo | Alto |
| TECH-B | **Consolidar admin_service** — unificar las 3 versiones en `admin_service.dart` final | Medio |
| TECH-C | **Migrar roles** — estandarizar `'teacher'` → `'docente'` en toda la base de datos | Medio |
| TECH-D | **Query paginada en correcciones** — query con filtro de fecha en servidor + cursor pagination | Medio |
| TECH-E | **Eliminar espera artificial de 2s en IA** — reemplazar con polling de estado real | Bajo |
| TECH-F | **Monitoreo de Cloud Functions** — alertas si `attendance-sync.ts` o triggers Telegram fallan | Medio |

### 20.4 Nuevas funcionalidades

| ID | Funcionalidad | Valor |
|----|--------------|-------|
| NEW-A | **Portal para padres** — app/web donde el padre puede ver el historial de asistencia de su hijo | Alto |
| NEW-B | **Reporte global de administrador** — ausentismo por aula, por grado, por semana — visión institucional | Alto |
| NEW-C | **Alertas automáticas por umbral** — notificación al docente cuando un alumno acumula X faltas | Alto |
| NEW-D | **Carnet QR imprimible** — generación de carnet estudiantil con QR listo para imprimir | Medio |
| NEW-E | **Integración SIAGIE oficial** — exportación directa al sistema del Ministerio de Educación | Alto |
| NEW-F | **Historial de sesiones** — docente ve todas las sesiones pasadas con estadísticas por sesión | Medio |
| NEW-G | **Multi-aula por docente con acceso rápido** — dashboard que muestra las aulas del día con su estado | Medio |
| NEW-H | **Rol alumno habilitado** — portal del alumno para ver su propia asistencia | Bajo (beta) |

### 20.5 Escala institucional

| ID | Mejora | Para qué escala |
|----|--------|----------------|
| SCALE-A | Soporte multi-institución (tenancy) | Red de colegios |
| SCALE-B | Configuración de período académico centralizada | Inicio de año escolar |
| SCALE-C | API pública para integración con SIAGIE/MINEDU | Integración ministerial |
| SCALE-D | Dashboard directivo con comparativa entre aulas | Dirección institucional |

---

## APÉNDICE A — Glosario de Términos

| Término | Definición |
|---------|-----------|
| **Sesión de asistencia** | Registro activo en `attendance_sessions` que habilita el escaneo QR. Debe iniciarse manualmente. |
| **dateKey** | Formato de fecha `YYYY-MM-DD` usado como clave de documento y para deduplicación diaria |
| **maxLateTime** | Hora límite configurada por el admin; alumnos que llegan después son marcados como `late` |
| **E.164** | Formato internacional de teléfono (+51XXXXXXXXX para Perú) |
| **ClassSchedule** | Objeto con `startTime`, `endTime`, `maxLateTime` por día de semana |
| **QrScanResultType** | Enum: `entryRegistered`, `exitRegistered`, `exitAlreadyRegistered` |
| **AttendanceStatus** | Enum: `present`, `absent`, `late`, `justified` |
| **activation_code** | Código de 6 dígitos que vincula al padre con el bot de Telegram |
| **attendance raíz** | Colección `attendance/` espejo de `classrooms/{id}/attendance/` para queries globales |
| **UGEL 06** | Unidad de Gestión Educativa Local 06, Lima — organismo regulador educativo |
| **SIAGIE** | Sistema de Información de Apoyo a la Gestión de la Institución Educativa — plataforma oficial MINEDU |

---

## APÉNDICE B — Archivos Clave del Proyecto

### Frontend (rutas relativas a `asistencias_app/lib/`)

| Archivo | Responsabilidad |
|---------|-----------------|
| `main.dart` | Entry point, inicialización Firebase, AuthWrapper |
| `providers/auth_provider.dart` | Estado global de autenticación |
| `providers/attendance_provider.dart` | Estado de asistencias + AttendanceRepository |
| `services/attendance_service.dart` | Lógica de negocio de asistencia |
| `services/attendance_repository.dart` | Repositorio QR (entrada/salida atómica) |
| `services/firestore_service.dart` | CRUD centralizado Firestore |
| `services/student_service.dart` | CRUD estudiantes + generación link Telegram |
| `screens/dashboard/modern_dashboard_screen.dart` | Navegación principal por rol |
| `screens/dashboard/improved_home_screen.dart` | Home con stats en vivo |
| `screens/teacher/classrooms/classroom_detail_screen.dart` | Escáner QR + calendario + lista |
| `screens/teacher/attendance/quick_qr_attendance_screen.dart` | Escáner QR alternativo |
| `screens/teacher/attendance/attendance_corrections_screen.dart` | Corrección histórica |
| `screens/teacher/students/teacher_create_student_screen.dart` | Registro alumno + Telegram |
| `screens/teacher/reports/teacher_reports_screen.dart` | Reportes IA + PDF + Excel |
| `theme/app_design_system.dart` | Sistema de diseño responsivo |

### Backend (rutas relativas a `functions/src/`)

| Archivo | Responsabilidad |
|---------|-----------------|
| `index.ts` | Express app, middlewares, rutas REST, configuración global |
| `telegram.ts` | Bot, vinculación, notificaciones automáticas, triggers |
| `attendance-sync.ts` | Sincronización subcollección → colección raíz |
| `modules/salones/` | CRUD aulas vía REST |
| `modules/asistencias/` | CRUD asistencias vía REST |
| `modules/admin/` | Gestión usuarios admin |

### Configuración del proyecto

| Archivo | Contenido |
|---------|-----------|
| `firebase.json` | Configuración hosting + functions |
| `firestore.rules` | Reglas de seguridad Firestore |
| `firestore.indexes.json` | Índices compuestos para queries |
| `.firebaserc` | Proyectos Firebase vinculados |
| `functions/package.json` | Dependencias Node.js |
| `asistencias_app/pubspec.yaml` | Dependencias Flutter/Dart |

---

*Documentación generada el 2026-05-23 — Sistema de Asistencia QR v1.0 beta*  
*Para uso interno: base para manuales, demo y desarrollo*

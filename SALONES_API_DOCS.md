# 📚 API de Gestión de Salones - Documentación

## 🏫 Colección Salones - Firestore

### Estructura del documento:
```json
{
  "id": "auto-generated",
  "nombre": "Salón 3°A - Matemáticas",
  "grado": "3°",
  "seccion": "A", 
  "idDocenteCreador": "uid_del_docente",
  "nombreDocenteCreador": "Juan Pérez",
  "isActive": true,
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "deletedAt": "timestamp", // solo si fue eliminado lógicamente
  "deletedBy": "uid" // solo si fue eliminado lógicamente
}
```

## 🔗 Endpoints para Postman

### Base URL:
```
http://127.0.0.1:5001/asistencia-alumnos-2025/us-central1/api
```

---

## 1. 🆕 Crear Salón
**POST** `/salones`

**Headers:**
```
Authorization: Bearer <token_docente_o_admin>
Content-Type: application/json
```

**Body:**
```json
{
  "nombre": "Salón 1°A - Ciencias",
  "grado": "1°",
  "seccion": "A"
}
```

**Respuesta exitosa (201):**
```json
{
  "success": true,
  "message": "Salón creado exitosamente",
  "data": {
    "salon": {
      "id": "salon_id_generado",
      "nombre": "Salón 1°A - Ciencias",
      "grado": "1°",
      "seccion": "A",
      "idDocenteCreador": "uid_docente",
      "nombreDocenteCreador": "Juan Pérez",
      "isActive": true,
      "createdAt": "2025-08-23T...",
      "updatedAt": "2025-08-23T..."
    }
  }
}
```

---

## 2. 📋 Listar Salones
**GET** `/salones`

**Headers:**
```
Authorization: Bearer <token_docente_o_admin>
```

**Query Parameters:**
- `grado` (opcional): Filtrar por grado específico
- `activos` (opcional): "true" o "false" (default: "true")

**Ejemplos:**
- `/salones` - Todos los salones activos
- `/salones?grado=3°` - Solo salones de 3°
- `/salones?activos=false` - Solo salones inactivos

**Respuesta:**
```json
{
  "success": true,
  "message": "5 salones encontrados",
  "data": {
    "salones": [
      {
        "id": "salon1",
        "nombre": "Salón 1°A - Matemáticas",
        "grado": "1°",
        "seccion": "A",
        "idDocenteCreador": "uid1",
        "nombreDocenteCreador": "Juan Pérez",
        "isActive": true,
        "createdAt": "timestamp",
        "updatedAt": "timestamp"
      }
    ],
    "total": 5,
    "filtros": {
      "grado": "todos",
      "activos": true
    }
  }
}
```

---

## 3. 🔍 Obtener Salón por ID
**GET** `/salones/:id`

**Headers:**
```
Authorization: Bearer <token_docente_o_admin>
```

**Ejemplo:** `/salones/abc123def456`

---

## 4. ✏️ Actualizar Salón
**PUT** `/salones/:id`

**Headers:**
```
Authorization: Bearer <token_docente_creador_o_admin>
Content-Type: application/json
```

**Body (campos opcionales):**
```json
{
  "nombre": "Nuevo nombre del salón",
  "grado": "2°",
  "seccion": "B",
  "isActive": false
}
```

**Nota:** Solo el docente creador o admin pueden actualizar.

---

## 5. 🗑️ Eliminar Salón
**DELETE** `/salones/:id`

**Headers:**
```
Authorization: Bearer <token_docente_creador_o_admin>
```

**Query Parameters:**
- `eliminarPermanente=true` (solo admin) - Eliminación física
- Sin parámetros - Eliminación lógica (default)

**Ejemplos:**
- `/salones/abc123?eliminarPermanente=true` (solo admin)
- `/salones/abc123` (eliminación lógica)

---

## 6. 📊 Endpoints Especiales

### 6.1. Salones por Grado
**GET** `/salones/grado/:grado`

**Ejemplo:** `/salones/grado/3°`

### 6.2. Estadísticas (Solo Admin)
**GET** `/salones/stats`

**Respuesta:**
```json
{
  "success": true,
  "message": "Estadísticas de salones obtenidas",
  "data": {
    "stats": {
      "total": 15,
      "activos": 12,
      "inactivos": 3,
      "porGrado": {
        "1°": { "total": 5, "activos": 4 },
        "2°": { "total": 5, "activos": 4 },
        "3°": { "total": 5, "activos": 4 }
      },
      "porDocente": {
        "Juan Pérez": { "total": 8, "activos": 7 },
        "María García": { "total": 7, "activos": 5 }
      }
    }
  }
}
```

---

## 🛡️ Reglas de Seguridad

### Permisos:
- **Crear:** Docentes y admin
- **Leer:** Admin ve todos, docentes solo los suyos
- **Actualizar:** Solo el docente creador o admin
- **Eliminar:** Solo el docente creador o admin
  - Eliminación lógica: Docentes y admin
  - Eliminación permanente: Solo admin

### Validaciones:
1. No puede haber dos salones activos con el mismo grado y sección
2. Los campos nombre, grado y sección son obligatorios
3. Solo el docente creador puede modificar/eliminar su salón
4. Admin tiene permisos completos sobre todos los salones

---

## 🔍 Índices de Firestore Optimizados

Los siguientes índices están configurados para optimizar las consultas:

1. `isActive + grado + seccion` - Para búsquedas por grado/sección
2. `idDocenteCreador + isActive + grado` - Para salones del docente
3. `grado + isActive + seccion` - Para listados ordenados por grado

---

## 🧪 Flujo de Prueba Recomendado

1. **Crear admin** con `/auth/setup`
2. **Registrar docente** con token de admin
3. **Login como docente** y obtener token
4. **Crear salón** con token de docente
5. **Listar salones** del docente
6. **Actualizar salón**
7. **Probar como admin** - ver todos los salones
8. **Eliminar salón** (lógica vs permanente)

---

## ⚠️ Notas Importantes

- **Eliminación lógica vs física:** Por defecto se hace eliminación lógica (isActive=false). Solo admin puede hacer eliminación permanente.
- **Unicidad:** Un grado y sección solo puede tener un salón activo.
- **Permisos:** Los docentes solo ven/modifican sus propios salones.
- **Firestore Rules:** Las reglas de seguridad están configuradas para reforzar estos permisos.

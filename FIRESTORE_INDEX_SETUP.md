# Configuración de Índices de Firestore

## Índice Compuesto Requerido

Este proyecto requiere un índice compuesto en Firestore para la colección `attendance` (asistencias).

### ⚠️ Error Corregido

El error que aparecía era:
```
Error al generar análisis con IA: [firebase_functions/internal] Error al generar reporte: 9 FAILED_PRECONDITION: The query requires an index.
```

### ✅ Solución Implementada

**IMPORTANTE**: Ya NO es necesario crear el índice compuesto, ya que el código fue modificado para:

1. **Consultar solo por `classroomId`** en Firestore
2. **Filtrar por fecha en memoria** después de obtener los datos

Esto elimina la necesidad del índice compuesto y mejora el rendimiento en algunos casos.

### 📝 Cambios Realizados en el Código

**Archivo**: `lib/screens/teacher/reports/teacher_reports_screen.dart`

**Antes** (requería índice):
```dart
final attendanceSnapshot = await _firestore
    .collection('attendances')
    .where('classroomId', isEqualTo: selectedClassroomId)
    .where('timestamp', isGreaterThanOrEqualTo: startDate)  // ❌ Segunda consulta where
    .where('timestamp', isLessThanOrEqualTo: endDate)        // ❌ Tercera consulta where
    .get();
```

**Después** (sin índice):
```dart
// Obtener todas las asistencias del aula
final attendanceSnapshot = await _firestore
    .collection('attendances')
    .where('classroomId', isEqualTo: selectedClassroomId)    // ✅ Solo una consulta where
    .get();

// Filtrar por fecha en memoria
final records = attendanceSnapshot.docs
    .map((doc) => { /* procesar datos */ })
    .where((record) {
      final timestamp = record['timestamp'] as DateTime;
      return timestamp.isAfter(startDate.subtract(const Duration(days: 1))) &&
             timestamp.isBefore(endDate.add(const Duration(days: 1)));
    })
    .toList();
```

### 🔧 Si Necesitas el Índice Compuesto (Alternativa)

Si prefieres usar la consulta con índice compuesto (puede ser más eficiente con muchos datos), puedes crear el índice manualmente:

#### Opción 1: Desde Firebase Console (Recomendado)

1. Ve a [Firebase Console](https://console.firebase.google.com)
2. Selecciona tu proyecto: `asistencia-alumnos-2025`
3. Ve a **Firestore Database** → **Índices**
4. Haz clic en **Crear índice**
5. Configura:
   - **Colección**: `attendance`
   - **Campos a indexar**:
     - `classroomId` → Ascendente
     - `timestamp` → Ascendente
   - **Estado de consulta**: Habilitado

#### Opción 2: Usando firestore.indexes.json

Agrega esto a tu archivo `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "attendance",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "classroomId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "timestamp",
          "order": "ASCENDING"
        }
      ]
    }
  ]
}
```

Luego despliega:
```bash
firebase deploy --only firestore:indexes
```

## Otros Cambios Implementados

### 1. Corrección del Error de PDF SIAGIE

**Error anterior**:
```
Error al generar PDF: NoSuchMethodError: The getter 'length' was called on null.
```

**Solución**: Agregada validación de datos antes de acceder a propiedades:

```dart
// Validar que tengamos datos
final attendances = data['attendances'] as List?;
if (attendances == null || attendances.isEmpty) {
  setState(() => isLoading = false);
  _showError('No hay registros de asistencia en el período seleccionado');
  return;
}
```

### 2. Uso de Plantilla de Excel

El código ahora utiliza la plantilla `assets/templates/23. Lista de Asistencia en EXCEL.xlsx` como base para generar reportes:

```dart
// Cargar la plantilla de Excel desde assets
final ByteData templateData = await rootBundle.load(
  'assets/templates/23. Lista de Asistencia en EXCEL.xlsx',
);
final bytes = templateData.buffer.asUint8List();
final excel = excel_pkg.Excel.decodeBytes(bytes);
```

## 🎯 Beneficios de los Cambios

1. ✅ **No requiere índices compuestos** - Menos configuración en Firestore
2. ✅ **Código más robusto** - Validaciones de null evitan crashes
3. ✅ **Usa plantilla profesional** - Reportes con formato institucional
4. ✅ **Más flexible** - Fácil de modificar sin cambiar índices

## 📊 Rendimiento

- **Para aulas pequeñas** (< 100 estudiantes): El filtrado en memoria es más rápido
- **Para aulas grandes** (> 100 estudiantes): Considera usar el índice compuesto

## 🔍 Verificación

Para verificar que todo funciona:

1. Abre la app
2. Ve a **Reportes de Asistencia**
3. Selecciona un aula y rango de fechas
4. Intenta generar:
   - ✅ Análisis con IA
   - ✅ Reporte Excel
   - ✅ Reporte PDF SIAGIE

Si alguno falla, revisa los logs en la consola de Flutter.

---

**Fecha de actualización**: Noviembre 2025  
**Versión**: 1.0.1

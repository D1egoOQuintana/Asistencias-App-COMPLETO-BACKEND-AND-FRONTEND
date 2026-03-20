# 🤖 Configuración de IA con Vertex AI (Gemini) para Reportes

## 📋 Requisitos

Tu proyecto Firebase necesita tener **Vertex AI activado**. Esto es GRATIS hasta ciertos límites.

## 🚀 Pasos para Activar Vertex AI

### 1️⃣ Ir a Google Cloud Console

```
https://console.cloud.google.com/
```

### 2️⃣ Seleccionar tu Proyecto Firebase

Busca el nombre de tu proyecto en el selector superior.

### 3️⃣ Habilitar Vertex AI API

1. Ve a: **APIs & Services** → **Enable APIs and Services**
2. Busca: `Vertex AI API`
3. Click en **Enable**

### 4️⃣ Configurar Facturación (Requerido pero GRATIS)

1. Ve a: **Billing** → **Link a billing account**
2. Crea una cuenta de facturación (necesita tarjeta pero NO te cobran nada en plan gratuito)
3. **Límites gratuitos de Gemini:**
   - **Gemini 1.5 Flash**: 15 requests/min GRATIS
   - **Gemini 1.5 Pro**: 2 requests/min GRATIS

### 5️⃣ Desplegar las Functions

```powershell
cd functions
firebase deploy --only functions:generateReportWithAI,functions:getAIReportsHistory
```

## ✅ Verificar que Funciona

1. Abre la app en un dispositivo/emulador
2. Ve a **Reportes** desde el dashboard
3. Selecciona un aula y período
4. Click en **"Generar Análisis con IA"**
5. Espera 5-10 segundos
6. ¡Deberías ver el análisis generado por Gemini! 🎉

## 📊 Qué Hace la IA

La función `generateReportWithAI` envía a Gemini:
- Estadísticas de asistencia
- Registros de presente/tarde/ausente
- Fechas del período

**Gemini responde con:**
- ✨ **Resumen**: Párrafo corto de la situación
- 🔍 **Patrones**: Lista de comportamientos detectados
- 💡 **Recomendaciones**: Sugerencias concretas para mejorar

## 🔧 Personalizar el Prompt

Edita el archivo: `functions/ai-reports.js`

Línea ~60: Modifica el `prompt` para cambiar lo que la IA analiza:

```javascript
const prompt = `
Eres un asistente educativo experto...
// Tu prompt personalizado aquí
`;
```

## 💰 Costos

**Plan Gratuito:**
- Hasta **1,500 requests/día** gratis con Gemini Flash
- Más que suficiente para una escuela pequeña/mediana

**Si excedes:**
- Gemini Flash: $0.075 por 1,000 requests
- MUY económico comparado con ChatGPT

## 🛡️ Seguridad

- ✅ Solo usuarios autenticados pueden usar la función
- ✅ Cada análisis se guarda en Firestore (`ai_reports` collection)
- ✅ Puedes ver historial con `getAIReportsHistory`

## 📱 UI de la App

La pantalla `TeacherReportsScreen` incluye:

1. **Selector de Aula**: Dropdown con tus aulas
2. **Selector de Fechas**: Rango personalizado
3. **Botón IA**: Genera análisis inteligente
4. **Tarjeta de Resultados**: Muestra resumen, patrones y recomendaciones
5. **Exportar Excel**: Genera .xlsx con formato UGEL
6. **Exportar PDF**: Genera PDF con formato SIAGIE

## 🎨 Personalizar Análisis

En `ai-reports.js` puedes agregar más análisis:

```javascript
// Ejemplo: Detectar estudiantes en riesgo
const atRiskStudents = students.filter(s => {
  const absences = records.filter(r => 
    r.studentId === s.id && r.status === 'absent'
  ).length;
  return absences > 3;
});

// Incluir en el prompt
Estudiantes en riesgo (>3 ausencias): ${atRiskStudents.length}
```

## 🐛 Troubleshooting

### Error: "Vertex AI API not enabled"
- Ve a Google Cloud Console → APIs → Habilita Vertex AI API

### Error: "Quota exceeded"
- Espera 1 minuto (límite de 15 requests/min)
- O actualiza a plan de pago (muy barato)

### Error: "Billing account required"
- Necesitas vincular una tarjeta (no te cobran en plan gratuito)

## 📚 Recursos

- [Vertex AI Docs](https://cloud.google.com/vertex-ai/docs)
- [Gemini Pricing](https://cloud.google.com/vertex-ai/pricing)
- [Firebase Functions Docs](https://firebase.google.com/docs/functions)

---

## 🎯 Próximos Pasos

1. ✅ Activar Vertex AI en Google Cloud
2. ✅ Desplegar las functions
3. ✅ Probar desde la app
4. 📝 Personalizar análisis según tus necesidades
5. 📊 Agregar más tipos de reportes (por estudiante, por mes, etc.)

¡Listo! Ahora tienes **IA integrada en tu sistema de asistencias** 🚀

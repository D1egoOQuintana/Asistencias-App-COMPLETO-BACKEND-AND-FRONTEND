/**
 * Funciones de Reportes con IA usando Vertex AI (Gemini)
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { VertexAI } = require('@google-cloud/vertexai');
const admin = require('firebase-admin');

// Inicializar Firebase Admin si no está inicializado
if (!admin.apps.length) {
  admin.initializeApp();
}

// Inicializar Vertex AI
const PROJECT_ID = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT;
const LOCATION = 'us-central1';

// Nota: Asegúrate de que Vertex AI API está habilitada en tu proyecto
// https://console.cloud.google.com/apis/library/aiplatform.googleapis.com

/**
 * Genera análisis inteligente de asistencia usando Gemini
 */
exports.generateReportWithAI = onCall(async (request) => {
  try {
    // Verificar autenticación
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Usuario no autenticado');
    }

    const { classroomId, startDate, endDate, attendanceData } = request.data;

    // Validaciones
    if (!classroomId || !attendanceData) {
      throw new HttpsError('invalid-argument', 'Faltan datos requeridos');
    }

    // Verificar que Vertex AI está disponible
    if (!PROJECT_ID) {
      console.error('PROJECT_ID no está configurado');
      throw new HttpsError('failed-precondition', 'Vertex AI no está configurado correctamente');
    }

    // Inicializar Vertex AI
    const vertexAI = new VertexAI({
      project: PROJECT_ID,
      location: LOCATION
    });

    // Modelo Gemini - usar gemini-pro que está más disponible
    const generativeModel = vertexAI.getGenerativeModel({
      model: 'gemini-pro',
      generationConfig: {
        maxOutputTokens: 2048,
        temperature: 0.7,
        topP: 0.8,
        topK: 40
      }
    });

    // Preparar datos para el prompt
    const attendances = attendanceData.attendances || [];
    const students = attendanceData.students || [];
    const metadata = attendanceData.metadata || {};
    const statistics = attendanceData.statistics || {};
    
    const totalStudents = students.length;
    const totalRecords = metadata.totalRecords || attendances.length;

    // Calcular estadísticas de asistencias
    const presentCount = attendances.filter(r => r.status === 'present').length;
    const lateCount = attendances.filter(r => r.status === 'late').length;
    const absentCount = attendances.filter(r => r.status === 'absent').length;

    // Crear prompt para la IA
    const prompt = `
Eres un asistente educativo experto en análisis de asistencia escolar en Perú (UGEL 06, SIAGIE).

Analiza los siguientes datos de asistencia:

📊 ESTADÍSTICAS GENERALES:
- Total de estudiantes: ${totalStudents}
- Total de registros: ${totalRecords}
- Período: ${new Date(startDate).toLocaleDateString('es-PE')} a ${new Date(endDate).toLocaleDateString('es-PE')}
- Asistencias: ${presentCount}
- Tardanzas: ${lateCount}
- Ausencias: ${absentCount}

📋 DATOS DETALLADOS:
${JSON.stringify(attendances.slice(0, 50), null, 2)}

POR FAVOR, GENERA UN ANÁLISIS COMPLETO CON:

1. RESUMEN: Un párrafo corto (máximo 3 líneas) resumiendo la situación general de asistencia.

2. PATRONES DETECTADOS: Lista de 3-5 patrones importantes que observas en los datos (días con más ausencias, estudiantes con problemas recurrentes, etc.)

3. RECOMENDACIONES: Lista de 3-5 recomendaciones concretas y accionables para mejorar la asistencia.

Responde SOLO en formato JSON válido con esta estructura:
{
  "summary": "tu resumen aquí",
  "patterns": ["patrón 1", "patrón 2", "patrón 3"],
  "recommendations": ["recomendación 1", "recomendación 2", "recomendación 3"]
}
`;

    // Llamar a Gemini
    console.log('Llamando a Gemini para análisis...');
    const result = await generativeModel.generateContent(prompt);
    const response = result.response;
    const text = response.candidates[0].content.parts[0].text;

    console.log('Respuesta de Gemini recibida:', text);

    // Parsear respuesta JSON
    let aiAnalysis;
    try {
      // Extraer JSON del texto (por si viene con markdown)
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        aiAnalysis = JSON.parse(jsonMatch[0]);
      } else {
        throw new Error('No se encontró JSON válido en la respuesta');
      }
    } catch (parseError) {
      console.error('Error parseando respuesta de IA:', parseError);
      // Fallback si no se puede parsear
      aiAnalysis = {
        summary: text,
        patterns: ['Análisis generado por IA (formato alternativo)'],
        recommendations: ['Revisar los datos manualmente para más detalles']
      };
    }

    // Registrar análisis en Firestore (opcional, para histórico)
    await admin.firestore().collection('ai_reports').add({
      userId: request.auth.uid,
      classroomId,
      startDate: new Date(startDate),
      endDate: new Date(endDate),
      analysis: aiAnalysis,
      stats: {
        totalStudents,
        totalRecords,
        presentCount,
        lateCount,
        absentCount
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return aiAnalysis;

  } catch (error) {
    console.error('Error en generateReportWithAI:', error);
    
    // Si es error de Vertex AI (404, permisos, etc), generar análisis básico
    if (error.message && (error.message.includes('404') || 
                          error.message.includes('NOT_FOUND') || 
                          error.message.includes('VertexAI') ||
                          error.message.includes('quota'))) {
      
      console.log('Vertex AI no disponible, generando análisis básico...');
      
      // Generar análisis básico sin IA
      const { classroomId, attendanceData } = request.data;
      const attendances = attendanceData.attendances || [];
      const students = attendanceData.students || [];
      const metadata = attendanceData.metadata || {};
      
      const totalStudents = students.length;
      const totalRecords = metadata.totalRecords || attendances.length;
      
      const presentCount = attendances.filter(r => r.status === 'present').length;
      const lateCount = attendances.filter(r => r.status === 'late').length;
      const absentCount = attendances.filter(r => r.status === 'absent').length;
      
      const attendanceRate = totalRecords > 0 
        ? ((presentCount + lateCount) / totalRecords * 100).toFixed(1)
        : 0;
      
      const basicAnalysis = {
        summary: `Análisis de asistencia del período seleccionado: Se registraron ${totalRecords} asistencias de ${totalStudents} estudiantes. La tasa de asistencia es del ${attendanceRate}% (${presentCount} presentes, ${lateCount} tardanzas, ${absentCount} ausencias).`,
        patterns: [
          `Total de registros: ${totalRecords} asistencias`,
          `Asistencias: ${presentCount} (${presentCount > 0 ? (presentCount/totalRecords*100).toFixed(1) : 0}%)`,
          `Tardanzas: ${lateCount} (${lateCount > 0 ? (lateCount/totalRecords*100).toFixed(1) : 0}%)`,
          `Ausencias: ${absentCount} (${absentCount > 0 ? (absentCount/totalRecords*100).toFixed(1) : 0}%)`,
        ],
        recommendations: [
          attendanceRate < 80 ? 'La tasa de asistencia es baja. Considere contactar a los padres de familia.' : 'Mantener la buena tasa de asistencia con reconocimientos.',
          lateCount > totalRecords * 0.2 ? 'Alto índice de tardanzas. Revisar horarios y comunicar importancia de la puntualidad.' : 'Buen nivel de puntualidad.',
          absentCount > totalRecords * 0.15 ? 'Varias ausencias detectadas. Hacer seguimiento individual de estudiantes con ausencias frecuentes.' : 'Nivel de ausencias aceptable.',
        ],
        note: 'Análisis básico generado (Vertex AI no disponible). Para análisis avanzado con IA, habilite Vertex AI en su proyecto de Firebase.'
      };
      
      // Guardar análisis básico
      await admin.firestore().collection('ai_reports').add({
        userId: request.auth.uid,
        classroomId,
        analysis: basicAnalysis,
        type: 'basic',
        stats: {
          totalStudents,
          totalRecords,
          presentCount,
          lateCount,
          absentCount
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      return basicAnalysis;
    }
    
    // Otros errores
    throw new HttpsError('internal', `Error generando reporte: ${error.message}`);
  }
});

/**
 * Obtiene el historial de análisis con IA
 */
exports.getAIReportsHistory = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Usuario no autenticado');
    }

    const { limit = 10 } = request.data;

    const snapshot = await admin.firestore()
      .collection('ai_reports')
      .where('userId', '==', request.auth.uid)
      .orderBy('createdAt', 'desc')
      .limit(limit)
      .get();

    const reports = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate().toISOString()
    }));

    return { reports };

  } catch (error) {
    console.error('Error en getAIReportsHistory:', error);
    throw new HttpsError('internal', `Error obteniendo historial: ${error.message}`);
  }
});

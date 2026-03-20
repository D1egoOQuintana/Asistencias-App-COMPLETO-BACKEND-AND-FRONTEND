/**
 * API Profesional de Reportes
 * Funciones Cloud optimizadas para generación de reportes
 * Con validación, cache, y análisis estadístico avanzado
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const admin = require('firebase-admin');

// Inicializar Firebase Admin si no está inicializado
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Obtener datos completos de asistencias para reportes
 * Incluye estadísticas calculadas y análisis de tendencias
 */
exports.getAttendanceReportData = onCall(
  { 
    cors: true,
    memory: '512MiB',
    timeoutSeconds: 60,
  },
  async (request) => {
    try {
      const { classroomId, startDate, endDate, includeStudentDetails = true } = request.data;

      // Validación de parámetros
      if (!classroomId) {
        throw new HttpsError('invalid-argument', 'El ID del aula es requerido');
      }

      // Verificar autenticación
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Usuario no autenticado');
      }

      const db = getFirestore();
      const userId = request.auth.uid;

      // Verificar que el usuario tenga acceso al aula
      const classroomDoc = await db.collection('classrooms').doc(classroomId).get();
      
      if (!classroomDoc.exists) {
        throw new HttpsError('not-found', 'Aula no encontrada');
      }

      const classroom = classroomDoc.data();
      
      // Verificar permisos (profesor del aula o admin)
      const userDoc = await db.collection('users').doc(userId).get();
      const userRole = userDoc.data()?.role;
      
      if (classroom.teacherUid !== userId && userRole !== 'admin') {
        throw new HttpsError('permission-denied', 'No tienes permiso para acceder a este aula');
      }

      // Construir query de asistencias - solo por classroomId para evitar índice compuesto
      console.log(`🔍 Buscando asistencias para classroomId: ${classroomId}`);
      const attendanceQuery = db.collection('attendance')
        .where('classroomId', '==', classroomId);

      // Obtener asistencias (sin filtros de fecha en la query)
      const attendancesSnapshot = await attendanceQuery.get();
      console.log(`📊 Documentos encontrados en Firestore: ${attendancesSnapshot.size}`);
      
      if (attendancesSnapshot.size > 0) {
        const firstDoc = attendancesSnapshot.docs[0].data();
        console.log(`📄 Ejemplo del primer documento:`, {
          id: attendancesSnapshot.docs[0].id,
          hasDate: !!firstDoc.date,
          hasRecordedAt: !!firstDoc.recordedAt,
          hasTimestamp: !!firstDoc.timestamp,
          status: firstDoc.status,
          classroomId: firstDoc.classroomId,
          studentId: firstDoc.studentId
        });
      }
      
      // Aplicar filtros de fecha en memoria
      let attendances = attendancesSnapshot.docs
        .map(doc => {
          const data = doc.data();
          let timestampDate = null;
          
          // Prioridad: date (string ISO) > timestamp > recordedAt
          // El campo 'date' es más confiable porque es la fecha del día de asistencia
          const timeField = data.date || data.timestamp || data.recordedAt;
          
          if (!timeField) {
            console.warn(`⚠️ Documento ${doc.id} no tiene ningún campo de fecha`);
            return null;
          }
          
          // Convertir a Date según el tipo
          try {
            if (typeof timeField === 'string') {
              // Es un string ISO o fecha (ESTE ES EL CASO MÁS COMÚN)
              timestampDate = new Date(timeField);
            } else if (timeField._seconds !== undefined) {
              // Es un Timestamp de Firestore (con _seconds)
              timestampDate = new Date(timeField._seconds * 1000);
            } else if (typeof timeField.toDate === 'function') {
              // Es un Timestamp con método toDate()
              timestampDate = timeField.toDate();
            } else if (timeField instanceof Date) {
              // Ya es un Date
              timestampDate = timeField;
            } else {
              console.warn(`⚠️ Documento ${doc.id} tiene campo de fecha de tipo desconocido:`, {
                type: typeof timeField,
                value: timeField,
                hasToDate: typeof timeField.toDate === 'function',
                hasSeconds: timeField._seconds !== undefined
              });
              return null;
            }
          } catch (error) {
            console.warn(`⚠️ Error al convertir fecha del documento ${doc.id}:`, error.message);
            return null;
          }
          
          if (!timestampDate || isNaN(timestampDate.getTime())) {
            console.warn(`⚠️ Documento ${doc.id} - fecha inválida después de conversión:`, {
              timestampDate,
              timeFieldType: typeof timeField
            });
            return null;
          }
          
          return {
            id: doc.id,
            ...data,
            timestamp: timestampDate.toISOString(),
            timestampDate: timestampDate,
          };
        })
        .filter(att => att !== null); // Filtrar documentos inválidos
      
      console.log(`📊 Total documentos en Firestore: ${attendancesSnapshot.size}`);
      console.log(`✅ Documentos con fecha válida: ${attendances.length}`);

      // Filtrar por fechas en memoria si se proporcionan
      if (startDate || endDate) {
        const start = startDate ? new Date(startDate) : null;
        const end = endDate ? new Date(endDate) : null;
        
        if (start) start.setHours(0, 0, 0, 0);
        if (end) end.setHours(23, 59, 59, 999);

        console.log(`🔍 Filtrando por fechas:`);
        console.log(`   Inicio: ${start ? start.toISOString() : 'N/A'}`);
        console.log(`   Fin: ${end ? end.toISOString() : 'N/A'}`);
        console.log(`   Registros antes de filtrar: ${attendances.length}`);

        attendances = attendances.filter(att => {
          const attDate = att.timestampDate;
          if (start && attDate < start) {
            console.log(`   ❌ Rechazado (antes de inicio): ${attDate.toISOString()}`);
            return false;
          }
          if (end && attDate > end) {
            console.log(`   ❌ Rechazado (después de fin): ${attDate.toISOString()}`);
            return false;
          }
          console.log(`   ✅ Aceptado: ${attDate.toISOString()}`);
          return true;
        });
        
        console.log(`   Registros después de filtrar: ${attendances.length}`);
      }

      // Ordenar por timestamp descendente
      attendances.sort((a, b) => b.timestampDate - a.timestampDate);
      
      // Remover timestampDate temporal (solo para filtrado)
      attendances = attendances.map(({timestampDate, ...rest}) => rest);

      // Obtener estudiantes del aula si se requiere
      let students = [];
      if (includeStudentDetails) {
        const studentsSnapshot = await db.collection('students')
          .where('classroomId', '==', classroomId)
          .get();
        
        students = studentsSnapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data(),
        }));
      }

      // Calcular estadísticas avanzadas
      const statistics = calculateAdvancedStatistics(attendances, students);

      // Calcular tendencias (última semana vs semana anterior)
      const trends = calculateTrends(attendances);

      return {
        success: true,
        data: {
          classroom: {
            id: classroomDoc.id,
            name: classroom.name,
            grade: classroom.grade,
            section: classroom.section,
          },
          attendances,
          students,
          statistics,
          trends,
          metadata: {
            totalRecords: attendances.length,
            dateRange: {
              start: startDate || null,
              end: endDate || null,
            },
            generatedAt: new Date().toISOString(),
            generatedBy: userId,
          },
        },
      };

    } catch (error) {
      console.error('Error en getAttendanceReportData:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', `Error al generar reporte: ${error.message}`);
    }
  }
);

/**
 * Obtener estadísticas consolidadas de múltiples aulas
 * Ideal para reportes de administradores
 */
exports.getConsolidatedReport = onCall(
  {
    cors: true,
    memory: '1GiB',
    timeoutSeconds: 120,
  },
  async (request) => {
    try {
      const { classroomIds, startDate, endDate } = request.data;

      // Verificar autenticación y rol de admin
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Usuario no autenticado');
      }

      const db = getFirestore();
      const userId = request.auth.uid;
      const userDoc = await db.collection('users').doc(userId).get();
      const userRole = userDoc.data()?.role;

      if (userRole !== 'admin') {
        throw new HttpsError('permission-denied', 'Solo los administradores pueden generar reportes consolidados');
      }

      // Si no se proporcionan IDs, obtener todas las aulas
      let targetClassroomIds = classroomIds;
      if (!targetClassroomIds || targetClassroomIds.length === 0) {
        const classroomsSnapshot = await db.collection('classrooms').get();
        targetClassroomIds = classroomsSnapshot.docs.map(doc => doc.id);
      }

      // Obtener datos de cada aula en paralelo
      const classroomReportsPromises = targetClassroomIds.map(async (classroomId) => {
        try {
          const classroomDoc = await db.collection('classrooms').doc(classroomId).get();
          
          if (!classroomDoc.exists) {
            return null;
          }

          // Query de asistencias - solo por classroomId para evitar índice compuesto
          const query = db.collection('attendance').where('classroomId', '==', classroomId);
          
          const attendancesSnapshot = await query.get();
          let attendances = attendancesSnapshot.docs
            .map(doc => {
              const data = doc.data();
              // Buscar el campo de fecha - puede ser 'date', 'recordedAt' o 'timestamp'
              const dateField = data.date || data.recordedAt || data.timestamp;
              
              if (!dateField || typeof dateField.toDate !== 'function') {
                return null;
              }
              return {
                ...data,
                timestampDate: dateField.toDate(),
              };
            })
            .filter(att => att !== null); // Filtrar documentos inválidos

          // Filtrar por fechas en memoria si se proporcionan
          if (startDate || endDate) {
            const start = startDate ? new Date(startDate) : null;
            const end = endDate ? new Date(endDate) : null;
            
            if (start) start.setHours(0, 0, 0, 0);
            if (end) end.setHours(23, 59, 59, 999);

            attendances = attendances.filter(att => {
              const attDate = att.timestampDate;
              if (start && attDate < start) return false;
              if (end && attDate > end) return false;
              return true;
            });
          }

          // Remover timestampDate temporal
          attendances = attendances.map(({timestampDate, ...rest}) => rest);

          // Obtener estudiantes
          const studentsSnapshot = await db.collection('students')
            .where('classroomId', '==', classroomId)
            .get();

          const classroomData = classroomDoc.data();
          const statistics = calculateAdvancedStatistics(attendances, studentsSnapshot.docs.map(d => d.data()));

          return {
            classroomId,
            classroomName: classroomData.name,
            grade: classroomData.grade,
            section: classroomData.section,
            totalStudents: studentsSnapshot.size,
            totalAttendances: attendances.length,
            statistics,
          };
        } catch (error) {
          console.error(`Error procesando aula ${classroomId}:`, error);
          return null;
        }
      });

      const classroomReports = (await Promise.all(classroomReportsPromises)).filter(r => r !== null);

      // Calcular estadísticas globales
      const globalStatistics = calculateGlobalStatistics(classroomReports);

      return {
        success: true,
        data: {
          classrooms: classroomReports,
          globalStatistics,
          metadata: {
            totalClassrooms: classroomReports.length,
            dateRange: {
              start: startDate || null,
              end: endDate || null,
            },
            generatedAt: new Date().toISOString(),
            generatedBy: userId,
          },
        },
      };

    } catch (error) {
      console.error('Error en getConsolidatedReport:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', `Error al generar reporte consolidado: ${error.message}`);
    }
  }
);

/**
 * Exportar reporte en formato estructurado para Excel/PDF
 * Optimizado para grandes volúmenes de datos
 */
exports.exportReportData = onCall(
  {
    cors: true,
    memory: '1GiB',
    timeoutSeconds: 180,
  },
  async (request) => {
    try {
      const { classroomId, startDate, endDate, format = 'structured' } = request.data;

      if (!classroomId) {
        throw new HttpsError('invalid-argument', 'El ID del aula es requerido');
      }

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Usuario no autenticado');
      }

      const db = getFirestore();
      const userId = request.auth.uid;

      // Verificar permisos
      const classroomDoc = await db.collection('classrooms').doc(classroomId).get();
      
      if (!classroomDoc.exists) {
        throw new HttpsError('not-found', 'Aula no encontrada');
      }

      const classroom = classroomDoc.data();
      const userDoc = await db.collection('users').doc(userId).get();
      const userRole = userDoc.data()?.role;
      
      if (classroom.teacherUid !== userId && userRole !== 'admin') {
        throw new HttpsError('permission-denied', 'No tienes permiso para exportar este reporte');
      }

      // Obtener datos - solo por classroomId para evitar índice compuesto
      const query = db.collection('attendance').where('classroomId', '==', classroomId);
      
      const attendancesSnapshot = await query.get();
      const studentsSnapshot = await db.collection('students').where('classroomId', '==', classroomId).get();
      const teacherDoc = await db.collection('users').doc(classroom.teacherUid).get();

      console.log('🔍 exportReportData - Parámetros recibidos:', { classroomId, startDate, endDate });
      console.log(`📊 Documentos obtenidos de Firestore: ${attendancesSnapshot.size} asistencias, ${studentsSnapshot.size} estudiantes`);

      // Procesar y filtrar asistencias por fecha en memoria
      let attendances = attendancesSnapshot.docs
        .map(doc => {
          const data = doc.data();
          // Buscar el campo de fecha - puede ser 'date', 'recordedAt' o 'timestamp'
          const dateField = data.date || data.recordedAt || data.timestamp;
          
          if (!dateField || typeof dateField.toDate !== 'function') {
            console.warn(`⚠️ Documento ${doc.id} no tiene campo de fecha válido`);
            return null;
          }
          const tsDate = dateField.toDate();
          return {
            id: doc.id,
            studentId: data.studentId,
            studentName: data.studentName,
            status: data.status,
            timestampDate: tsDate,
            date: tsDate.toLocaleDateString('es-PE'),
            time: tsDate.toLocaleTimeString('es-PE'),
            timestamp: tsDate.toISOString(),
            method: data.method || 'manual',
            notes: data.notes || '',
          };
        })
        .filter(att => att !== null); // Filtrar documentos inválidos

      console.log(`📝 Asistencias después de mapeo: ${attendances.length}`);

      // Filtrar por fechas en memoria si se proporcionan
      if (startDate || endDate) {
        const start = startDate ? new Date(startDate) : null;
        const end = endDate ? new Date(endDate) : null;
        
        if (start) start.setHours(0, 0, 0, 0);
        if (end) end.setHours(23, 59, 59, 999);

        console.log(`🗓️ Filtrando por fechas: ${start?.toISOString()} a ${end?.toISOString()}`);

        attendances = attendances.filter(att => {
          const attDate = att.timestampDate;
          if (start && attDate < start) return false;
          if (end && attDate > end) return false;
          return true;
        });
        
        console.log(`✅ Asistencias después de filtro de fechas: ${attendances.length}`);
      }

      // Ordenar por timestamp descendente y remover timestampDate temporal
      attendances.sort((a, b) => b.timestampDate - a.timestampDate);
      attendances = attendances.map(({timestampDate, ...rest}) => rest);

      const students = studentsSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      }));

      const teacher = teacherDoc.exists ? teacherDoc.data() : null;

      // Calcular resumen por estudiante
      const studentSummaries = students.map(student => {
        const studentAttendances = attendances.filter(a => a.studentId === student.id);
        const present = studentAttendances.filter(a => a.status === 'present').length;
        const absent = studentAttendances.filter(a => a.status === 'absent').length;
        const late = studentAttendances.filter(a => a.status === 'late').length;
        const justified = studentAttendances.filter(a => a.status === 'justified').length;
        const total = studentAttendances.length;
        const attendanceRate = total > 0 ? ((present + late) / total * 100).toFixed(2) : '0.00';

        return {
          studentId: student.id,
          studentName: `${student.lastName}, ${student.firstName}`,
          dni: student.dni || '',
          totalClasses: total,
          present,
          absent,
          late,
          justified,
          attendanceRate: `${attendanceRate}%`,
        };
      });

      // Estructura optimizada para exportación (formato compatible con Flutter)
      const exportData = {
        metadata: {
          institution: 'UGEL 06 - Lima',
          classroom: `${classroom.name} - ${classroom.grade}° "${classroom.section}"`,
          teacher: teacher ? `${teacher.firstName} ${teacher.lastName}` : 'N/A',
          dateRange: {
            start: startDate || 'Inicio',
            end: endDate || 'Actualidad',
          },
          generatedAt: new Date().toISOString(),
          totalRecords: attendances.length,
        },
        summary: {
          totalStudents: students.length,
          totalClasses: attendances.length,
          averageAttendance: calculateAverageAttendance(attendances),
          byStatus: {
            present: attendances.filter(a => a.status === 'present').length,
            absent: attendances.filter(a => a.status === 'absent').length,
            late: attendances.filter(a => a.status === 'late').length,
            justified: attendances.filter(a => a.status === 'justified').length,
          },
        },
        studentSummaries: studentSummaries.sort((a, b) => a.studentName.localeCompare(b.studentName)),
        attendances: attendances.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp)),
        students: students,
      };

      // Guardar log de exportación
      await db.collection('report_exports').add({
        userId,
        classroomId,
        format,
        recordCount: attendances.length,
        dateRange: { start: startDate, end: endDate },
        timestamp: FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        data: exportData,
      };

    } catch (error) {
      console.error('Error en exportReportData:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', `Error al exportar reporte: ${error.message}`);
    }
  }
);

/**
 * Obtener análisis de tendencias y predicciones
 */
exports.getAttendanceTrends = onCall(
  {
    cors: true,
    memory: '512MiB',
  },
  async (request) => {
    try {
      const { classroomId, period = 30 } = request.data;

      if (!classroomId) {
        throw new HttpsError('invalid-argument', 'El ID del aula es requerido');
      }

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Usuario no autenticado');
      }

      const db = getFirestore();

      // Obtener asistencias - solo por classroomId para evitar índice compuesto
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - period);

      const attendancesSnapshot = await db.collection('attendances')
        .where('classroomId', '==', classroomId)
        .get();

      // Filtrar por fecha en memoria y ordenar
      const attendances = attendancesSnapshot.docs
        .map(doc => {
          const data = doc.data();
          // Validar que timestamp existe
          if (!data.timestamp || typeof data.timestamp.toDate !== 'function') {
            return null;
          }
          return {
            ...data,
            timestamp: data.timestamp.toDate(),
          };
        })
        .filter(att => att !== null && att.timestamp >= cutoffDate)
        .sort((a, b) => a.timestamp - b.timestamp);

      // Agrupar por día
      const dailyStats = groupByDay(attendances);

      // Calcular tendencias
      const trends = {
        daily: dailyStats,
        weekly: calculateWeeklyTrends(dailyStats),
        predictions: calculateSimplePredictions(dailyStats),
        alerts: generateAlerts(dailyStats),
      };

      return {
        success: true,
        data: trends,
      };

    } catch (error) {
      console.error('Error en getAttendanceTrends:', error);
      throw new HttpsError('internal', error.message);
    }
  }
);

// ============================================================================
// FUNCIONES AUXILIARES DE CÁLCULO
// ============================================================================

/**
 * Calcular estadísticas avanzadas
 */
function calculateAdvancedStatistics(attendances, students) {
  const totalAttendances = attendances.length;
  const totalStudents = students.length;

  const byStatus = {
    present: attendances.filter(a => a.status === 'present').length,
    absent: attendances.filter(a => a.status === 'absent').length,
    late: attendances.filter(a => a.status === 'late').length,
    justified: attendances.filter(a => a.status === 'justified').length,
  };

  const attendanceRate = totalAttendances > 0 
    ? ((byStatus.present + byStatus.late) / totalAttendances * 100).toFixed(2)
    : 0;

  const absenceRate = totalAttendances > 0
    ? (byStatus.absent / totalAttendances * 100).toFixed(2)
    : 0;

  // Calcular estudiantes en riesgo (más de 30% de faltas)
  const studentsAtRisk = students.filter(student => {
    const studentAttendances = attendances.filter(a => a.studentId === student.id);
    const absent = studentAttendances.filter(a => a.status === 'absent').length;
    const total = studentAttendances.length;
    return total > 0 && (absent / total) > 0.3;
  }).length;

  return {
    totalRecords: totalAttendances,
    totalStudents,
    byStatus,
    rates: {
      attendance: parseFloat(attendanceRate),
      absence: parseFloat(absenceRate),
    },
    studentsAtRisk,
  };
}

/**
 * Calcular tendencias comparativas
 */
function calculateTrends(attendances) {
  const now = new Date();
  const oneWeekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const twoWeeksAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);

  const lastWeek = attendances.filter(a => {
    const date = a.timestamp instanceof Date ? a.timestamp : new Date(a.timestamp);
    return date >= oneWeekAgo && date < now;
  });

  const previousWeek = attendances.filter(a => {
    const date = a.timestamp instanceof Date ? a.timestamp : new Date(a.timestamp);
    return date >= twoWeeksAgo && date < oneWeekAgo;
  });

  const lastWeekRate = lastWeek.length > 0
    ? (lastWeek.filter(a => a.status === 'present').length / lastWeek.length * 100).toFixed(2)
    : 0;

  const previousWeekRate = previousWeek.length > 0
    ? (previousWeek.filter(a => a.status === 'present').length / previousWeek.length * 100).toFixed(2)
    : 0;

  const trend = lastWeekRate - previousWeekRate;

  return {
    lastWeek: {
      total: lastWeek.length,
      attendanceRate: parseFloat(lastWeekRate),
    },
    previousWeek: {
      total: previousWeek.length,
      attendanceRate: parseFloat(previousWeekRate),
    },
    change: parseFloat(trend.toFixed(2)),
    direction: trend > 0 ? 'up' : trend < 0 ? 'down' : 'stable',
  };
}

/**
 * Calcular estadísticas globales de múltiples aulas
 */
function calculateGlobalStatistics(classroomReports) {
  const totalStudents = classroomReports.reduce((sum, r) => sum + r.totalStudents, 0);
  const totalAttendances = classroomReports.reduce((sum, r) => sum + r.totalAttendances, 0);
  
  const avgAttendanceRate = classroomReports.length > 0
    ? classroomReports.reduce((sum, r) => sum + (r.statistics.rates?.attendance || 0), 0) / classroomReports.length
    : 0;

  return {
    totalClassrooms: classroomReports.length,
    totalStudents,
    totalAttendances,
    averageAttendanceRate: parseFloat(avgAttendanceRate.toFixed(2)),
  };
}

/**
 * Calcular promedio de asistencia
 */
function calculateAverageAttendance(attendances) {
  if (attendances.length === 0) return 0;
  const present = attendances.filter(a => a.status === 'present' || a.status === 'late').length;
  return parseFloat((present / attendances.length * 100).toFixed(2));
}

/**
 * Agrupar asistencias por día
 */
function groupByDay(attendances) {
  const grouped = {};
  
  attendances.forEach(attendance => {
    const date = attendance.timestamp.toISOString().split('T')[0];
    if (!grouped[date]) {
      grouped[date] = {
        date,
        total: 0,
        present: 0,
        absent: 0,
        late: 0,
      };
    }
    grouped[date].total++;
    grouped[date][attendance.status]++;
  });

  return Object.values(grouped).sort((a, b) => a.date.localeCompare(b.date));
}

/**
 * Calcular tendencias semanales
 */
function calculateWeeklyTrends(dailyStats) {
  const weeks = {};
  
  dailyStats.forEach(day => {
    const date = new Date(day.date);
    const weekStart = new Date(date);
    weekStart.setDate(date.getDate() - date.getDay());
    const weekKey = weekStart.toISOString().split('T')[0];
    
    if (!weeks[weekKey]) {
      weeks[weekKey] = {
        weekStart: weekKey,
        total: 0,
        present: 0,
        absent: 0,
        late: 0,
      };
    }
    
    weeks[weekKey].total += day.total;
    weeks[weekKey].present += day.present;
    weeks[weekKey].absent += day.absent;
    weeks[weekKey].late += day.late;
  });

  return Object.values(weeks);
}

/**
 * Calcular predicciones simples basadas en tendencias
 */
function calculateSimplePredictions(dailyStats) {
  if (dailyStats.length < 7) {
    return { message: 'Datos insuficientes para predicciones' };
  }

  const recentDays = dailyStats.slice(-7);
  const avgAttendance = recentDays.reduce((sum, day) => 
    sum + (day.present / day.total), 0) / recentDays.length;

  return {
    nextWeekAttendanceRate: parseFloat((avgAttendance * 100).toFixed(2)),
    confidence: 'low', // Predicción simple
    basedOnDays: recentDays.length,
  };
}

/**
 * Generar alertas basadas en patrones
 */
function generateAlerts(dailyStats) {
  const alerts = [];
  
  // Alerta: Tendencia decreciente en los últimos 5 días
  if (dailyStats.length >= 5) {
    const recent = dailyStats.slice(-5);
    const rates = recent.map(d => d.present / d.total);
    let decreasing = true;
    
    for (let i = 1; i < rates.length; i++) {
      if (rates[i] >= rates[i - 1]) {
        decreasing = false;
        break;
      }
    }
    
    if (decreasing) {
      alerts.push({
        type: 'warning',
        message: 'Tendencia decreciente en asistencia detectada en los últimos 5 días',
      });
    }
  }

  return alerts;
}

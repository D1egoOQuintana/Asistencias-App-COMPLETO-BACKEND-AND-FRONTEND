/**
 * Funciones de Telegram para notificaciones de asistencia
 * Implementa sistema de códigos de vinculación automática
 */

import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onCall, onRequest, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { FieldValue, getFirestore, QueryDocumentSnapshot } from 'firebase-admin/firestore';
import axios from 'axios';

// Usar la instancia de Firebase Admin ya inicializada
const db = getFirestore();

// TOKEN del bot de Telegram. Se resuelve en runtime para no romper el discovery
// de Firebase Functions durante deploy/predeploy.
function getBotToken(): string {
  const token = process.env.TELEGRAM_BOT_TOKEN;
  if (!token) {
    throw new Error(
      'TELEGRAM_BOT_TOKEN no esta definido. Configuralo como variable de entorno/secreto antes de desplegar.'
    );
  }
  return token;
}

function telegramApiUrl(method: string): string {
  return `https://api.telegram.org/bot${getBotToken()}/${method}`;
}

function telegramErrorSummary(error: any): string {
  const status = error?.response?.status;
  const description = error?.response?.data?.description;
  if (status || description) {
    return 'Telegram API error' + (status ? ' ' + status : '') + (description ? ': ' + description : '');
  }
  return error instanceof Error ? error.message : String(error);
}

const BOT_USERNAME_FALLBACK = process.env.TELEGRAM_BOT_USERNAME || 'mi_bot_asistencia';
let cachedBotUsername: string | null = null;

// Función para generar código aleatorio de 6 dígitos
function generateLinkingCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

async function getBotUsername(): Promise<string> {
  if (cachedBotUsername) return cachedBotUsername;

  try {
    const resp = await axios.get(telegramApiUrl('getMe'));
    const username = resp?.data?.result?.username;
    if (typeof username === 'string' && username.trim().length > 0) {
      cachedBotUsername = username.trim();
      return cachedBotUsername;
    }
  } catch (e) {
    console.warn('No se pudo obtener username del bot por getMe, usando fallback:', telegramErrorSummary(e));
  }

  cachedBotUsername = BOT_USERNAME_FALLBACK;
  return cachedBotUsername;
}

function buildTelegramStartLink(botUsername: string, code: string): string {
  return `https://t.me/${botUsername}?start=${code}`;
}

function createWhatsappActivationMessage(studentName: string, startLink: string): string {
  return `Hola, su link de activacion para: ${studentName}\n${startLink}\nCon este enlace se vincula al bot sin escribir nada.`;
}

// Logging simple en Firestore para diagnóstico
async function logTelegramEvent(event: any) {
  try {
    await db.collection('telegram_events').add({
      ...event,
      createdAt: new Date()
    });
  } catch (e) {
    console.warn('No se pudo escribir telegram_events:', e);
  }
}

// Normaliza teléfonos al formato canónico (solo dígitos) y E.164 Perú (+51)
function toDigits(phone: string | undefined | null): string {
  if (!phone) return '';
  return (phone + '').replace(/\D+/g, '');
}

function toE164Peru(phone: string | undefined | null): string {
  const d = toDigits(phone);
  if (!d) return '';
  if (d.startsWith('51')) return `+${d}`;
  if (d.length === 9) return `+51${d}`; // asume móvil peruano 9 dígitos
  return `+${d}`;
}

// Helper: formatea fecha y hora a partir de distintos posibles campos
function formatAttendanceDateTime(attendanceData: any): { dateStr: string; timeStr: string } {
  // Preferir entryAt/fechaHora si existe
  const maybeTs = attendanceData?.entryAt || attendanceData?.fechaHora || attendanceData?.date;

  let d: Date | null = null;
  try {
    if (!maybeTs) {
      // fallback a ahora si no hay fecha
      d = new Date();
    } else if (typeof maybeTs?.toDate === 'function') {
      d = maybeTs.toDate();
    } else if (typeof maybeTs === 'string') {
      // asume formato YYYY-MM-DD u otro parseable por Date
      d = new Date(maybeTs);
    } else if (maybeTs?._seconds || maybeTs?.seconds) {
      // Timestamp serializado
      const seconds = maybeTs._seconds ?? maybeTs.seconds;
      const nanos = maybeTs._nanoseconds ?? maybeTs.nanoseconds ?? 0;
      d = new Date(seconds * 1000 + Math.floor(nanos / 1_000_000));
    }
  } catch (_e) {
    d = new Date();
  }

  if (!d || isNaN(d.getTime())) {
    d = new Date();
  }

  // Formatear en español de Perú con zona horaria Lima
  const opts: Intl.DateTimeFormatOptions = { timeZone: 'America/Lima' };
  const dateStr = d.toLocaleDateString('es-PE', opts);
  const timeStr = d.toLocaleTimeString('es-PE', { timeZone: 'America/Lima' });
  return { dateStr, timeStr };
}

// Clave de día (YYYY-MM-DD) en Lima para controlar duplicados por día
function getDayKeyLima(date: Date): string {
  return date.toLocaleDateString('en-CA', { timeZone: 'America/Lima' });
}

function getAttendanceDate(attendanceData: any): Date {
  const entryAt = attendanceData?.entryAt?.toDate ? attendanceData.entryAt.toDate() : attendanceData?.entryAt;
  const fechaHora = attendanceData?.fechaHora?.toDate ? attendanceData.fechaHora.toDate() : attendanceData?.fechaHora;
  const dateStr = attendanceData?.date || attendanceData?.fecha || undefined;
  const raw = entryAt || fechaHora || (dateStr ? new Date(dateStr) : new Date());
  return new Date(raw);
}

function timestampToDate(value: any): Date | null {
  if (!value) return null;
  if (typeof value?.toDate === 'function') return value.toDate();
  if (value?._seconds || value?.seconds) {
    const seconds = value._seconds ?? value.seconds;
    const nanos = value._nanoseconds ?? value.nanoseconds ?? 0;
    return new Date(seconds * 1000 + Math.floor(nanos / 1_000_000));
  }
  const parsed = new Date(value);
  return isNaN(parsed.getTime()) ? null : parsed;
}

async function claimTelegramAttendanceEvent(
  eventSnap: QueryDocumentSnapshot,
  eventType: 'entry' | 'exit',
  dayKey: string,
): Promise<boolean> {
  const claimTtlMs = 10 * 60 * 1000;

  return db.runTransaction(async (tx) => {
    const freshSnap = await tx.get(eventSnap.ref);
    if (!freshSnap.exists) return false;

    const current = freshSnap.data()?.telegramNotification || {};
    const status = String(current.status || '').toLowerCase();
    if (status === 'sent' || status === 'processed' || status === 'skipped') {
      return false;
    }

    if (status === 'sending') {
      const claimedAt = timestampToDate(current.claimedAt);
      if (claimedAt && Date.now() - claimedAt.getTime() < claimTtlMs) {
        return false;
      }
    }

    tx.set(eventSnap.ref, {
      telegramNotification: {
        status: 'sending',
        eventType,
        dayKey,
        claimedAt: FieldValue.serverTimestamp(),
      },
    }, { merge: true });

    return true;
  });
}

async function markTelegramAttendanceEventProcessed(
  eventSnap: QueryDocumentSnapshot,
  status: 'processed' | 'error',
  extra: Record<string, unknown> = {},
) {
  await eventSnap.ref.set({
    telegramNotification: {
      status,
      ...extra,
      updatedAt: FieldValue.serverTimestamp(),
    },
  }, { merge: true });
}

function getStudentDisplayName(student: any): string {
  const firstName = student?.firstName || '';
  const lastName = student?.lastName || '';
  const fullName = `${firstName} ${lastName}`.trim();
  if (fullName) return fullName;
  if (student?.fullName) return String(student.fullName).trim();
  return 'Estudiante';
}

function getParentPhone(student: any): string {
  return (
    student?.parentPhone ||
    student?.telefonoApoderado ||
    student?.telefonoPadre ||
    student?.parent_phone ||
    ''
  );
}

async function findStudentById(studentId: string) {
  // Flujo principal en app Flutter
  const studentsDoc = await db.collection('students').doc(studentId).get();
  if (studentsDoc.exists) {
    return {
      data: studentsDoc.data(),
      ref: studentsDoc.ref,
      sourceCollection: 'students',
    };
  }

  // Compatibilidad con flujo backend (idAlumno en colección users)
  const usersDoc = await db.collection('users').doc(studentId).get();
  if (usersDoc.exists) {
    return {
      data: usersDoc.data(),
      ref: usersDoc.ref,
      sourceCollection: 'users',
    };
  }

  return null;
}

async function getUserRole(uid: string, roleHint?: string): Promise<string> {
  const userDoc = await db.collection('users').doc(uid).get();
  const userData = userDoc.data() || {};
  return String(userData.role || roleHint || '');
}

async function userCanManageStudent(
  uid: string,
  studentData: any,
  roleHint?: string,
): Promise<boolean> {
  const role = await getUserRole(uid, roleHint);
  if (role === 'admin') return true;
  if (role !== 'docente' && role !== 'teacher') return false;

  const classroomId = studentData?.classroomId;
  if (!classroomId) return false;

  const classroomDoc = await db.collection('classrooms').doc(String(classroomId)).get();
  if (!classroomDoc.exists) return false;

  const classroomData = classroomDoc.data() || {};
  const teacherUid = String(classroomData.teacherUid || '').trim();
  const teacherId = String(classroomData.teacherId || '').trim();
  const ownerUid = String(classroomData.ownerUid || '').trim();
  return teacherUid === uid || teacherId === uid || ownerUid === uid;
}

async function invalidatePreviousActivationCodes(studentId: string) {
  const prevCodes = await db
    .collection('activation_codes')
    .where('studentId', '==', studentId)
    .where('used', '==', false)
    .limit(20)
    .get();

  const now = new Date();
  for (const doc of prevCodes.docs) {
    await doc.ref.update({
      used: true,
      usedAt: now,
      deactivatedBy: 'regenerated',
    });
  }
}

export const createTelegramActivationLink = onCall({
  memory: '256MiB',
  timeoutSeconds: 30,
  maxInstances: 5,
}, async (request) => {
  const uid = request.auth?.uid;
  const roleHint = String(request.auth?.token?.role || '').trim();
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  const studentId = String(request.data?.studentId || '').trim();
  if (!studentId) {
    throw new HttpsError('invalid-argument', 'studentId es requerido');
  }

  const studentSnap = await db.collection('students').doc(studentId).get();
  if (!studentSnap.exists) {
    throw new HttpsError('not-found', 'Estudiante no encontrado');
  }

  const studentData: any = studentSnap.data() || {};
  const canManage = await userCanManageStudent(uid, studentData, roleHint);
  if (!canManage) {
    throw new HttpsError('permission-denied', 'No tienes permisos para generar el link de este estudiante');
  }

  await invalidatePreviousActivationCodes(studentId);

  const activationCode = generateLinkingCode();
  const studentName = getStudentDisplayName(studentData);
  const parentPhone = getParentPhone(studentData);
  const parentPhoneDigits = toDigits(parentPhone);
  const parentPhoneE164 = toE164Peru(parentPhone);
  const botUsername = await getBotUsername();
  const startLink = buildTelegramStartLink(botUsername, activationCode);

  await db.collection('activation_codes').add({
    code: activationCode,
    studentId,
    studentName,
    parentPhone,
    parentPhoneDigits,
    parentPhoneE164,
    createdAt: new Date(),
    used: false,
    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
    generatedByUid: uid,
    source: 'manual-link',
  });

  return {
    success: true,
    studentName,
    activationCode,
    botUsername,
    startLink,
    whatsappMessage: createWhatsappActivationMessage(studentName, startLink),
  };
});

async function processAttendanceEvent(event: any) {
  console.log('🚀 INICIANDO TRIGGER TELEGRAM - Documento ID:', event.params.docId);
  try {
    console.log('🔔 Trigger de Telegram ejecutado para asistencia:', event.params.docId);
    const afterSnap = event.data?.after;
    if (!afterSnap?.exists) {
      console.log('🗑️ Documento eliminado o inexistente, no se envía notificación.');
      await logTelegramEvent({ type: 'skip.deleted', docId: event.params.docId });
      return;
    }

    const attendanceData = afterSnap.data();
    console.log('📄 Datos de asistencia (keys):', attendanceData ? Object.keys(attendanceData) : 'null');
    await logTelegramEvent({
      type: 'trigger.start',
      docId: event.params.docId,
      collection: event?.topic ? undefined : (
        event?.params?.classroomId
          ? `classrooms/${event.params.classroomId}/attendance`
          : 'asistencias/attendance'
      ),
      attendanceKeys: attendanceData ? Object.keys(attendanceData) : [],
    });
    if (!attendanceData) {
      console.log('❌ No hay datos de asistencia');
      await logTelegramEvent({ type: 'trigger.noData', docId: event.params.docId });
      return;
    }

    const eventDrivenSourceRaw = attendanceData.source || attendanceData.origen || attendanceData.metadata?.createdFrom;
    const eventDrivenSource = `${eventDrivenSourceRaw ?? ''}`.toLowerCase();
    if (attendanceData.eventDriven === true && eventDrivenSource === 'attendance_event') {
      console.log('⏭️ Registro event-driven (attendance_event) detectado; se delega al trigger de attendance_events.');
      await logTelegramEvent({ type: 'skip.eventDriven', docId: event.params.docId });
      return;
    }

    const beforeData = event.data?.before?.data ? event.data.before.data() : null;
    const statusRaw = attendanceData.status || attendanceData.estado || '';
    const status = `${statusRaw}`.toLowerCase();
    const allowedStatuses = new Set(['present', 'late', 'presente', 'tardanza', 'tarde']);
    if (!allowedStatuses.has(status)) {
      console.log('⏭️ Estado no notificado:', statusRaw);
      await logTelegramEvent({ type: 'skip.status', docId: event.params.docId, status: statusRaw });
      return;
    }

    const sourceRaw =
      (eventDrivenSourceRaw ?? attendanceData.source) ||
      attendanceData.origen ||
      attendanceData.metadata?.createdFrom;
    const source = `${sourceRaw ?? ''}`.toLowerCase();
    const hasQr = Boolean(
      attendanceData.qrCodeScanned ||
      attendanceData.qrCode ||
      attendanceData.qr ||
      attendanceData.codigoQr
    );
    const qrSources = new Set(['qr', 'qr_scan', 'qrscan']);
    if (!hasQr && source && !qrSources.has(source)) {
      console.log('⏭️ Fuente manual detectada, se omite notificación. source:', sourceRaw);
      await logTelegramEvent({ type: 'skip.source', docId: event.params.docId, source: sourceRaw });
      return;
    }
    const beforeStatus = beforeData
      ? `${beforeData.status || beforeData.estado || ''}`.toLowerCase()
      : '';
    const beforeSource = beforeData
      ? `${beforeData.source || beforeData.origen || beforeData.metadata?.createdFrom || ''}`.toLowerCase()
      : '';
    const beforeQr = beforeData
      ? beforeData.qrCodeScanned || beforeData.qrCode || beforeData.qr || beforeData.codigoQr
      : false;
    const hadExitBefore = Boolean(beforeData?.exitAt);
    const hasExitNow = Boolean(attendanceData.exitAt);
    const exitJustRecorded = !hadExitBefore && hasExitNow;

    if (beforeData) {
      if (beforeStatus === status && beforeSource === source && Boolean(beforeQr) === hasQr && !exitJustRecorded) {
        console.log('⏭️ No hubo cambios relevantes, se omite notificación duplicada.');
        await logTelegramEvent({ type: 'skip.noChange', docId: event.params.docId });
        return;
      }
    }
    // Compatibilidad: studentId (nuevo) o idAlumno (backend actual)
    const studentId = attendanceData.studentId || attendanceData.idAlumno;
    const classroomId = attendanceData.classroomId || attendanceData.idCurso || event?.params?.classroomId;
    if (!studentId) {
      console.log('❌ No hay studentId/idAlumno en los datos de asistencia');
      await logTelegramEvent({ type: 'trigger.noStudentId', docId: event.params.docId });
      return;
    }
    console.log('🔍 Buscando estudiante con ID:', studentId);
    const studentLookup = await findStudentById(studentId);
    if (!studentLookup) {
      console.log('❌ Estudiante no encontrado con ID:', studentId, '(buscado en students y users)');
      await logTelegramEvent({ type: 'trigger.studentNotFound', docId: event.params.docId, studentId, searchedCollections: ['students', 'users'] });
      return;
    }
    const student = studentLookup.data;
    const studentRef = studentLookup.ref;
    const studentName = getStudentDisplayName(student);
    console.log('👤 Estudiante encontrado:', studentName, 'en', studentLookup.sourceCollection);

    // Evitar notificaciones duplicadas el mismo día por alumno
    const dayKey = getDayKeyLima(getAttendanceDate(attendanceData));
    const eventType: 'entry' | 'exit' = exitJustRecorded ? 'exit' : 'entry';
    const notificationEventKey = `${dayKey}_${eventType}`;
    const notifiedEventKeys = (student as any)?.lastTelegramNotifiedEventKeys || {};
    if (notifiedEventKeys?.[notificationEventKey] === true) {
      console.log('⏭️ Ya se notificó este evento. Omitiendo envío. key:', notificationEventKey);
      await logTelegramEvent({
        type: 'skip.alreadyNotifiedEvent',
        docId: event.params.docId,
        studentId,
        notificationEventKey,
      });
      return;
    }
    if (!exitJustRecorded && (student as any)?.lastTelegramNotifiedDayKey === dayKey) {
      console.log('⏭️ Ya se notificó hoy. Omitiendo envío. dayKey:', dayKey);
      await logTelegramEvent({ type: 'skip.alreadyNotifiedToday', docId: event.params.docId, studentId, dayKey });
      return;
    }
    if (!student?.parentTelegramChatId) {
      console.log('🆕 Primera vez - enviando código de activación');
      await logTelegramEvent({ type: 'activation.start', docId: event.params.docId, studentId, classroomId });
      await sendActivationCode({ ...student, _id: studentRef.id }, { ...attendanceData, studentId, classroomId });
      await studentRef.set({
        lastTelegramNotifiedDayKey: dayKey,
        lastTelegramNotifiedEventKeys: {
          ...(notifiedEventKeys || {}),
          [notificationEventKey]: true,
        },
      }, { merge: true });
    } else {
      console.log('🔁 Ya vinculado - enviando notificación normal');
      await logTelegramEvent({ type: 'regular.start', docId: event.params.docId, studentId, classroomId, chatId: student.parentTelegramChatId });
      await sendRegularNotification(
        { ...student, _id: studentRef.id },
        { ...attendanceData, studentId, classroomId },
        eventType,
      );
      await studentRef.set({
        lastTelegramNotifiedDayKey: dayKey,
        lastTelegramNotifiedEventKeys: {
          ...(notifiedEventKeys || {}),
          [notificationEventKey]: true,
        },
      }, { merge: true });
    }
  } catch (error) {
    console.error('Error enviando notificación de Telegram:', telegramErrorSummary(error));
    await logTelegramEvent({ type: 'trigger.error', docId: event.params?.docId, error: telegramErrorSummary(error) });
  }
}

async function processAttendanceEventNotification(event: any) {
  try {
    const snap = event.data;
    if (!snap?.exists) {
      await logTelegramEvent({
        type: 'events.skip.deleted',
        eventId: event.params?.eventId,
        classroomId: event.params?.classroomId,
      });
      return;
    }

    const attendanceData = snap.data() || {};
    const eventType = String(attendanceData.eventType || '').toLowerCase();
    if (eventType != 'entry' && eventType != 'exit') {
      await logTelegramEvent({
        type: 'events.skip.invalidType',
        eventId: event.params?.eventId,
        classroomId: event.params?.classroomId,
        eventType,
      });
      return;
    }

    const studentId = attendanceData.studentId || attendanceData.idAlumno;
    if (!studentId) {
      await logTelegramEvent({
        type: 'events.skip.noStudentId',
        eventId: event.params?.eventId,
        classroomId: event.params?.classroomId,
      });
      return;
    }

    const studentLookup = await findStudentById(studentId);
    if (!studentLookup) {
      await logTelegramEvent({
        type: 'events.skip.studentNotFound',
        eventId: event.params?.eventId,
        classroomId: event.params?.classroomId,
        studentId,
      });
      return;
    }

    const student = studentLookup.data;
    const studentRef = studentLookup.ref;

    const eventAtRaw = attendanceData.eventAt?.toDate
      ? attendanceData.eventAt.toDate()
      : attendanceData.eventAt;
    const eventDate = eventAtRaw ? new Date(eventAtRaw) : getAttendanceDate(attendanceData);
    const dayKey = getDayKeyLima(eventDate);
    const notificationEventKey = `${dayKey}_${eventType}`;

    if (eventType === 'exit') {
      const eventId = String(event.params?.eventId || '');
      const entryEventId = eventId.endsWith('__exit')
        ? eventId.replace(/__exit$/, '__entry')
        : `${attendanceData.studentId || studentId}_${attendanceData.date || dayKey}__entry`;
      const entryEventSnap = await snap.ref.parent.doc(entryEventId).get();
      const entryEventAt = timestampToDate(entryEventSnap.data()?.eventAt);
      if (entryEventAt && Math.abs(eventDate.getTime() - entryEventAt.getTime()) < 90 * 1000) {
        await markTelegramAttendanceEventProcessed(snap, 'processed', {
          processedAt: FieldValue.serverTimestamp(),
          notificationEventKey,
          skippedReason: 'exit_too_close_to_entry',
        });
        await logTelegramEvent({
          type: 'events.skip.exitTooCloseToEntry',
          eventId: event.params?.eventId,
          classroomId: event.params?.classroomId,
          studentId,
          notificationEventKey,
        });
        return;
      }
    }

    if ((student as any)?.lastTelegramNotifiedEventKeys?.[notificationEventKey] == true) {
      await logTelegramEvent({
        type: 'events.skip.alreadyNotified',
        eventId: event.params?.eventId,
        classroomId: event.params?.classroomId,
        studentId,
        notificationEventKey,
      });
      return;
    }

    const claimed = await claimTelegramAttendanceEvent(snap, eventType, dayKey);
    if (!claimed) {
      await logTelegramEvent({
        type: 'events.skip.alreadyClaimed',
        eventId: event.params?.eventId,
        classroomId: event.params?.classroomId,
        studentId,
        notificationEventKey,
      });
      return;
    }

    if (!student?.parentTelegramChatId) {
      if (eventType == 'entry') {
        await sendActivationCode(
          { ...student, _id: studentRef.id },
          {
            ...attendanceData,
            studentId,
            classroomId: attendanceData.classroomId || event.params?.classroomId,
            entryAt: attendanceData.eventAt || attendanceData.entryAt || attendanceData.fechaHora,
          }
        );
      } else {
        await logTelegramEvent({
          type: 'events.skip.exitWithoutLinkedChat',
          eventId: event.params?.eventId,
          classroomId: event.params?.classroomId,
          studentId,
        });
      }
    } else {
      await sendRegularNotification(
        { ...student, _id: studentRef.id },
        {
          ...attendanceData,
          studentId,
          classroomId: attendanceData.classroomId || event.params?.classroomId,
          entryAt: attendanceData.eventAt || attendanceData.entryAt || attendanceData.fechaHora,
        },
        eventType,
      );
    }

    await studentRef.set({
      lastTelegramNotifiedDayKey: dayKey,
      lastTelegramNotifiedEventKeys: {
        [notificationEventKey]: true,
      },
    }, { merge: true });

    await markTelegramAttendanceEventProcessed(snap, 'processed', {
      processedAt: FieldValue.serverTimestamp(),
      notificationEventKey,
    });

    await logTelegramEvent({
      type: 'events.notified',
      eventId: event.params?.eventId,
      classroomId: event.params?.classroomId,
      studentId,
      eventType,
      notificationEventKey,
    });
  } catch (error) {
    console.error('Error enviando notificación por attendance_events:', telegramErrorSummary(error));
    if (event.data?.exists) {
      await markTelegramAttendanceEventProcessed(event.data, 'error', {
        errorAt: FieldValue.serverTimestamp(),
        error: telegramErrorSummary(error),
      });
    }
    await logTelegramEvent({
      type: 'events.error',
      eventId: event.params?.eventId,
      classroomId: event.params?.classroomId,
      error: telegramErrorSummary(error),
    });
  }
}

// Función que se ejecuta automáticamente cuando se crea o modifica una asistencia (colección principal)
export const sendTelegramNotification = onDocumentWritten({
  document: 'asistencias/{docId}',
  memory: '128MiB',
  timeoutSeconds: 60,
  maxInstances: 5,
}, async (event) => {
  await processAttendanceEvent(event);
});

// Trigger adicional por compatibilidad con colección 'attendance' (si existiera en algunos flujos)
export const sendTelegramNotificationLegacy = onDocumentWritten('attendance/{docId}', async (event) => {
  await processAttendanceEvent(event);
});

// Trigger adicional para asistencias guardadas por aula (scanner QR en tiempo real)
export const sendTelegramNotificationClassroomScoped = onDocumentWritten(
  'classrooms/{classroomId}/attendance/{docId}',
  async (event) => {
    await processAttendanceEvent(event);
  }
);

// Trigger principal para notificaciones por eventos entrada/salida
export const sendTelegramAttendanceEventNotification = onDocumentCreated(
  'classrooms/{classroomId}/attendance_events/{eventId}',
  async (event) => {
    await processAttendanceEventNotification(event);
  }
);

// 🆕 Función para enviar código de activación (PRIMERA VEZ)
async function sendActivationCode(student: any, attendanceData: any) {
  try {
    const studentName = getStudentDisplayName(student);
    const parentPhone = getParentPhone(student);

    // Solo si tiene teléfono configurado
    if (!parentPhone) {
      console.log(`❌ Padre de ${studentName} no tiene teléfono configurado`);
      return;
    }
    
    console.log('📞 Teléfono del padre encontrado:', parentPhone);
    console.log('📞 Tipo de teléfono:', typeof parentPhone);
    console.log('📞 Longitud:', parentPhone?.length);
    
    // Generar código único
    const activationCode = generateLinkingCode();
    
    // Normalizar teléfono
    const parentPhoneDigits = toDigits(parentPhone);
    const parentPhoneE164 = toE164Peru(parentPhone);

    // Guardar código temporal en Firebase
    await db.collection('activation_codes').add({
      code: activationCode,
      studentId: student._id || student.id || attendanceData.studentId,
      studentName,
      parentPhone,
      parentPhoneDigits,
      parentPhoneE164,
      createdAt: new Date(),
      used: false,
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 horas
    });
    
    // Obtener nombre de la clase
    let classroomName = 'No especificada';
    if (attendanceData.classroomId || attendanceData.idCurso || attendanceData.classroomId) {
      const classroomDoc = await db
        .collection('classrooms')
        .doc(attendanceData.classroomId || attendanceData.idCurso)
        .get();
      
      if (classroomDoc.exists) {
        classroomName = classroomDoc.data()?.name || 'No especificada';
      }
    }
    
  const { dateStr, timeStr } = formatAttendanceDateTime(attendanceData);
  const activationMessage = `🎓 *¡${studentName} registró asistencia!*

📚 *Clase:* ${classroomName}
📅 *Fecha:* ${dateStr}
⏰ *Hora de registro:* ${timeStr}

🔔 *Para recibir notificaciones futuras automáticamente, responda con este código:*

\`${activationCode}\`

💡 Solo escriba: ${activationCode}

⏰ Este código expira en 24 horas.`;
    
    // 📱 ENVIAR CÓDIGO INMEDIATAMENTE si el padre ya habló con el bot
  const parentDigits = parentPhoneDigits;
  console.log('📱 Buscando mensajes pendientes para teléfono:', parentPhone);
    console.log('🔍 E164 normalizado:', parentPhoneE164);
    console.log('🔢 Dígitos normalizados:', parentDigits);
    
    // Primero verificar si ya existe el número en conversaciones activas (por igualdad exacta o por dígitos)
    let existingChats = await db
      .collection('telegram_chats')
      .where('phoneNumber', '==', parentPhoneE164)
      .limit(1)
      .get();
    if (existingChats.empty) {
      // Intentar por campo phoneDigits si existe
      const byDigits = await db
        .collection('telegram_chats')
        .where('phoneDigits', '==', parentDigits)
        .limit(1)
        .get();
      if (!byDigits.empty) existingChats = byDigits;
    }
    
    console.log('💬 Chats encontrados:', existingChats.size);
    if (!existingChats.empty) {
      console.log('✅ Chat existente encontrado');
      existingChats.docs.forEach(doc => {
        console.log('📄 Data del chat:', JSON.stringify(doc.data(), null, 2));
      });
    } else {
      console.log('❌ No se encontró chat para este teléfono');
      
      // DEBUGGING: Listar todos los chats para ver formatos
      console.log('🔍 DEBUGGING: Listando todos los chats...');
      const allChats = await db.collection('telegram_chats').limit(10).get();
      allChats.docs.forEach(doc => {
        const data = doc.data();
        console.log('📱 Chat existente - Phone:', `"${data.phoneNumber}"`, 'Digits:', data.phoneDigits, 'ChatId:', data.chatId);
      });
    }
    
    if (!existingChats.empty) {
      // El padre ya está vinculado con el bot, enviar código directamente
      const chatDoc = existingChats.docs[0];
      const chatData = chatDoc.data();
      
      console.log('📨 Enviando código directamente al chat:', chatData.chatId);
      
      await axios.post(telegramApiUrl('sendMessage'), {
        chat_id: chatData.chatId,
        text: activationMessage,
        parse_mode: 'Markdown'
      });
      await logTelegramEvent({ type: 'activation.sentDirect', studentId: attendanceData.studentId, chatId: chatData.chatId });
    } else {
      // Guardar para cuando el usuario escriba /start
      await db.collection('pending_activations').add({
        phoneNumber: parentPhone,
        phoneDigits: parentPhoneDigits,
        phoneE164: parentPhoneE164,
        message: activationMessage,
        code: activationCode,
        studentId: student._id || student.id || attendanceData.studentId,
        createdAt: new Date(),
        sent: false,
        expiresAt: new Date(Date.now() + 48 * 60 * 60 * 1000)
      });
      
      console.log('💾 Mensaje guardado para cuando el padre escriba /start');
      await logTelegramEvent({ type: 'activation.savedPending', studentId: attendanceData.studentId, phoneE164: parentPhoneE164 });
    }
    
    console.log(`✅ Código de activación enviado para ${studentName}: ${activationCode}`);
    
  } catch (error) {
    console.error('Error enviando código de activación:', telegramErrorSummary(error));
  }
}

// 🔁 Función para notificación normal (SIGUIENTES VECES)
async function sendRegularNotification(
  student: any,
  attendanceData: any,
  eventType: 'entry' | 'exit' = 'entry',
) {
  try {
    const studentName = getStudentDisplayName(student);
    let classroomName = 'No especificada';
    
    if (attendanceData.classroomId || attendanceData.idCurso) {
      const classroomDoc = await db
        .collection('classrooms')
        .doc(attendanceData.classroomId || attendanceData.idCurso)
        .get();
      
      if (classroomDoc.exists) {
        classroomName = classroomDoc.data()?.name || 'No especificada';
      }
    }
    
  const { dateStr, timeStr } = formatAttendanceDateTime(attendanceData);
  const isExit = eventType === 'exit';
  const message = `${isExit ? '🏁 *Salida Registrada*' : '🎓 *Asistencia Registrada*'}

👨‍🎓 *Estudiante:* ${studentName}
📚 *Clase:* ${classroomName}
📅 *Fecha:* ${dateStr}
⏰ *Hora de registro:* ${timeStr}

${isExit ? '✅ Su hijo(a) ha registrado salida exitosamente.' : '✅ Su hijo(a) ha registrado asistencia exitosamente.'}`;
    
    await axios.post(telegramApiUrl('sendMessage'), {
      chat_id: student.parentTelegramChatId,
      text: message,
      parse_mode: 'Markdown'
    });
    
    console.log(`Notificación regular enviada a padre de ${studentName}`);
    await logTelegramEvent({ type: 'regular.sent', studentId: attendanceData.studentId, chatId: student.parentTelegramChatId });
    
  } catch (error) {
    console.error('Error enviando notificación regular:', telegramErrorSummary(error));
    await logTelegramEvent({ type: 'regular.error', studentId: attendanceData.studentId, error: telegramErrorSummary(error) });
  }
}

// Webhook para manejar mensajes del bot de Telegram
export const handleTelegramWebhook = onRequest(async (request, response) => {
  try {
    const body = request.body;
    
    if (body.message) {
      const chatId = body.message.chat.id;
      const text = body.message.text?.trim();
      const firstName = body.message.from.first_name || 'Usuario';
      const contact = body.message.contact;
      
      if (text && (text.toLowerCase().startsWith('/start') || text.toLowerCase() === 'start')) {
        const payload = text.split(/\s+/).slice(1).join(' ').trim();

        if (/^\d{6}$/.test(payload)) {
          console.log('🚀 /start con payload detectado:', payload, 'ChatID:', chatId);
          await handleLinkingCode(chatId, payload, firstName);
          response.status(200).send('OK');
          return;
        }

        console.log('🚀 Usuario escribió /start:', firstName, 'ChatID:', chatId);
        
        // Guardar información básica del chat
        await db.collection('telegram_chats').doc(chatId.toString()).set({
          chatId,
          firstName,
          username: body.message.from.username || null,
          lastSeen: new Date()
        }, { merge: true });
        
  const welcomeMessage = `¡Hola ${firstName}! 👋

🎓 Soy el bot de notificaciones de asistencia del colegio.

📝 **Para vincular su cuenta:**
1. Recibirá un código de 6 dígitos (se genera al registrar asistencia)
2. Escriba ese código aquí en el chat
3. Recibirá confirmación de vinculación
4. Empezará a recibir notificaciones automáticas

💡 **Ejemplo:** Si su código es 842913, solo escriba: \`842913\`

📱 Si toca “📱 Compartir mi número”, te vinculo automáticamente y empezarás a recibir notificaciones sin escribir código.`;

        const keyboard = {
          keyboard: [
            [
              { text: '📱 Compartir mi número', request_contact: true }
            ]
          ],
          resize_keyboard: true,
          one_time_keyboard: true
        };

        await axios.post(telegramApiUrl('sendMessage'), {
          chat_id: chatId,
          text: welcomeMessage,
          parse_mode: 'Markdown',
          reply_markup: keyboard
        });
        
        console.log('✅ Mensaje de bienvenida enviado');
        
        // Intentar enviar activaciones pendientes "a ciegas" (si hubiera guardadas sin teléfono)
        // Por ahora no hay criterio seguro aquí; se envía instrucción únicamente.
      }
      // Si el usuario comparte su contacto
      else if (contact && contact.phone_number) {
        const normalizedE164 = toE164Peru(contact.phone_number);
        const digits = toDigits(contact.phone_number);
        console.log('📞 Contacto recibido:', contact.phone_number, '->', normalizedE164, 'digits:', digits);

        await db.collection('telegram_chats').doc(chatId.toString()).set({
          chatId,
          firstName,
          username: body.message.from.username || null,
          phoneNumber: normalizedE164,
          phoneDigits: digits,
          lastSeen: new Date()
        }, { merge: true });

        // Auto-vincular alumnos por teléfono del apoderado
        const phoneCandidates = [normalizedE164, `+${digits}`, digits];
        const studentsSnap = await db
          .collection('students')
          .where('parentPhone', 'in', phoneCandidates)
          .limit(50)
          .get();

        const linked: string[] = [];
        for (const s of studentsSnap.docs) {
          const sdata: any = s.data();
          try {
            await s.ref.set({
              parentTelegramChatId: chatId,
              parentTelegramName: firstName,
              telegramActivatedAt: new Date()
            }, { merge: true });
            linked.push(`${sdata.firstName || ''} ${sdata.lastName || ''}`.trim());
          } catch (e) {
            console.warn('No se pudo vincular estudiante', s.id, e);
          }
        }

        // Marcar códigos de activación pendientes como usados y cancelar pendientes por teléfono (sin índices compuestos)
        try {
          const now = new Date();
          const ac1 = await db.collection('activation_codes').where('parentPhoneE164', '==', normalizedE164).limit(50).get();
          const ac2 = await db.collection('activation_codes').where('parentPhoneDigits', '==', digits).limit(50).get();
          const acMap = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
          [...ac1.docs, ...ac2.docs].forEach(d => acMap.set(d.id, d));
          for (const d of acMap.values()) {
            const data: any = d.data();
            const exp = data.expiresAt?.toDate ? data.expiresAt.toDate() : new Date(data.expiresAt || 0);
            if (!data.used && exp > now) {
              await d.ref.update({ used: true, usedAt: now, deactivatedBy: 'autolink' });
            }
          }
          // Cancelar pending_activations del mismo teléfono
          const pa1 = await db.collection('pending_activations').where('phoneE164', '==', normalizedE164).limit(50).get();
          const pa2 = await db.collection('pending_activations').where('phoneDigits', '==', digits).limit(50).get();
          const paMap = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
          [...pa1.docs, ...pa2.docs].forEach(d => paMap.set(d.id, d));
          for (const d of paMap.values()) {
            const pdata: any = d.data();
            if (pdata && pdata.sent === false) {
              await d.ref.update({ sent: true, canceledAt: now, cancelReason: 'autolink' });
            }
          }
        } catch (e) {
          console.warn('No se pudo limpiar códigos/pendientes tras autolink:', e);
        }

        if (linked.length > 0) {
          const success = `✅ ¡Listo! Vinculación automática exitosa.

👤 Padre/Madre/Tutor: ${firstName}
👨‍🎓 Alumno(s):\n- ${linked.join('\n- ')}

🔔 A partir de ahora recibirá notificaciones automáticas de asistencia.`;
          await axios.post(telegramApiUrl('sendMessage'), {
            chat_id: chatId,
            text: success,
            parse_mode: 'Markdown'
          });
          await logTelegramEvent({ type: 'autolink.success', chatId, phone: normalizedE164, students: linked });
        } else {
          const info = `ℹ️ Número recibido: ${normalizedE164}

No encontré alumnos con este teléfono de apoderado en el sistema. Si cree que es un error, confirme con el colegio que el número esté registrado correctamente.`;
          await axios.post(telegramApiUrl('sendMessage'), {
            chat_id: chatId,
            text: info,
            parse_mode: 'Markdown'
          });
          await logTelegramEvent({ type: 'autolink.noStudent', chatId, phone: normalizedE164 });
        }
      }
      // Verificar si el mensaje es un código de 6 dígitos
      else if (text && /^\d{6}$/.test(text)) {
        await handleLinkingCode(chatId, text, firstName);
      }
      // Respuesta para mensajes no reconocidos
      else if (text && text !== '/start') {
  const helpMessage = `❓ No entiendo ese mensaje.

📱 Para vincular su cuenta al instante, toque “📱 Compartir mi número”.

También puede escribir el **código de 6 dígitos** que se generó al registrar asistencia.

💡 **Ejemplo:** \`842913\``;

        await axios.post(telegramApiUrl('sendMessage'), {
          chat_id: chatId,
          text: helpMessage,
          parse_mode: 'Markdown'
        });
      }
    }
    
    response.status(200).send('OK');
  } catch (error) {
    console.error('Error en webhook:', telegramErrorSummary(error));
    response.status(500).send('Error');
  }
});

// Función para manejar códigos de activación
async function handleLinkingCode(chatId: number, code: string, parentName: string) {
  try {
    console.log('🔐 Procesando código:', code, 'para chat:', chatId);
    
    // Buscar por código y filtrar en memoria para evitar índices compuestos
    const codesSnapshot = await db
      .collection('activation_codes')
      .where('code', '==', code)
      .limit(5)
      .get();

    const candidates = codesSnapshot.docs
      .map(d => ({ ref: d.ref, data: d.data() }))
      .filter(x => !x.data.used && new Date(x.data.expiresAt?.toDate ? x.data.expiresAt.toDate() : x.data.expiresAt) > new Date())
      .sort((a, b) => {
        const ca = (a.data.createdAt as any) || 0;
        const cb = (b.data.createdAt as any) || 0;
        const ta = typeof ca?.toMillis === 'function' ? ca.toMillis() : new Date(ca).getTime();
        const tb = typeof cb?.toMillis === 'function' ? cb.toMillis() : new Date(cb).getTime();
        return tb - ta;
      });

    console.log('🔍 Códigos válidos encontrados:', candidates.length);

    if (candidates.length === 0) {
      console.log('❌ Código no válido:', code);
      
      const errorMessage = `❌ **Código no válido**

El código \`${code}\` no es válido, ya ha sido usado, o ha expirado.

💡 Si necesita un nuevo código, pida al profesor que registre otra asistencia.`;

      await axios.post(telegramApiUrl('sendMessage'), {
        chat_id: chatId,
        text: errorMessage,
        parse_mode: 'Markdown'
      });
      return;
    }
    
  const codeDoc = candidates[0].ref;
  const codeData: any = candidates[0].data;
    
    console.log('✅ Código válido encontrado para estudiante:', codeData.studentName);
    
    // Consultar estudiante
    const stuRef = db.collection('students').doc(codeData.studentId);
    const stuSnap = await stuRef.get();
    const stu: any = stuSnap.data() || {};

    // Si ya estaba vinculado a este chat, solo marcar código y no spamear
    if (stu.parentTelegramChatId && String(stu.parentTelegramChatId) === String(chatId)) {
      await codeDoc.update({ used: true, usedAt: new Date(), activatedChatId: chatId, activatedParentName: parentName, note: 'already-linked' });
      console.log('ℹ️ Código aplicado pero alumno ya estaba vinculado, no se envía mensaje duplicado');
      return;
    }

    // ✅ ACTIVAR NOTIFICACIONES: Actualizar el estudiante con el chatId del padre
    await stuRef.set({
      parentTelegramChatId: chatId,
      parentTelegramName: parentName,
      telegramActivatedAt: new Date()
    }, { merge: true });
    
    console.log('📱 Estudiante actualizado con chat ID');
    
    // Marcar el código como usado
    await codeDoc.update({
      used: true,
      usedAt: new Date(),
      activatedChatId: chatId,
      activatedParentName: parentName
    });
    
    console.log('🔒 Código marcado como usado');

    // Guardar teléfono en telegram_chats para coincidencias futuras
    try {
      const phoneE164 = toE164Peru(codeData.parentPhone);
      const phoneDigits = toDigits(codeData.parentPhone);
      await db.collection('telegram_chats').doc(chatId.toString()).set({
        chatId,
        firstName: parentName,
        phoneNumber: phoneE164,
        phoneDigits,
        lastSeen: new Date()
      }, { merge: true });
      console.log('📒 telegram_chats actualizado con teléfono del padre');
    } catch (e) {
      console.warn('No se pudo actualizar telegram_chats con teléfono:', e);
    }
    
    const successMessage = `✅ **¡Notificaciones Activadas!**

👨‍🎓 **Estudiante:** ${codeData.studentName}
🆔 **Código:** ${code}
    📅 **Activado:** ${new Date().toLocaleDateString('es-PE', { timeZone: 'America/Lima' })} a las ${new Date().toLocaleTimeString('es-PE', { timeZone: 'America/Lima' })}

🔔 **A partir de ahora recibirá notificaciones automáticas** cada vez que ${codeData.studentName.split(' ')[0]} registre asistencia.

¡Sistema activado correctamente! 📚✨`;

    await axios.post(telegramApiUrl('sendMessage'), {
      chat_id: chatId,
      text: successMessage,
      parse_mode: 'Markdown'
    });
    
    console.log(`✅ Activación exitosa: ${parentName} (${chatId}) -> ${codeData.studentName}`);
    
  } catch (error) {
    console.error('Error procesando código de activación:', telegramErrorSummary(error));
    
    const errorMessage = `⚠️ **Error temporal**

Hubo un problema procesando su código. Por favor, inténtelo nuevamente en unos momentos.`;

    await axios.post(telegramApiUrl('sendMessage'), {
      chat_id: chatId,
      text: errorMessage,
      parse_mode: 'Markdown'
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICACIÓN DE INASISTENCIA (AUSENCIA)
//
// La ausencia no genera ningún documento, así que se DETECTA comparando los
// estudiantes activos del aula contra quienes registraron asistencia hoy.
// - Manual:     onCall `notifyClassroomAbsences` (botón en la app)
// - Automático: onSchedule `notifyAbsencesScheduled` corre periódicamente y,
//               por cada aula, notifica al pasar el endTime del horario del día.
// Solo notifica a apoderados con `parentTelegramChatId` (vinculados al bot).
// ─────────────────────────────────────────────────────────────────────────────

const WEEKDAY_KEYS = [
  'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday',
];

// Hora/minuto/día-semana actuales en zona horaria de Lima.
function getLimaNowParts(now: Date): { hour: number; minute: number; weekday: string; dayKey: string } {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/Lima',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    weekday: 'long',
  }).formatToParts(now);

  let hour = 0;
  let minute = 0;
  let weekdayName = '';
  for (const p of parts) {
    if (p.type === 'hour') hour = parseInt(p.value, 10);
    if (p.type === 'minute') minute = parseInt(p.value, 10);
    if (p.type === 'weekday') weekdayName = p.value.toLowerCase();
  }
  // '24' a veces aparece para medianoche según runtime; normalizar.
  if (hour === 24) hour = 0;

  return {
    hour,
    minute,
    weekday: weekdayName,
    dayKey: getDayKeyLima(now),
  };
}

// Convierte "HH:mm" en minutos desde medianoche. Devuelve null si inválido.
function parseHHmmToMinutes(value: any): number | null {
  if (typeof value !== 'string') return null;
  const m = value.trim().match(/^(\d{1,2}):(\d{2})$/);
  if (!m) return null;
  const h = parseInt(m[1], 10);
  const min = parseInt(m[2], 10);
  if (isNaN(h) || isNaN(min) || h > 23 || min > 59) return null;
  return h * 60 + min;
}

function formatLimaDate(dayKey: string): string {
  // dayKey es YYYY-MM-DD; formatear amigable es-PE.
  try {
    const d = new Date(`${dayKey}T12:00:00`);
    return d.toLocaleDateString('es-PE', { timeZone: 'America/Lima' });
  } catch (_e) {
    return dayKey;
  }
}

function classroomDisplayName(data: any): string {
  const grade = (data?.grade ?? '').toString().trim();
  const section = (data?.section ?? '').toString().trim();
  const name = (data?.name ?? '').toString().trim();
  if (grade && section) {
    return `${grade}° ${section}${name ? ` – ${name}` : ''}`;
  }
  return name || 'Aula';
}

function isPresenceAttendance(data: any): boolean {
  const status = (data?.status ?? '').toString().trim().toLowerCase();
  const source = (data?.source ?? '').toString().trim().toLowerCase();
  if (status === 'absent' || status === 'ausente' || source === 'auto_absent') {
    return false;
  }
  return true;
}

// Envía a un apoderado (ya vinculado) el aviso de inasistencia.
async function sendAbsenceNotification(
  student: any,
  classroomName: string,
  dayKey: string,
): Promise<boolean> {
  const chatId = student?.parentTelegramChatId;
  if (!chatId) return false;

  const studentName = getStudentDisplayName(student);
  const firstName = studentName.split(' ')[0] || studentName;
  const message = `⚠️ *Inasistencia*

👨‍🎓 *Estudiante:* ${studentName}
📚 *Clase:* ${classroomName}
📅 *Fecha:* ${formatLimaDate(dayKey)}

❌ ${firstName} no registró asistencia hoy. Si cree que es un error, comuníquese con la institución educativa.`;

  await axios.post(telegramApiUrl('sendMessage'), {
    chat_id: chatId,
    text: message,
    parse_mode: 'Markdown',
  });
  return true;
}

/**
 * Calcula los ausentes de un aula en una fecha y notifica por Telegram a los
 * apoderados vinculados. Idempotente por estudiante/día vía
 * `lastTelegramNotifiedEventKeys[<dayKey>_absence]`.
 */
async function computeAndNotifyAbsences(
  classroomId: string,
  dayKey: string,
): Promise<{ total: number; absent: number; notified: number; skippedNoChat: number; alreadyNotified: number }> {
  const result = { total: 0, absent: 0, notified: 0, skippedNoChat: 0, alreadyNotified: 0 };

  const classroomSnap = await db.collection('classrooms').doc(classroomId).get();
  if (!classroomSnap.exists) return result;
  const classroomName = classroomDisplayName(classroomSnap.data());

  // 1) Estudiantes activos del aula.
  const studentsSnap = await db
    .collection('students')
    .where('classroomId', '==', classroomId)
    .where('isActive', '==', true)
    .get();
  result.total = studentsSnap.size;
  if (studentsSnap.empty) return result;

  // 2) Asistencia del día (subcolección del aula). Set de studentId presentes.
  const presentIds = new Set<string>();
  const attendanceSnap = await db
    .collection('classrooms')
    .doc(classroomId)
    .collection('attendance')
    .where('date', '==', dayKey)
    .get();
  for (const doc of attendanceSnap.docs) {
    const data = doc.data();
    if (!isPresenceAttendance(data)) continue;
    const sid = (data?.studentId ?? '').toString().trim();
    if (sid) presentIds.add(sid);
  }

  const absenceKey = `${dayKey}_absence`;

  // 3) Ausentes = activos sin registro hoy → notificar a vinculados.
  for (const stuDoc of studentsSnap.docs) {
    const student: any = stuDoc.data();
    if (presentIds.has(stuDoc.id)) continue;
    result.absent += 1;

    const notifiedKeys = student?.lastTelegramNotifiedEventKeys || {};
    if (notifiedKeys?.[absenceKey] === true) {
      result.alreadyNotified += 1;
      continue;
    }

    if (!student?.parentTelegramChatId) {
      result.skippedNoChat += 1;
      continue;
    }

    try {
      const sent = await sendAbsenceNotification(
        { ...student, _id: stuDoc.id },
        classroomName,
        dayKey,
      );
      if (sent) {
        result.notified += 1;
        await stuDoc.ref.set({
          lastTelegramNotifiedEventKeys: {
            ...(notifiedKeys || {}),
            [absenceKey]: true,
          },
        }, { merge: true });
        await logTelegramEvent({ type: 'absence.sent', studentId: stuDoc.id, classroomId, dayKey });
      }
    } catch (e) {
      await logTelegramEvent({ type: 'absence.error', studentId: stuDoc.id, classroomId, dayKey, error: telegramErrorSummary(e) });
    }
  }

  return result;
}

/**
 * MANUAL — el docente/admin dispara la notificación de ausentes de un aula.
 * data: { classroomId: string, date?: 'YYYY-MM-DD' }
 */
export const notifyClassroomAbsences = onCall({
  memory: '256MiB',
  timeoutSeconds: 120,
  maxInstances: 5,
}, async (request) => {
  const uid = request.auth?.uid;
  const roleHint = String(request.auth?.token?.role || '').trim();
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  const classroomId = String(request.data?.classroomId || '').trim();
  if (!classroomId) {
    throw new HttpsError('invalid-argument', 'classroomId es requerido');
  }

  // Permisos: admin, o docente dueño del aula.
  const role = await getUserRole(uid, roleHint);
  if (role !== 'admin') {
    const classroomDoc = await db.collection('classrooms').doc(classroomId).get();
    if (!classroomDoc.exists) {
      throw new HttpsError('not-found', 'Aula no encontrada');
    }
    const cd = classroomDoc.data() || {};
    const owns =
      String(cd.teacherUid || '').trim() === uid ||
      String(cd.teacherId || '').trim() === uid ||
      String(cd.ownerUid || '').trim() === uid;
    if (!owns) {
      throw new HttpsError('permission-denied', 'No tienes permisos sobre esta aula');
    }
  }

  const dayKey = String(request.data?.date || getDayKeyLima(new Date())).trim();
  const r = await computeAndNotifyAbsences(classroomId, dayKey);

  await logTelegramEvent({ type: 'absence.manual', uid, classroomId, dayKey, ...r });

  return {
    success: true,
    dayKey,
    ...r,
  };
});

/**
 * AUTOMÁTICO — corre cada 30 min y, por cada aula activa, notifica ausentes
 * una vez que ha pasado el endTime del horario del día. Marca el aula con
 * `lastAbsenceNotifiedDayKey` para no repetir el mismo día.
 *
 * Requiere Cloud Scheduler (plan Blaze). Zona horaria: America/Lima.
 */
export const notifyAbsencesScheduled = onSchedule({
  schedule: 'every 30 minutes',
  timeZone: 'America/Lima',
  memory: '256MiB',
  timeoutSeconds: 300,
  maxInstances: 1,
}, async () => {
  const now = new Date();
  const { hour, minute, weekday, dayKey } = getLimaNowParts(now);
  const nowMinutes = hour * 60 + minute;

  const classroomsSnap = await db
    .collection('classrooms')
    .where('isActive', '==', true)
    .get();

  let processed = 0;
  let totalNotified = 0;

  for (const classDoc of classroomsSnap.docs) {
    const data: any = classDoc.data();

    // Ya notificado hoy → saltar.
    if (data?.lastAbsenceNotifiedDayKey === dayKey) continue;

    // Horario del día actual.
    const schedule = data?.schedule;
    if (!schedule || typeof schedule !== 'object') continue;
    const todaySchedule = schedule[weekday];
    if (!todaySchedule) continue; // no hay clase hoy

    const endMinutes = parseHHmmToMinutes(todaySchedule.endTime);
    if (endMinutes === null) continue; // sin endTime válido

    // Aún no termina la clase → esperar a la próxima corrida.
    if (nowMinutes < endMinutes) continue;

    try {
      const r = await computeAndNotifyAbsences(classDoc.id, dayKey);
      processed += 1;
      totalNotified += r.notified;

      // Marcar el aula como ya procesada hoy (aunque notified sea 0, para no
      // recalcular en cada corrida posterior del mismo día).
      await classDoc.ref.set({ lastAbsenceNotifiedDayKey: dayKey }, { merge: true });

      await logTelegramEvent({
        type: 'absence.scheduled',
        classroomId: classDoc.id,
        dayKey,
        weekday,
        endTime: todaySchedule.endTime,
        ...r,
      });
    } catch (e) {
      await logTelegramEvent({
        type: 'absence.scheduled.error',
        classroomId: classDoc.id,
        dayKey,
        error: telegramErrorSummary(e),
      });
    }
  }

  console.log(`notifyAbsencesScheduled: aulas procesadas=${processed}, notificados=${totalNotified}, dayKey=${dayKey}`);
});

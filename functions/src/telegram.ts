/**
 * Funciones de Telegram para notificaciones de asistencia
 * Implementa sistema de códigos de vinculación automática
 */

import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onRequest } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import axios from 'axios';

// Usar la instancia de Firebase Admin ya inicializada
const db = getFirestore();

// TOKEN del bot de Telegram
const BOT_TOKEN = '8305613209:AAFxld-nM5Qwe5Rs1TTDEbyXHOdu2Vg_NQw';

// Función para generar código aleatorio de 6 dígitos
function generateLinkingCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
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
      collection: event?.topic ? undefined : 'asistencias/attendance',
      attendanceKeys: attendanceData ? Object.keys(attendanceData) : [],
    });
    if (!attendanceData) {
      console.log('❌ No hay datos de asistencia');
      await logTelegramEvent({ type: 'trigger.noData', docId: event.params.docId });
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

    const sourceRaw = attendanceData.source || attendanceData.origen || attendanceData.metadata?.createdFrom;
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
    if (beforeData) {
      const beforeStatus = `${beforeData.status || beforeData.estado || ''}`.toLowerCase();
      const beforeSource = `${beforeData.source || beforeData.origen || beforeData.metadata?.createdFrom || ''}`.toLowerCase();
      const beforeQr = beforeData.qrCodeScanned || beforeData.qrCode || beforeData.qr || beforeData.codigoQr;
      if (beforeStatus === status && beforeSource === source && Boolean(beforeQr) === hasQr) {
        console.log('⏭️ No hubo cambios relevantes, se omite notificación duplicada.');
        await logTelegramEvent({ type: 'skip.noChange', docId: event.params.docId });
        return;
      }
    }
    // Compatibilidad: studentId (nuevo) o idAlumno (backend actual)
    const studentId = attendanceData.studentId || attendanceData.idAlumno;
    const classroomId = attendanceData.classroomId || attendanceData.idCurso;
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
    if ((student as any)?.lastTelegramNotifiedDayKey === dayKey) {
      console.log('⏭️ Ya se notificó hoy. Omitiendo envío. dayKey:', dayKey);
      await logTelegramEvent({ type: 'skip.alreadyNotifiedToday', docId: event.params.docId, studentId, dayKey });
      return;
    }
    if (!student?.parentTelegramChatId) {
      console.log('🆕 Primera vez - enviando código de activación');
      await logTelegramEvent({ type: 'activation.start', docId: event.params.docId, studentId, classroomId });
      await sendActivationCode({ ...student, _id: studentRef.id }, { ...attendanceData, studentId, classroomId });
      await studentRef.set({ lastTelegramNotifiedDayKey: dayKey }, { merge: true });
    } else {
      console.log('🔁 Ya vinculado - enviando notificación normal');
      await logTelegramEvent({ type: 'regular.start', docId: event.params.docId, studentId, classroomId, chatId: student.parentTelegramChatId });
      await sendRegularNotification({ ...student, _id: studentRef.id }, { ...attendanceData, studentId, classroomId });
      await studentRef.set({ lastTelegramNotifiedDayKey: dayKey }, { merge: true });
    }
  } catch (error) {
    console.error('Error enviando notificación de Telegram:', error);
    await logTelegramEvent({ type: 'trigger.error', docId: event.params?.docId, error: String(error) });
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
⏰ *Hora:* ${timeStr}

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
      
      await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
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
    console.error('Error enviando código de activación:', error);
  }
}

// 🔁 Función para notificación normal (SIGUIENTES VECES)
async function sendRegularNotification(student: any, attendanceData: any) {
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
  const message = `🎓 *Asistencia Registrada*

👨‍🎓 *Estudiante:* ${studentName}
📚 *Clase:* ${classroomName}
📅 *Fecha:* ${dateStr}
⏰ *Hora:* ${timeStr}

✅ Su hijo(a) ha registrado asistencia exitosamente.`;
    
    await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
      chat_id: student.parentTelegramChatId,
      text: message,
      parse_mode: 'Markdown'
    });
    
    console.log(`Notificación regular enviada a padre de ${studentName}`);
    await logTelegramEvent({ type: 'regular.sent', studentId: attendanceData.studentId, chatId: student.parentTelegramChatId });
    
  } catch (error) {
    console.error('Error enviando notificación regular:', error);
    await logTelegramEvent({ type: 'regular.error', studentId: attendanceData.studentId, error: String(error) });
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
      
        if (text === '/start' || text === 'start') {
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

        await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
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
          await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
            chat_id: chatId,
            text: success,
            parse_mode: 'Markdown'
          });
          await logTelegramEvent({ type: 'autolink.success', chatId, phone: normalizedE164, students: linked });
        } else {
          const info = `ℹ️ Número recibido: ${normalizedE164}

No encontré alumnos con este teléfono de apoderado en el sistema. Si cree que es un error, confirme con el colegio que el número esté registrado correctamente.`;
          await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
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

        await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
          chat_id: chatId,
          text: helpMessage,
          parse_mode: 'Markdown'
        });
      }
    }
    
    response.status(200).send('OK');
  } catch (error) {
    console.error('Error en webhook:', error);
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

      await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
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

    await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
      chat_id: chatId,
      text: successMessage,
      parse_mode: 'Markdown'
    });
    
    console.log(`✅ Activación exitosa: ${parentName} (${chatId}) -> ${codeData.studentName}`);
    
  } catch (error) {
    console.error('Error procesando código de activación:', error);
    
    const errorMessage = `⚠️ **Error temporal**

Hubo un problema procesando su código. Por favor, inténtelo nuevamente en unos momentos.`;

    await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
      chat_id: chatId,
      text: errorMessage,
      parse_mode: 'Markdown'
    });
  }
}
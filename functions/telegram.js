const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {onRequest} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const axios = require('axios');

// TOKEN del bot (obtenido de @BotFather). Obligatorio vía variable de entorno (sin fallback).
const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
if (!BOT_TOKEN) {
  throw new Error('TELEGRAM_BOT_TOKEN no está definido en el entorno.');
}

// Función que se ejecuta automáticamente cuando se crea una asistencia
exports.sendTelegramNotification = onDocumentCreated('attendance/{docId}', async (event) => {
  try {
    const attendanceData = event.data.data();
    
    // Solo enviar si es presente
    if (attendanceData.status?.toLowerCase() !== 'present') {
      console.log('Asistencia no es presente, no enviar notificación');
      return;
    }
    
    // Obtener datos del estudiante
    const studentDoc = await admin.firestore()
      .collection('students')
      .doc(attendanceData.studentId)
      .get();
    
    if (!studentDoc.exists) {
      console.log('Estudiante no encontrado');
      return;
    }
    
    const student = studentDoc.data();
    
    // Verificar que el padre tenga chat_id de Telegram
    if (!student.parentTelegramChatId) {
      console.log(`Padre de ${student.firstName} no tiene Telegram configurado`);
      return;
    }
    
    // Obtener datos del aula
    let classroomName = 'No especificada';
    if (attendanceData.classroomId) {
      const classroomDoc = await admin.firestore()
        .collection('classrooms')
        .doc(attendanceData.classroomId)
        .get();
      
      if (classroomDoc.exists) {
        classroomName = classroomDoc.data().name;
      }
    }
    
    // Crear mensaje
    const studentName = `${student.firstName} ${student.lastName}`;
    const timestamp = attendanceData.timestamp?.toDate() || new Date();
    const time = timestamp.toLocaleString('es-PE', { 
      timeZone: 'America/Lima',
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
    
    const message = `📚 *Notificación de Asistencia*

Estimado padre/madre de familia,

Su hijo(a) *${studentName}* ha registrado su asistencia:

🏫 Aula: ${classroomName}
📅 Fecha y hora: ${time}
📝 Estado: *PRESENTE*

Este es un mensaje automático del sistema de asistencias.

¡Gracias!`;

    // Enviar mensaje por Telegram
    const telegramUrl = `https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`;
    
    console.log(`Enviando mensaje a chat_id: ${student.parentTelegramChatId}`);
    
    const response = await axios.post(telegramUrl, {
      chat_id: student.parentTelegramChatId,
      text: message,
      parse_mode: 'Markdown'
    });
    
    console.log('Respuesta de Telegram:', response.status);
    
    // Marcar como enviado
    await event.data.ref.update({
      telegramSent: true,
      telegramSentAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(`✅ Notificación enviada exitosamente a ${studentName}`);
    
  } catch (error) {
    console.error('Error enviando notificación Telegram:', error.message);
    if (error.response) {
      console.error('Respuesta de error:', error.response.data);
    }
  }
});

// Función para manejar comandos del bot
exports.handleTelegramWebhook = onRequest(async (request, response) => {
  try {
    const update = request.body;
    console.log('Webhook recibido:', JSON.stringify(update, null, 2));
    
    if (update.message && update.message.text === '/start') {
      const chatId = update.message.chat.id;
      const userName = update.message.from.first_name || 'Usuario';
      
      // Mensaje de bienvenida
      const welcomeMessage = `¡Hola ${userName}! 👋

Bienvenido al bot de notificaciones de asistencias.

Para recibir notificaciones de su hijo(a), debe proporcionar este código al colegio:

\`${chatId}\`

Una vez configurado, recibirá notificaciones automáticas cuando su hijo(a) registre asistencia.

¡Gracias! 📚`;

      await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
        chat_id: chatId,
        text: welcomeMessage,
        parse_mode: 'Markdown'
      });
      
      console.log(`Mensaje de bienvenida enviado a ${userName} (${chatId})`);
    }
    
    response.status(200).send('OK');
  } catch (error) {
    console.error('Error en webhook:', error);
    response.status(500).send('Error');
  }
});
// Firebase Functions - Bot Telegram
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

// TOKEN del bot (obtenido de @BotFather)
const BOT_TOKEN = 'TU_BOT_TOKEN_AQUI';

// Función que se ejecuta automáticamente cuando se crea una asistencia
exports.sendTelegramNotification = onDocumentCreated('attendance/{docId}', async (event) => {
  try {
    const attendanceData = event.data.data();
    
    // Solo enviar si es presente
    if (attendanceData.status?.toLowerCase() !== 'present') {
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
    
    await axios.post(telegramUrl, {
      chat_id: student.parentTelegramChatId,
      text: message,
      parse_mode: 'Markdown'
    });
    
    // Marcar como enviado
    await event.data.ref.update({
      telegramSent: true,
      telegramSentAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(`✅ Notificación enviada a ${studentName}`);
    
  } catch (error) {
    console.error('Error enviando notificación Telegram:', error);
  }
});

// Función para manejar comandos del bot
exports.handleTelegramWebhook = onRequest(async (request, response) => {
  try {
    const update = request.body;
    
    if (update.message && update.message.text === '/start') {
      const chatId = update.message.chat.id;
      const userName = update.message.from.first_name;
      
      // Mensaje de bienvenida
      const welcomeMessage = `¡Hola ${userName}! 👋

Bienvenido al bot de notificaciones de asistencias.

Para recibir notificaciones de su hijo(a), debe:
1. Proporcionar este código al colegio: \`${chatId}\`
2. El colegio configurará su cuenta

Una vez configurado, recibirá notificaciones automáticas cuando su hijo(a) registre asistencia.

¡Gracias! 📚`;

      await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
        chat_id: chatId,
        text: welcomeMessage,
        parse_mode: 'Markdown'
      });
    }
    
    response.status(200).send('OK');
  } catch (error) {
    console.error('Error en webhook:', error);
    response.status(500).send('Error');
  }
});
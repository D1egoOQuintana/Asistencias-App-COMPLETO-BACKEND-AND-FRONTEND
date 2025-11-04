/**
 * Funciones de Telegram para notificaciones de asistencia
 */

const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {onRequest} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const axios = require('axios');

// TOKEN del bot de Telegram
const BOT_TOKEN = '8305613209:AAFxld-nM5Qwe5Rs1TTDEbyXHOdu2Vg_NQw';

// Función que se ejecuta automáticamente cuando se crea una asistencia
const sendTelegramNotification = onDocumentCreated('attendance/{docId}', async (event) => {
  try {
    const attendanceData = event.data.data();
    
    if (attendanceData.status?.toLowerCase() !== 'present') {
      return;
    }
    
    const studentDoc = await admin.firestore()
      .collection('students')
      .doc(attendanceData.studentId)
      .get();
    
    if (!studentDoc.exists) {
      console.log('Estudiante no encontrado');
      return;
    }
    
    const student = studentDoc.data();
    
    if (!student.parentTelegramChatId) {
      console.log(`Padre de ${student.firstName} no tiene Telegram configurado`);
      return;
    }
    
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
    
    const message = `🎓 *Asistencia Registrada*

👨‍🎓 *Estudiante:* ${student.firstName} ${student.lastName}
📚 *Clase:* ${classroomName}
📅 *Fecha:* ${new Date(attendanceData.date.toDate()).toLocaleDateString('es-CO')}
⏰ *Hora:* ${new Date(attendanceData.date.toDate()).toLocaleTimeString('es-CO')}

✅ Su hijo(a) ha registrado asistencia exitosamente.`;
    
    await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
      chat_id: student.parentTelegramChatId,
      text: message,
      parse_mode: 'Markdown'
    });
    
    console.log(`Notificación de Telegram enviada a padre de ${student.firstName}`);
    
  } catch (error) {
    console.error('Error enviando notificación de Telegram:', error);
  }
});

// Webhook para manejar mensajes del bot de Telegram
const handleTelegramWebhook = onRequest(async (request, response) => {
  try {
    const body = request.body;
    
    if (body.message) {
      const chatId = body.message.chat.id;
      const text = body.message.text;
      
      if (text === '/start') {
        const welcomeMessage = `¡Hola! 👋

Soy el bot de notificaciones de asistencia del colegio.

Su *Chat ID* es: \`${chatId}\`

Por favor, proporcione este código al administrador del sistema para vincular las notificaciones de asistencia de su hijo(a) con este chat.

Una vez configurado, recibirá notificaciones automáticas cuando su hijo(a) registre asistencia.

¡Gracias! 📚`;

        await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
          chat_id: chatId,
          text: welcomeMessage,
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

module.exports = {
  sendTelegramNotification,
  handleTelegramWebhook
};
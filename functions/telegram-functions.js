/**
 * Funciones de Telegram para notificaciones de asistencia
 */

const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {onRequest} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const axios = require('axios');

// TOKEN del bot de Telegram. Obligatorio vía variable de entorno (sin fallback).
const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
if (!BOT_TOKEN) {
  throw new Error('TELEGRAM_BOT_TOKEN no está definido en el entorno.');
}

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
      const contact = body.message.contact;
      
      // Comando /start - Mostrar opciones de vinculación
      if (text === '/start') {
        const welcomeMessage = `¡Hola! 👋

Soy el bot de notificaciones de asistencia del colegio.

Para recibir notificaciones de asistencia de su hijo(a), tiene 2 opciones:

*Opción 1 - Vinculación Automática:*
Presione el botón "📱 Compartir mi número" para vincular automáticamente su cuenta.

*Opción 2 - Vinculación Manual:*
Su Chat ID es: \`${chatId}\`
Proporcione este código al administrador del colegio.

¡Gracias! 📚`;

        // Crear teclado con botón para compartir número
        await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
          chat_id: chatId,
          text: welcomeMessage,
          parse_mode: 'Markdown',
          reply_markup: {
            keyboard: [
              [{
                text: '📱 Compartir mi número de teléfono',
                request_contact: true
              }]
            ],
            resize_keyboard: true,
            one_time_keyboard: true
          }
        });
      }
      
      // El usuario compartió su número de teléfono
      if (contact) {
        const phoneNumber = contact.phone_number;
        
        // Buscar estudiante por número de teléfono del padre
        const studentsQuery = await admin.firestore()
          .collection('students')
          .where('parentPhone', '==', phoneNumber)
          .get();
        
        if (studentsQuery.empty) {
          // No se encontró estudiante con ese número
          await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
            chat_id: chatId,
            text: `❌ No se encontró ningún estudiante con el número de teléfono *${phoneNumber}*.

Por favor, asegúrese de que:
1. El número esté registrado en el sistema del colegio
2. El número incluya el código de país (+51 para Perú)

Si el problema persiste, contacte al administrador con su Chat ID: \`${chatId}\``,
            parse_mode: 'Markdown'
          });
        } else {
          // Vincular el chatId a todos los hijos con ese número
          const batch = admin.firestore().batch();
          const studentNames = [];
          
          studentsQuery.docs.forEach(doc => {
            const student = doc.data();
            studentNames.push(`${student.firstName} ${student.lastName}`);
            batch.update(doc.ref, {
              parentTelegramChatId: chatId.toString(),
              parentTelegramLinkedAt: admin.firestore.FieldValue.serverTimestamp()
            });
          });
          
          await batch.commit();
          
          const studentList = studentNames.map((name, i) => `${i + 1}. ${name}`).join('\n');
          
          await axios.post(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
            chat_id: chatId,
            text: `✅ *¡Vinculación exitosa!*

Su cuenta de Telegram ha sido vinculada con:

${studentList}

A partir de ahora recibirá notificaciones automáticas cuando sus hijo(a)s registren asistencia.

¡Gracias! 📚`,
            parse_mode: 'Markdown',
            reply_markup: {
              remove_keyboard: true
            }
          });
          
          console.log(`✅ Vinculación exitosa para ${phoneNumber} con ${studentNames.length} estudiante(s)`);
        }
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
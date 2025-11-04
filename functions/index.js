/**
 * Sistema de Asistencias - Backend con Firebase Functions
 * Implementa autenticación segura y arquitectura limpia
 * Aplicando buenas prácticas 2025
 */

const { setGlobalOptions } = require("firebase-functions/v2");

// Configuración global para control de costos
setGlobalOptions({ maxInstances: 10 });

// Importar las funciones compiladas desde el directorio lib
const { api, auth, whatsappOnAttendanceCreate } = require("./lib/index");

// Importar funciones de Telegram
const { sendTelegramNotification, handleTelegramWebhook } = require('./telegram-functions');

// Exportar las Cloud Functions
exports.api = api;
exports.auth = auth;
exports.whatsappOnAttendanceCreate = whatsappOnAttendanceCreate;
exports.sendTelegramNotification = sendTelegramNotification;
exports.handleTelegramWebhook = handleTelegramWebhook;
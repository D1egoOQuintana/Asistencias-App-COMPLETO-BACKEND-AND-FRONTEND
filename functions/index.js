/**
 * Sistema de Asistencias - Backend con Firebase Functions
 * Implementa autenticación segura y arquitectura limpia
 * Aplicando buenas prácticas 2025
 */

// Importar las funciones compiladas desde el directorio lib (TypeScript)
let tsModules;
try {
  tsModules = require("./lib/index");
  exports.api = tsModules.api;
  exports.auth = tsModules.auth;
  exports.whatsappOnAttendanceCreate = tsModules.whatsappOnAttendanceCreate;
  
  // ✅ USAR FUNCIONES DE TELEGRAM DEL ARCHIVO telegram.ts (compilado)
  exports.sendTelegramNotification = tsModules.sendTelegramNotification;
  exports.sendTelegramNotificationLegacy = tsModules.sendTelegramNotificationLegacy;
  exports.sendTelegramNotificationClassroomScoped = tsModules.sendTelegramNotificationClassroomScoped;
  exports.sendTelegramAttendanceEventNotification = tsModules.sendTelegramAttendanceEventNotification;
  exports.syncClassroomAttendanceToRoot = tsModules.syncClassroomAttendanceToRoot;
  exports.handleTelegramWebhook = tsModules.handleTelegramWebhook;
  exports.createTelegramActivationLink = tsModules.createTelegramActivationLink;
  exports.notifyClassroomAbsences = tsModules.notifyClassroomAbsences;
  exports.notifyAbsencesScheduled = tsModules.notifyAbsencesScheduled;

  console.log('✅ Funciones de Telegram cargadas desde telegram.ts');
} catch (error) {
  console.error('Error cargando módulos TypeScript:', error);
}

// Importar funciones de IA para reportes (JavaScript)
try {
  const aiReports = require('./ai-reports');
  exports.generateReportWithAI = aiReports.generateReportWithAI;
  exports.getAIReportsHistory = aiReports.getAIReportsHistory;
} catch (error) {
  console.error('Error cargando funciones de IA:', error);
}

// Importar API profesional de reportes (JavaScript)
try {
  const reportsApi = require('./reports-api');
  exports.getAttendanceReportData = reportsApi.getAttendanceReportData;
  exports.getConsolidatedReport = reportsApi.getConsolidatedReport;
  exports.exportReportData = reportsApi.exportReportData;
  exports.getAttendanceTrends = reportsApi.getAttendanceTrends;
} catch (error) {
  console.error('Error cargando API de reportes:', error);
}
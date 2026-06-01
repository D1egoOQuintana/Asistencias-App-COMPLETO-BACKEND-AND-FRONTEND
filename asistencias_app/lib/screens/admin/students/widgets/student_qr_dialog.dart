import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../models/student_model.dart';
import '../../../../services/student_service.dart';
import '../../../../theme/app_design_system.dart';

const _kBorder = Color(0xFFE6EAF0);
const _kCanvas = Color(0xFFF4F6FA);

// TODO(telegram-linked): StudentModel has no 'telegramChatId' or 'telegramLinked' field.
// Until that field is added to Firestore, Telegram status is always shown as "No verificado".
// When the institution adds Telegram verification: check 'telegramChatId != null' in the
// student document and surface it here as a "Verificado" badge.

/// Diálogo que muestra el QR del estudiante y permite:
/// - Ver el código QR (qr_flutter)
/// - Copiar el valor del qrCode al portapapeles
/// - Generar enlace de activación de Telegram (Cloud Function: createTelegramActivationLink)
/// - Copiar el enlace Telegram generado
/// - Abrir WhatsApp con el mensaje de activación (url_launcher)
///
/// No modifica el formato QR existente. No crea Cloud Functions nuevas.
class StudentQrDialog extends StatefulWidget {
  final StudentModel student;

  const StudentQrDialog({super.key, required this.student});

  @override
  State<StudentQrDialog> createState() => _StudentQrDialogState();
}

class _StudentQrDialogState extends State<StudentQrDialog> {
  bool _loadingTelegram = false;
  Map<String, dynamic>? _telegramData;
  String? _telegramError;

  Future<void> _generateTelegramLink() async {
    if (widget.student.id == null) return;
    setState(() {
      _loadingTelegram = true;
      _telegramData = null;
      _telegramError = null;
    });

    final result = await StudentService.generateTelegramActivationLink(
      studentId: widget.student.id!,
    );

    if (!mounted) return;
    setState(() {
      _loadingTelegram = false;
      if (result['success'] == true) {
        _telegramData = result;
      } else {
        _telegramError = result['message'] ?? 'Error al generar enlace';
      }
    });
  }

  Future<void> _openWhatsApp(String startLink) async {
    final phone = widget.student.parentPhone;
    if (phone == null || phone.isEmpty) return;

    // Strip non-digits for wa.me (removes +51 prefix but keeps number)
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    final whatsappNumber = digitsOnly.startsWith('51')
        ? digitsOnly
        : '51$digitsOnly';

    final message = _telegramData?['whatsappMessage'] as String? ??
        'Enlace de activación Telegram para ${widget.student.fullName}: $startLink';

    final uri = Uri.parse(
        'https://wa.me/$whatsappNumber?text=${Uri.encodeComponent(message)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo abrir WhatsApp'),
          backgroundColor: AppDesignSystem.errorColor,
        ));
      }
    }
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$label copiado al portapapeles'),
        backgroundColor: AppDesignSystem.successColor,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  /// Contenido REAL que se codifica en la imagen QR.
  ///
  /// Debe ser el MISMO formato JSON que genera la app docente
  /// (`teacher_students_screen.dart`), porque el escáner
  /// (`qr_attendance_realtime.dart`) resuelve el perfil del estudiante por el
  /// campo `id` = doc ID de Firestore. Si se codificara solo `s.qrCode`
  /// (string plano `STU-...`), el escáner no encontraría al estudiante y la
  /// asistencia quedaría como "Estudiante" genérico sin enviar Telegram.
  String _qrPayload(StudentModel s) {
    return jsonEncode({
      'type': 'student',
      'id': s.id,
      'name': s.fullName,
      'dni': s.dni,
      'classroomId': s.classroomId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final hasQr = s.qrCode.isNotEmpty;
    final hasPhone =
        s.parentPhone != null && s.parentPhone!.isNotEmpty;
    final startLink = _telegramData?['startLink'] as String?;

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: AppDesignSystem.borderRadiusLG),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00695C).withValues(alpha: 0.1),
                      borderRadius: AppDesignSystem.borderRadiusMD,
                    ),
                    child: const Icon(Icons.qr_code_rounded,
                        size: 20, color: Color(0xFF00695C)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'QR y activación Telegram',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.textPrimary,
                          ),
                        ),
                        Text(
                          s.fullName,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppDesignSystem.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                    color: AppDesignSystem.textSecondary,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Divider(color: _kBorder, height: 1),
            ),

            // QR section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasQr) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppDesignSystem.borderRadiusMD,
                          border: Border.all(color: _kBorder),
                        ),
                        child: QrImageView(
                          // Codifica el JSON (mismo formato que la app docente),
                          // NO el string plano s.qrCode. Así el escáner resuelve
                          // el estudiante real y envía Telegram.
                          data: _qrPayload(s),
                          version: QrVersions.auto,
                          size: 180,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF0D1B2A),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF0D1B2A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // QR code value
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _kCanvas,
                        borderRadius: AppDesignSystem.borderRadiusSM,
                        border: Border.all(color: _kBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.qrCode,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                                color: AppDesignSystem.textSecondary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            tooltip: 'Copiar código QR',
                            onPressed: () =>
                                _copyToClipboard(s.qrCode, 'Código QR'),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: AppDesignSystem.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.warningColor.withValues(alpha: 0.06),
                        borderRadius: AppDesignSystem.borderRadiusMD,
                        border: Border.all(
                            color: AppDesignSystem.warningColor
                                .withValues(alpha: 0.3)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 18, color: AppDesignSystem.warningColor),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Este estudiante no tiene código QR generado. '
                            'Esto puede ocurrir con datos migrados. '
                            'Edita y guarda el estudiante para regenerarlo.',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppDesignSystem.textSecondary),
                          ),
                        ),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Divider(color: _kBorder, height: 1),
                  const SizedBox(height: 16),

                  // Telegram section
                  const Row(
                    children: [
                      Icon(Icons.send_rounded,
                          size: 16, color: Color(0xFF0088CC)),
                      SizedBox(width: 8),
                      Text(
                        'Activación Telegram',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppDesignSystem.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Telegram status — always "No verificado" since StudentModel
                  // has no telegramChatId / telegramLinked field.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.textSecondary
                          .withValues(alpha: 0.08),
                      borderRadius: AppDesignSystem.borderRadiusFull,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.help_outline_rounded,
                            size: 12,
                            color: AppDesignSystem.textSecondary),
                        SizedBox(width: 4),
                        Text(
                          'Telegram: No verificado',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppDesignSystem.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Error message
                  if (_telegramError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _telegramError!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppDesignSystem.errorColor),
                      ),
                    ),

                  // Generated link
                  if (startLink != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0088CC).withValues(alpha: 0.06),
                        borderRadius: AppDesignSystem.borderRadiusSM,
                        border: Border.all(
                            color: const Color(0xFF0088CC)
                                .withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Enlace de activación:',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppDesignSystem.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            startLink,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0088CC),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _copyToClipboard(startLink, 'Enlace Telegram'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0088CC),
                              side: const BorderSide(
                                  color: Color(0xFF0088CC),
                                  width: 1),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      AppDesignSystem.borderRadiusMD),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 15),
                            label: const Text('Copiar enlace',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        if (hasPhone) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _openWhatsApp(startLink),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        AppDesignSystem.borderRadiusMD),
                              ),
                              icon: const Icon(Icons.open_in_new_rounded,
                                  size: 15),
                              label: const Text('WhatsApp',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Generate button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (widget.student.id == null || _loadingTelegram)
                          ? null
                          : _generateTelegramLink,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0088CC),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppDesignSystem.borderRadiusMD),
                      ),
                      icon: _loadingTelegram
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(
                        startLink != null
                            ? 'Regenerar enlace Telegram'
                            : 'Generar enlace Telegram',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),

                  if (!hasPhone) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Sin teléfono registrado — agrega el teléfono del apoderado para abrir WhatsApp directamente.',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: AppDesignSystem.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

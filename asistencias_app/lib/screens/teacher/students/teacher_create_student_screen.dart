import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/classroom_model.dart';
import '../../../services/student_service.dart';

class TeacherCreateStudentScreen extends StatefulWidget {
  final ClassroomModel classroom;

  const TeacherCreateStudentScreen({super.key, required this.classroom});

  @override
  State<TeacherCreateStudentScreen> createState() =>
      _TeacherCreateStudentScreenState();
}

class _TeacherCreateStudentScreenState
    extends State<TeacherCreateStudentScreen> {
  static const Color _celeste = Color(0xFF1976D2);
  static const Color _celesteSoft = Color(0xFFD8E8FF);
  static const Color _celesteDark = Color(0xFF1976D2);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _dniCtrl.dispose();
    _parentPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final res = await StudentService.createStudent(
      firstName: _nameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      dni: _dniCtrl.text.trim(),
      classroomId: widget.classroom.id!,
      parentEmail: null,
      parentPhone: _parentPhoneCtrl.text.trim().isEmpty
          ? null
          : _parentPhoneCtrl.text.trim(),
    );

    if (!mounted) return;

    if (res['success'] == true) {
      final studentId = (res['studentId'] ?? '').toString();
      final studentName =
          '${_nameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();
      final parentPhone = _parentPhoneCtrl.text.trim();

      Map<String, dynamic>? activationData;
      String? activationError;

      if (studentId.isNotEmpty) {
        final activationRes =
            await StudentService.generateTelegramActivationLink(
              studentId: studentId,
            );

        if (activationRes['success'] == true) {
          activationData = activationRes;
        } else {
          activationError = (activationRes['message'] ?? '').toString();
        }
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      await _showActivationDeliveryDialog(
        studentName: studentName,
        parentPhone: parentPhone,
        activationData: activationData,
        activationError: activationError,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }

    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message'] ?? 'No se pudo crear el estudiante'),
        backgroundColor: const Color(0xFFBA1A1A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _phoneForWhatsapp(String rawPhone) {
    var digits = rawPhone.replaceAll(RegExp(r'\D+'), '');
    if (digits.length == 9 && !digits.startsWith('51')) {
      digits = '51$digits';
    }
    return digits;
  }

  Future<void> _openWhatsapp(
    BuildContext context, {
    required String phone,
    required String message,
  }) async {
    final waPhone = _phoneForWhatsapp(phone);
    if (waPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay teléfono válido para enviar por WhatsApp'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uri = Uri.parse(
      'https://wa.me/$waPhone?text=${Uri.encodeComponent(message)}',
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir WhatsApp en este dispositivo'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showActivationDeliveryDialog({
    required String studentName,
    required String parentPhone,
    required Map<String, dynamic>? activationData,
    required String? activationError,
  }) async {
    final startLink = (activationData?['startLink'] ?? '').toString().trim();
    final whatsappMessage =
        (activationData?['whatsappMessage'] ?? '').toString().trim();

    final fallbackMessage =
        'Hola, su link de activacion para: $studentName\n$startLink\nCon este enlace se vincula al bot sin escribir nada.';

    final messageToSend = whatsappMessage.isNotEmpty
        ? whatsappMessage
        : fallbackMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alumno creado',
                  style: GoogleFonts.manrope(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF000D33),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  studentName,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _celesteDark,
                  ),
                ),
                const SizedBox(height: 14),
                if (activationError != null && activationError.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No se pudo generar el enlace automático: $activationError',
                      style: GoogleFonts.workSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF8A1C1C),
                      ),
                    ),
                  ),
                if (activationError != null && activationError.isNotEmpty)
                  const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _celesteSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Link de activación Telegram',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _celesteDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        startLink.isEmpty ? 'No disponible' : startLink,
                        style: GoogleFonts.workSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF123054),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  parentPhone.isEmpty
                      ? 'No se registró teléfono para WhatsApp.'
                      : 'Se enviará al teléfono: $parentPhone',
                  style: GoogleFonts.workSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF556474),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: parentPhone.isEmpty || startLink.isEmpty
                        ? null
                        : () async {
                            await _openWhatsapp(
                              context,
                              phone: parentPhone,
                              message: messageToSend,
                            );
                          },
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('Enviar por WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: startLink.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: startLink),
                                );
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Link copiado'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('Copiar link'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: startLink.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: messageToSend),
                                );
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Mensaje copiado'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copiar mensaje'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Finalizar',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF000D33),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.manrope(
      fontSize: 42,
      fontWeight: FontWeight.w500,
      color: const Color(0xFF000D33),
      height: 1.05,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _celeste.withValues(alpha: 0.35),
                    _celeste.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Container(
                  height: 76,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F5).withValues(alpha: 0.78),
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFE1E3E4)),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Nuevo Estudiante',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w500,
                            fontSize: 23,
                            color: const Color(0xFF000D33),
                          ),
                        ),
                      ),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _celesteSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.person_add_alt_1,
                          color: _celesteDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              style: titleStyle,
                              children: [
                                const TextSpan(text: 'Alta de\n'),
                                TextSpan(
                                  text: 'Alumno',
                                  style: titleStyle.copyWith(
                                    color: _celesteDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Complete la información para integrar al estudiante al sistema de asistencia.',
                            style: GoogleFonts.workSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF444650),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _celesteSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${widget.classroom.grade} ${widget.classroom.section} - ${widget.classroom.name}',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _celesteDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          _buildField(
                            label: 'Nombre del Estudiante',
                            controller: _nameCtrl,
                            hint: 'Ej. Juan Carlos',
                            icon: Icons.badge_outlined,
                            requiredField: true,
                            textCapitalization: TextCapitalization.words,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'El nombre es requerido';
                              }
                              if (value.trim().length < 2) {
                                return 'Nombre muy corto';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            label: 'Apellido',
                            controller: _lastNameCtrl,
                            hint: 'Ej. Rodríguez',
                            icon: Icons.person_outline,
                            requiredField: true,
                            textCapitalization: TextCapitalization.words,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'El apellido es requerido';
                              }
                              if (value.trim().length < 2) {
                                return 'Apellido muy corto';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildField(
                                  label: 'DNI / ID',
                                  controller: _dniCtrl,
                                  hint: 'Opcional',
                                  icon: Icons.fingerprint,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (value) {
                                    if (value != null &&
                                        value.trim().isNotEmpty &&
                                        value.trim().length < 7) {
                                      return 'Mínimo 7 dígitos';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildField(
                                  label: 'Teléfono',
                                  controller: _parentPhoneCtrl,
                                  hint: '+54 9 ... (opcional)',
                                  icon: Icons.call_outlined,
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _celesteSoft,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.qr_code_2_rounded,
                                  color: _celesteDark,
                                  size: 30,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Al crear el perfil, el sistema generará automáticamente un QR único del estudiante.',
                                    style: GoogleFonts.workSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _celesteDark,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 62,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _celesteDark,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 0,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Crear Estudiante',
                                          style: GoogleFonts.manrope(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          size: 24,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool requiredField = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text(
            requiredField ? '$label *' : label,
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF000D33),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          textCapitalization: textCapitalization,
          style: GoogleFonts.workSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF000D33),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.workSans(
              color: const Color(0xFF757681),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF757681)),
            filled: true,
            fillColor: const Color(0xFFE6E8E9),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _celesteDark, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }
}

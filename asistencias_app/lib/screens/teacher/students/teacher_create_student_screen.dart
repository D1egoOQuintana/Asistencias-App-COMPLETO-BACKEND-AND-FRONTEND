import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.manrope(
      fontSize: 42,
      fontWeight: FontWeight.w800,
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
                    const Color(0xFFADC7FF).withValues(alpha: 0.45),
                    const Color(0xFFADC7FF).withValues(alpha: 0.05),
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
                          color: Color(0xFF002060),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Nuevo Estudiante',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            fontSize: 23,
                            color: const Color(0xFF000D33),
                          ),
                        ),
                      ),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8E2FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1,
                          color: Color(0xFF2C4383),
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
                                    color: const Color(0xFF0059BB),
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
                              color: const Color(0xFFEAF1FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${widget.classroom.grade} ${widget.classroom.section} - ${widget.classroom.name}',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2C4383),
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
                              color: const Color(0xFFD8E2FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.qr_code_2_rounded,
                                  color: Color(0xFF2C4383),
                                  size: 30,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Al crear el perfil, el sistema generará automáticamente un QR único del estudiante.',
                                    style: GoogleFonts.workSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2C4383),
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
                                backgroundColor: const Color(0xFF002060),
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
                                            fontWeight: FontWeight.w800,
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
              fontWeight: FontWeight.w800,
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
            fontWeight: FontWeight.w600,
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
              borderSide: const BorderSide(
                color: Color(0xFF0059BB),
                width: 1.8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

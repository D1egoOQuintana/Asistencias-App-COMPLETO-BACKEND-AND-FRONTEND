import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/student_model.dart';
import '../../../../services/student_service.dart';
import '../../../../services/classroom_service.dart';
import '../../../../theme/app_design_system.dart';

const _kBorder = Color(0xFFE6EAF0);
const _kPrimary = Color(0xFF1976D2);

/// Diálogo para crear o editar un estudiante.
/// Usa [StudentService.createStudent] / [StudentService.updateStudent].
/// Nunca toca historial de asistencia ni el formato QR existente.
class StudentFormDialog extends StatefulWidget {
  final StudentModel? student;

  const StudentFormDialog({super.key, this.student});

  @override
  State<StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends State<StudentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _dni;
  late final TextEditingController _phone;
  late final TextEditingController _email;

  String? _selectedClassroomId;
  bool _saving = false;

  bool get _isEditing => widget.student != null;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _firstName = TextEditingController(text: s?.firstName ?? '');
    _lastName = TextEditingController(text: s?.lastName ?? '');
    _dni = TextEditingController(text: s?.dni ?? '');
    _phone = TextEditingController(text: s?.parentPhone ?? '');
    _email = TextEditingController(text: s?.parentEmail ?? '');
    _selectedClassroomId = s?.classroomId.isNotEmpty == true
        ? s!.classroomId
        : null;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _dni.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final cleaned = v.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('+51')) {
      return cleaned.length == 12 ? null : 'Teléfono peruano inválido (+51 + 9 dígitos)';
    }
    if (cleaned.length == 9) return null;
    return 'Ingresa 9 dígitos o formato +51XXXXXXXXX';
  }

  String? _validateDni(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (!RegExp(r'^\d{8}$').hasMatch(v.trim())) {
      return 'DNI debe tener exactamente 8 dígitos numéricos';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassroomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecciona un aula'),
        backgroundColor: AppDesignSystem.errorColor,
      ));
      return;
    }

    setState(() => _saving = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    bool ok;
    String message;

    if (_isEditing) {
      ok = await StudentService.updateStudent(
        studentId: widget.student!.id!,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        dni: _dni.text.trim(),
        classroomId: _selectedClassroomId!,
        parentEmail: _email.text.trim().isNotEmpty ? _email.text.trim() : null,
        parentPhone:
            _phone.text.trim().isNotEmpty ? _phone.text.trim() : null,
      );
      message = ok
          ? 'Estudiante actualizado correctamente'
          : 'No se pudo actualizar el estudiante (puede ser DNI duplicado)';
    } else {
      final result = await StudentService.createStudent(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        dni: _dni.text.trim().isNotEmpty ? _dni.text.trim() : null,
        classroomId: _selectedClassroomId!,
        parentEmail: _email.text.trim().isNotEmpty ? _email.text.trim() : null,
        parentPhone:
            _phone.text.trim().isNotEmpty ? _phone.text.trim() : null,
      );
      ok = result['success'] == true;
      message = result['message'] ?? (ok ? 'Estudiante creado' : 'Error al crear');
    }

    if (!mounted) return;
    nav.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor:
          ok ? AppDesignSystem.successColor : AppDesignSystem.errorColor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppDesignSystem.borderRadiusLG),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
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
                      color: _kPrimary.withValues(alpha: 0.1),
                      borderRadius: AppDesignSystem.borderRadiusMD,
                    ),
                    child: Icon(
                      _isEditing
                          ? Icons.edit_rounded
                          : Icons.person_add_rounded,
                      size: 20,
                      color: _kPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditing ? 'Editar estudiante' : 'Nuevo estudiante',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.textPrimary,
                      ),
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
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Divider(color: _kBorder, height: 1),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre + Apellido
                      Row(children: [
                        Expanded(
                          child: _field(
                            ctrl: _firstName,
                            label: 'Nombres *',
                            hint: 'Ej: Ana María',
                            icon: Icons.person_outline_rounded,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'El nombre es requerido'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            ctrl: _lastName,
                            label: 'Apellidos *',
                            hint: 'Ej: García López',
                            icon: Icons.person_outline_rounded,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'El apellido es requerido'
                                : null,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),

                      // DNI
                      _field(
                        ctrl: _dni,
                        label: 'DNI (opcional)',
                        hint: '8 dígitos numéricos',
                        icon: Icons.badge_outlined,
                        keyboardType: TextInputType.number,
                        formatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: _validateDni,
                      ),
                      const SizedBox(height: 14),

                      // Classroom dropdown
                      _classroomDropdown(),
                      const SizedBox(height: 14),

                      // Teléfono apoderado
                      _field(
                        ctrl: _phone,
                        label: 'Teléfono del apoderado (opcional)',
                        hint: 'Ej: 987654321 o +51987654321',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: _validatePhone,
                      ),
                      const SizedBox(height: 14),

                      // Email apoderado
                      _field(
                        ctrl: _email,
                        label: 'Email del apoderado (opcional)',
                        hint: 'Ej: apoderado@correo.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                              .hasMatch(v.trim())) {
                            return 'Email inválido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),

            // Footer actions
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                children: [
                  Divider(color: _kBorder, height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            _saving ? null : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: AppDesignSystem.textSecondary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: _kPrimary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: AppDesignSystem.borderRadiusMD),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(_isEditing ? 'Guardar cambios' : 'Crear estudiante'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── classroom dropdown ─────────────────────────────────────────────────────

  Widget _classroomDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: ClassroomService.getAllClassrooms(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 56,
            child: Center(
                child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppDesignSystem.warningColor.withValues(alpha: 0.06),
              borderRadius: AppDesignSystem.borderRadiusMD,
              border: Border.all(
                  color: AppDesignSystem.warningColor.withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.warning_amber_rounded,
                  size: 16, color: AppDesignSystem.warningColor),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No hay aulas activas. Crea una en el módulo "Aulas" primero.',
                  style: TextStyle(
                      fontSize: 12, color: AppDesignSystem.textSecondary),
                ),
              ),
            ]),
          );
        }

        // Build dropdown items
        final items = docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final grade = (d['grade'] ?? '').toString();
          final section = (d['section'] ?? '').toString();
          final name = (d['name'] ?? '').toString();
          final label = grade.isNotEmpty && section.isNotEmpty
              ? '$grade° $section${name.isNotEmpty ? ' – $name' : ''}'
              : name.isNotEmpty
                  ? name
                  : doc.id;
          return DropdownMenuItem<String>(
            value: doc.id,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          );
        }).toList();

        // If editing: make sure current classroomId exists in docs.
        final validIds = docs.map((d) => d.id).toSet();
        if (_selectedClassroomId != null &&
            !validIds.contains(_selectedClassroomId)) {
          _selectedClassroomId = null;
        }

        return DropdownButtonFormField<String>(
          initialValue: _selectedClassroomId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Aula *',
            prefixIcon: const Icon(Icons.class_rounded, size: 18),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: AppDesignSystem.borderRadiusMD,
                borderSide: const BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: AppDesignSystem.borderRadiusMD,
                borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: AppDesignSystem.borderRadiusMD,
                borderSide: const BorderSide(color: _kPrimary, width: 2)),
          ),
          hint: const Text('Selecciona un aula',
              style: TextStyle(fontSize: 13)),
          items: items,
          onChanged: (v) => setState(() {
            _selectedClassroomId = v;
          }),
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Selecciona un aula' : null,
        );
      },
    );
  }

  // ─── text field helper ──────────────────────────────────────────────────────

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: AppDesignSystem.borderRadiusMD,
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: AppDesignSystem.borderRadiusMD,
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: AppDesignSystem.borderRadiusMD,
            borderSide: const BorderSide(color: _kPrimary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: AppDesignSystem.borderRadiusMD,
            borderSide:
                const BorderSide(color: AppDesignSystem.errorColor)),
      ),
    );
  }
}

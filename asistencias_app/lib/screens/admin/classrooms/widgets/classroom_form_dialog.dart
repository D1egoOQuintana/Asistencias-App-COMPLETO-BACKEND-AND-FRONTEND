import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../models/classroom_model.dart';
import '../../../../services/classroom_service.dart';
import '../../../../theme/app_design_system.dart';
import '../../widgets/admin_ui.dart';

const _kBorder = Color(0xFFE6EAF0);

/// Diálogo para crear o editar un aula.
/// Pasa [classroom] == null para crear, o una instancia para editar.
class ClassroomFormDialog extends StatefulWidget {
  final ClassroomModel? classroom;

  const ClassroomFormDialog({super.key, this.classroom});

  @override
  State<ClassroomFormDialog> createState() => _ClassroomFormDialogState();
}

class _ClassroomFormDialogState extends State<ClassroomFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _grade;
  late final TextEditingController _section;
  late final TextEditingController _capacity;

  bool _isLoading = false;
  bool get _isEditing => widget.classroom != null;

  static const _grades = ['1', '2', '3', '4', '5', '6'];
  static const _sections = ['A', 'B', 'C', 'D', 'E'];

  @override
  void initState() {
    super.initState();
    final c = widget.classroom;
    _name = TextEditingController(text: c?.name ?? '');
    _grade = TextEditingController(text: c?.grade ?? '');
    _section = TextEditingController(text: c?.section ?? '');
    _capacity = TextEditingController(
      text: c != null ? c.capacity.toString() : '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _grade.dispose();
    _section.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final name = _name.text.trim();
    final grade = _grade.text.trim();
    final section = _section.text.trim().toUpperCase();
    final capacity = int.parse(_capacity.text.trim());

    try {
      bool ok;
      String message;

      if (_isEditing) {
        ok = await ClassroomService.updateClassroom(
          classroomId: widget.classroom!.id!,
          name: name,
          grade: grade,
          section: section,
          capacity: capacity,
          description: widget.classroom!.description,
          teacherUid: widget.classroom!.teacherUid,
          teacherName: widget.classroom!.teacherName,
        );
        message = ok ? 'Aula actualizada correctamente' : 'Error al actualizar el aula';
      } else {
        final result = await ClassroomService.createClassroom(
          name: name,
          grade: grade,
          section: section,
          capacity: capacity,
          description: 'Aula creada por administrador',
        );
        ok = result['success'] == true;
        message = result['message'] ?? (ok ? 'Aula creada correctamente' : 'Error al crear el aula');
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        AdminFeedback.snack(
          ok ? AdminFeedbackType.success : AdminFeedbackType.error,
          message,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AdminFeedback.snack(AdminFeedbackType.error, 'Error: $e'),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Editar aula' : 'Nueva aula';
    final btnLabel = _isEditing ? 'Guardar cambios' : 'Crear aula';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppDesignSystem.borderRadiusLG),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppDesignSystem.primaryColor.withValues(alpha: 0.1),
                        borderRadius: AppDesignSystem.borderRadiusMD,
                      ),
                      child: const Icon(Icons.class_rounded,
                          size: 20, color: AppDesignSystem.primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.textPrimary,
                          letterSpacing: -0.2,
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
                const SizedBox(height: 6),
                const Text(
                  'Los campos marcados con * son obligatorios.',
                  style: TextStyle(fontSize: 12, color: AppDesignSystem.textSecondary),
                ),
                const SizedBox(height: 20),
                Divider(color: _kBorder, height: 1),
                const SizedBox(height: 20),

                // Nombre
                _field(
                  label: 'Nombre del aula *',
                  controller: _name,
                  hint: 'Ej: Matemáticas, Comunicación…',
                  icon: Icons.drive_file_rename_outline_rounded,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
                ),
                const SizedBox(height: 16),

                // Grado + Sección
                Row(
                  children: [
                    Expanded(
                      child: _dropdownField(
                        label: 'Grado *',
                        controller: _grade,
                        items: _grades,
                        hint: 'Ej: 1, 2, 3…',
                        icon: Icons.school_outlined,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dropdownField(
                        label: 'Sección *',
                        controller: _section,
                        items: _sections,
                        hint: 'Ej: A, B, C…',
                        icon: Icons.tag_rounded,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Capacidad
                _field(
                  label: 'Capacidad máxima *',
                  controller: _capacity,
                  hint: 'Número de estudiantes (1–60)',
                  icon: Icons.groups_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0 || n > 60) {
                      return 'Ingresa un número entre 1 y 60';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Note on teacher/schedule
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.primaryColor.withValues(alpha: 0.05),
                    borderRadius: AppDesignSystem.borderRadiusMD,
                    border: Border.all(color: AppDesignSystem.primaryColor.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: AppDesignSystem.primaryColor),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'La asignación de docente y el horario se configuran por separado desde la tabla.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppDesignSystem.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AdminButton.ghost(
                      label: 'Cancelar',
                      onPressed:
                          _isLoading ? null : () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    AdminButton.primary(
                      label: btnLabel,
                      icon: Icons.check_rounded,
                      loading: _isLoading,
                      onPressed: _isLoading ? null : _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: AdminInputs.decoration(
        label: label,
        hint: hint,
        prefixIcon: icon,
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required TextEditingController controller,
    required List<String> items,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(controller.text) ? controller.text : null,
      isExpanded: true,
      validator: validator,
      decoration: AdminInputs.decoration(
        label: label,
        prefixIcon: icon,
      ),
      hint: Text(hint, style: const TextStyle(fontSize: 13)),
      items: items
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: (v) {
        if (v != null) controller.text = v;
      },
    );
  }
}

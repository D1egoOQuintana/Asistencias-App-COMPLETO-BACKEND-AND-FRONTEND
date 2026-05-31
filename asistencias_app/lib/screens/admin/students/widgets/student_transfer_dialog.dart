import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/student_model.dart';
import '../../../../services/student_service.dart';
import '../../../../services/classroom_service.dart';
import '../../../../theme/app_design_system.dart';

const _kBorder = Color(0xFFE6EAF0);
const _kPrimary = Color(0xFF1976D2);

/// Diálogo de transferencia de estudiante entre aulas.
/// Usa [StudentService.transferStudent] que solo actualiza classroomId + updatedAt.
/// El historial de asistencia (attendance subcollection en el aula anterior) NO se modifica.
class StudentTransferDialog extends StatefulWidget {
  final StudentModel student;

  const StudentTransferDialog({super.key, required this.student});

  @override
  State<StudentTransferDialog> createState() => _StudentTransferDialogState();
}

class _StudentTransferDialogState extends State<StudentTransferDialog> {
  String? _targetClassroomId;
  bool _saving = false;

  Future<void> _transfer() async {
    if (_targetClassroomId == null) return;
    setState(() => _saving = true);

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await StudentService.transferStudent(
      studentId: widget.student.id!,
      newClassroomId: _targetClassroomId!,
    );

    if (!mounted) return;
    nav.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Estudiante transferido correctamente'
          : 'No se pudo transferir el estudiante'),
      backgroundColor:
          ok ? AppDesignSystem.successColor : AppDesignSystem.errorColor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: AppDesignSystem.borderRadiusLG),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                      color: AppDesignSystem.warningColor.withValues(alpha: 0.1),
                      borderRadius: AppDesignSystem.borderRadiusMD,
                    ),
                    child: const Icon(Icons.swap_horiz_rounded,
                        size: 20, color: AppDesignSystem.warningColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transferir estudiante',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.textPrimary,
                          ),
                        ),
                        Text(
                          widget.student.fullName,
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
              const SizedBox(height: 16),
              Divider(color: _kBorder, height: 1),
              const SizedBox(height: 16),

              // Warning notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppDesignSystem.warningColor.withValues(alpha: 0.06),
                  borderRadius: AppDesignSystem.borderRadiusMD,
                  border: Border.all(
                      color: AppDesignSystem.warningColor
                          .withValues(alpha: 0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: AppDesignSystem.warningColor),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'El historial de asistencia del estudiante en el aula anterior se mantiene intacto. '
                        'Solo se actualiza el aula actual del estudiante.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppDesignSystem.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Classroom selector
              StreamBuilder<QuerySnapshot>(
                stream: ClassroomService.getAllClassrooms(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2));
                  }

                  final docs = snap.data?.docs ?? [];
                  // Exclude the current classroom
                  final available = docs.where(
                      (d) => d.id != widget.student.classroomId).toList();

                  if (available.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6FA),
                        borderRadius: AppDesignSystem.borderRadiusMD,
                        border: Border.all(color: _kBorder),
                      ),
                      child: const Text(
                        'No hay otras aulas disponibles para transferir.',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppDesignSystem.textSecondary),
                      ),
                    );
                  }

                  final items = available.map((doc) {
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

                  return DropdownButtonFormField<String>(
                    initialValue: _targetClassroomId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Aula destino',
                      prefixIcon: const Icon(Icons.class_rounded, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                          borderRadius: AppDesignSystem.borderRadiusMD,
                          borderSide: const BorderSide(color: _kBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: AppDesignSystem.borderRadiusMD,
                          borderSide: const BorderSide(color: _kBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: AppDesignSystem.borderRadiusMD,
                          borderSide:
                              const BorderSide(color: _kPrimary, width: 2)),
                    ),
                    hint: const Text('Selecciona el aula destino',
                        style: TextStyle(fontSize: 13)),
                    items: items,
                    onChanged: (v) => setState(() => _targetClassroomId = v),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                        foregroundColor: AppDesignSystem.textSecondary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12)),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed:
                        (_saving || _targetClassroomId == null) ? null : _transfer,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppDesignSystem.warningColor,
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
                        : const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Transferir'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

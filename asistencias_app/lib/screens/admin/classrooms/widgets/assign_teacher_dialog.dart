import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/classroom_model.dart';
import '../../../../services/classroom_service.dart';
import '../../../../services/teacher_service.dart';
import '../../../../theme/app_design_system.dart';

const _kBorder = Color(0xFFE6EAF0);
const _kCanvas = Color(0xFFF4F6FA);

/// Diálogo para asignar o reasignar un docente a un aula.
class AssignTeacherDialog extends StatefulWidget {
  final ClassroomModel classroom;

  const AssignTeacherDialog({super.key, required this.classroom});

  @override
  State<AssignTeacherDialog> createState() => _AssignTeacherDialogState();
}

class _AssignTeacherDialogState extends State<AssignTeacherDialog> {
  String? _selectedUid;
  String? _selectedName;
  bool _isLoading = false;

  late final Stream<QuerySnapshot> _teachersStream;

  @override
  void initState() {
    super.initState();
    _teachersStream = TeacherService.getTeachersStream();
    _selectedUid = widget.classroom.teacherUid;
    _selectedName = widget.classroom.teacherName;
  }

  Future<void> _assign() async {
    if (_selectedUid == null) return;
    setState(() => _isLoading = true);
    try {
      final ok = await ClassroomService.assignTeacherToClassroom(
        classroomId: widget.classroom.id!,
        teacherUid: _selectedUid!,
        teacherName: _selectedName ?? '',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Docente asignado correctamente'
              : 'No se pudo asignar el docente'),
          backgroundColor:
              ok ? AppDesignSystem.successColor : AppDesignSystem.errorColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppDesignSystem.errorColor),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _displayName(Map<String, dynamic> data) {
    final fn = (data['firstName'] ?? '').toString().trim();
    final ln = (data['lastName'] ?? '').toString().trim();
    final full = (data['fullName'] ?? '').toString().trim();
    final email = (data['email'] ?? '').toString().trim();
    final composed = '$fn $ln'.trim();
    if (composed.isNotEmpty) return composed;
    if (full.isNotEmpty) return full;
    return email;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppDesignSystem.borderRadiusLG),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28),
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
                      color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                      borderRadius: AppDesignSystem.borderRadiusMD,
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded,
                        size: 20, color: Color(0xFF1565C0)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Asignar docente',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.textPrimary,
                          ),
                        ),
                        Text(
                          widget.classroom.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppDesignSystem.textSecondary,
                          ),
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

              // Teacher list
              StreamBuilder<QuerySnapshot>(
                stream: _teachersStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return _noTeachersNotice();
                  }

                  final docs = snap.data!.docs;
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: _kBorder),
                      itemBuilder: (ctx, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        final uid = (data['uid'] as String?) ?? docs[i].id;
                        final name = _displayName(data);
                        final email = (data['email'] ?? '').toString();
                        final isSelected = _selectedUid == uid;

                        return InkWell(
                          borderRadius: AppDesignSystem.borderRadiusMD,
                          onTap: () => setState(() {
                            _selectedUid = uid;
                            _selectedName = name;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppDesignSystem.primaryColor
                                      .withValues(alpha: 0.06)
                                  : Colors.transparent,
                              borderRadius: AppDesignSystem.borderRadiusMD,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isSelected
                                      ? AppDesignSystem.primaryColor
                                      : _kCanvas,
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: isSelected
                                          ? Colors.white
                                          : AppDesignSystem.primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          color: AppDesignSystem.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        email,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppDesignSystem.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle_rounded,
                                      size: 20,
                                      color: AppDesignSystem.primaryColor),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                        foregroundColor: AppDesignSystem.textSecondary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12)),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed:
                        (_isLoading || _selectedUid == null) ? null : _assign,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppDesignSystem.primaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: AppDesignSystem.borderRadiusMD),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Asignar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noTeachersNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesignSystem.warningColor.withValues(alpha: 0.06),
        borderRadius: AppDesignSystem.borderRadiusMD,
        border: Border.all(color: AppDesignSystem.warningColor.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 20, color: AppDesignSystem.warningColor),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No hay docentes activos disponibles.\nCrea docentes en el módulo "Docentes" primero.',
              style: TextStyle(
                  fontSize: 13, color: AppDesignSystem.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

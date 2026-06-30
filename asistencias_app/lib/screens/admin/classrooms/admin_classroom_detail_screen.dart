import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../models/classroom_model.dart';
import '../../../theme/app_design_system.dart';
import '../widgets/admin_ui.dart';
import 'widgets/classroom_form_dialog.dart';

/// Pantalla de detalle de un aula (vista admin).
///
/// Entregable 1: header + KPIs + Información del aula + Equipo docente.
/// Estudiantes y asistencia reciente quedan como secciones "Próximamente"
/// para iteración posterior.
class AdminClassroomDetailScreen extends StatefulWidget {
  final String classroomId;

  const AdminClassroomDetailScreen({super.key, required this.classroomId});

  @override
  State<AdminClassroomDetailScreen> createState() =>
      _AdminClassroomDetailScreenState();
}

class _AdminClassroomDetailScreenState
    extends State<AdminClassroomDetailScreen> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _classroomStream;

  @override
  void initState() {
    super.initState();
    _classroomStream = FirebaseFirestore.instance
        .collection('classrooms')
        .doc(widget.classroomId)
        .snapshots();
  }

  Future<void> _openEdit(ClassroomModel c) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ClassroomFormDialog(classroom: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    return DefaultTextStyle.merge(
      style: AdminUi.fontBase,
      child: Scaffold(
        backgroundColor: AdminUi.surface0,
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _classroomStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorState(message: '${snap.error}');
            }
            final data = snap.data;
            if (data == null || !data.exists) {
              return const _NotFoundState();
            }
            final classroom = ClassroomModel.fromFirestore(data);
            return _DetailContent(
              classroom: classroom,
              isWide: isWide,
              onEdit: () => _openEdit(classroom),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTENT
// ─────────────────────────────────────────────────────────────────────────────

class _DetailContent extends StatelessWidget {
  final ClassroomModel classroom;
  final bool isWide;
  final VoidCallback onEdit;

  const _DetailContent({
    required this.classroom,
    required this.isWide,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final pad = AdminUi.pagePadding(MediaQuery.of(context).size.width);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 16),
      child: Center(
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(classroom: classroom, onEdit: onEdit),
            const SizedBox(height: 20),
            _KpiRow(classroom: classroom),
            const SizedBox(height: 20),
            // Información + Equipo, lado a lado en desktop, apilados en mobile.
            isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _InfoCard(classroom: classroom)),
                      const SizedBox(width: 16),
                      Expanded(flex: 4, child: _TeamCard(classroom: classroom)),
                    ],
                  )
                : Column(
                    children: [
                      _InfoCard(classroom: classroom),
                      const SizedBox(height: 16),
                      _TeamCard(classroom: classroom),
                    ],
                  ),
            const SizedBox(height: 20),
            const _ComingSoonCard(
              icon: Icons.schedule_rounded,
              title: 'Horario semanal',
              description:
                  'La vista detallada del horario llegará en la próxima iteración.',
            ),
            const SizedBox(height: 16),
            const _ComingSoonCard(
              icon: Icons.groups_2_outlined,
              title: 'Estudiantes',
              description: 'Listado de estudiantes inscritos en este aula.',
            ),
            const SizedBox(height: 16),
            const _ComingSoonCard(
              icon: Icons.fact_check_outlined,
              title: 'Asistencia reciente',
              description:
                  'Resumen de presentes, tardanzas y ausencias por día.',
            ),
          ],
        ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final ClassroomModel classroom;
  final VoidCallback onEdit;

  const _Header({required this.classroom, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final gradeSec = classroom.grade.isNotEmpty
        ? '${classroom.grade}° ${classroom.section}'
        : classroom.name;
    final hasAux = classroom.effectiveTeacherUids.length > 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminUi.cardDecoration(elevated: false),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button (web/desktop) — en mobile el AppBar nativo lo cubriría,
          // pero como esta pantalla es contenido puro, lo dejamos siempre.
          IconButton(
            tooltip: 'Volver',
            onPressed: () => Get.back<void>(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppDesignSystem.textPrimary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 8),
          // Avatar grande del aula.
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppDesignSystem.primaryColor.withValues(alpha: 0.10),
              borderRadius: AppDesignSystem.borderRadiusMD,
            ),
            alignment: Alignment.center,
            child: Text(
              classroom.grade.isNotEmpty
                  ? classroom.grade
                  : classroom.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AppDesignSystem.primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$gradeSec · ${classroom.name}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MetaLine(
                      icon: Icons.person_rounded,
                      label: classroom.teacherName?.isNotEmpty == true
                          ? 'Tutor: ${classroom.teacherName}'
                          : 'Sin tutor',
                      color: classroom.teacherName?.isNotEmpty == true
                          ? AppDesignSystem.textSecondary
                          : AppDesignSystem.warningColor,
                    ),
                    if (hasAux)
                      const _MetaLine(
                        icon: Icons.support_agent_rounded,
                        label: 'Con auxiliar',
                        color: AppDesignSystem.infoColor,
                      ),
                    _MetaLine(
                      icon: classroom.isActive
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      label: classroom.isActive ? 'Activa' : 'Inactiva',
                      color: classroom.isActive
                          ? AppDesignSystem.successColor
                          : AppDesignSystem.errorColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AdminButton.primary(
            label: 'Editar',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaLine({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPIs
// ─────────────────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final ClassroomModel classroom;

  const _KpiRow({required this.classroom});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiCard(
        label: 'Estudiantes',
        valueStream: FirebaseFirestore.instance
            .collection('students')
            .where('classroomId', isEqualTo: classroom.id)
            .where('isActive', isEqualTo: true)
            .snapshots()
            .map((s) => s.size.toString()),
        icon: Icons.groups_rounded,
        color: AppDesignSystem.primaryColor,
      ),
      _KpiCard(
        label: 'Capacidad',
        value: classroom.capacity.toString(),
        icon: Icons.event_seat_outlined,
        color: AppDesignSystem.infoColor,
      ),
      _KpiCard(
        label: classroom.hasSchedule ? 'Días lectivos/sem.' : 'Horario',
        value: classroom.hasSchedule
            ? classroom.schedule!.length.toString()
            : '—',
        icon: Icons.schedule_rounded,
        color: AppDesignSystem.warningColor,
        hint: classroom.hasSchedule ? null : 'Sin configurar',
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 700 ? 3 : (c.maxWidth >= 460 ? 2 : 1);
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: cols == 1 ? 4.2 : (cols == 2 ? 2.6 : 2.2),
          children: cards,
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String? value;
  final Stream<String>? valueStream;
  final IconData icon;
  final Color color;
  final String? hint;

  const _KpiCard({
    required this.label,
    this.value,
    this.valueStream,
    required this.icon,
    required this.color,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AdminUi.cardDecoration(elevated: false),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: AppDesignSystem.borderRadiusMD,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppDesignSystem.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                valueStream != null
                    ? StreamBuilder<String>(
                        stream: valueStream,
                        builder: (context, snap) => Text(
                          snap.data ?? '—',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.textPrimary,
                          ),
                        ),
                      )
                    : Text(
                        value ?? '—',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.textPrimary,
                        ),
                      ),
                if (hint != null)
                  Text(
                    hint!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppDesignSystem.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO CARD
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final ClassroomModel classroom;

  const _InfoCard({required this.classroom});

  @override
  Widget build(BuildContext context) {
    final rows = <_InfoRow>[
      _InfoRow(label: 'Nombre', value: classroom.name),
      _InfoRow(
        label: 'Grado · sección',
        value: classroom.grade.isNotEmpty
            ? '${classroom.grade}° ${classroom.section}'
            : '—',
      ),
      _InfoRow(label: 'Capacidad', value: '${classroom.capacity}'),
      if ((classroom.description ?? '').trim().isNotEmpty)
        _InfoRow(label: 'Descripción', value: classroom.description!.trim()),
      if ((classroom.periodName ?? '').isNotEmpty)
        _InfoRow(label: 'Periodo', value: classroom.periodName!),
      _InfoRow(
        label: 'Creada',
        value: _formatDate(classroom.createdAt),
      ),
      _InfoRow(
        label: 'Actualizada',
        value: _formatDate(classroom.updatedAt),
      ),
    ];

    return _SectionCard(
      icon: Icons.info_outline_rounded,
      title: 'Información del aula',
      child: Column(
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: r,
                ))
            .toList(),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppDesignSystem.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppDesignSystem.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEAM CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TeamCard extends StatelessWidget {
  final ClassroomModel classroom;

  const _TeamCard({required this.classroom});

  @override
  Widget build(BuildContext context) {
    final uids = classroom.effectiveTeacherUids;
    final tutorUid = uids.isNotEmpty ? uids.first : null;
    final auxiliarUid = uids.length > 1 ? uids[1] : null;

    return _SectionCard(
      icon: Icons.school_outlined,
      title: 'Equipo docente',
      child: Column(
        children: [
          _TeacherTile(
            uid: tutorUid,
            roleLabel: 'Tutor',
            storedName: classroom.teacherName,
            roleColor: AppDesignSystem.primaryColor,
          ),
          const SizedBox(height: 10),
          if (auxiliarUid != null)
            _TeacherTile(
              uid: auxiliarUid,
              roleLabel: 'Auxiliar',
              roleColor: AppDesignSystem.infoColor,
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AdminUi.surface0,
                borderRadius: AppDesignSystem.borderRadiusMD,
                border: Border.all(color: AdminUi.border, style: BorderStyle.solid),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_rounded,
                      size: 18, color: AppDesignSystem.textSecondary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sin auxiliar asignado',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppDesignSystem.textSecondary,
                        fontWeight: FontWeight.w500,
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
}

class _TeacherTile extends StatelessWidget {
  final String? uid;
  final String roleLabel;
  final String? storedName;
  final Color roleColor;

  const _TeacherTile({
    required this.uid,
    required this.roleLabel,
    this.storedName,
    required this.roleColor,
  });

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return _staticTile(name: 'Sin asignar', email: '—');
    }
    // Lectura puntual del docente (1 doc por tile). Cache local de la sesión
    // del StreamBuilder padre lo evitaría, pero un get directo basta para
    // este detalle (no es lista N+1).
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _staticTile(name: '...', email: '');
        }
        final data = snap.data?.data() ?? const <String, dynamic>{};
        final name = _displayName(data, fallback: storedName);
        final email = (data['email'] ?? '').toString();
        return _staticTile(name: name, email: email);
      },
    );
  }

  Widget _staticTile({required String name, required String email}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDesignSystem.borderRadiusMD,
        border: Border.all(color: AdminUi.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: roleColor.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: roleColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppDesignSystem.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppDesignSystem.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.10),
              borderRadius: AppDesignSystem.borderRadiusFull,
            ),
            child: Text(
              roleLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: roleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _displayName(Map<String, dynamic> data, {String? fallback}) {
    final fn = (data['firstName'] ?? '').toString().trim();
    final ln = (data['lastName'] ?? '').toString().trim();
    final full = (data['fullName'] ?? '').toString().trim();
    final composed = '$fn $ln'.trim();
    if (composed.isNotEmpty) return composed;
    if (full.isNotEmpty) return full;
    if (fallback != null && fallback.trim().isNotEmpty) return fallback.trim();
    return (data['email'] ?? '(sin nombre)').toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminUi.cardDecoration(elevated: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppDesignSystem.primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppDesignSystem.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _ComingSoonCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminUi.surface0,
        borderRadius: AppDesignSystem.borderRadiusMD,
        border: Border.all(color: AdminUi.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppDesignSystem.textDisabled.withValues(alpha: 0.10),
              borderRadius: AppDesignSystem.borderRadiusMD,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: AppDesignSystem.textSecondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppDesignSystem.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.textDisabled.withValues(alpha: 0.15),
                        borderRadius: AppDesignSystem.borderRadiusFull,
                      ),
                      child: const Text(
                        'Próximamente',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppDesignSystem.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppDesignSystem.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: AppDesignSystem.errorColor),
            const SizedBox(height: 10),
            const Text('No se pudo cargar el aula',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppDesignSystem.textPrimary,
                )),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppDesignSystem.textSecondary)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Get.back<void>(),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFoundState extends StatelessWidget {
  const _NotFoundState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.class_outlined,
                size: 40, color: AppDesignSystem.textDisabled),
            const SizedBox(height: 10),
            const Text('Aula no encontrada',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppDesignSystem.textPrimary,
                )),
            const SizedBox(height: 4),
            const Text(
              'El aula puede haber sido eliminada o desactivada.',
              style: TextStyle(
                  fontSize: 12, color: AppDesignSystem.textSecondary),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Get.back<void>(),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/classroom_model.dart';
import '../../../services/classroom_service.dart';
import '../../../services/teacher_service.dart';
import '../../../theme/app_design_system.dart';
import 'widgets/classroom_form_dialog.dart';
import 'widgets/assign_teacher_dialog.dart';
import 'widgets/schedule_config_dialog.dart';
import '../widgets/admin_ui.dart';

const _kBorder = Color(0xFFE6EAF0);
const _kCanvas = Color(0xFFF4F6FA);

// Columnas de la tabla de Aulas (header y filas comparten esta spec).
// Texto → izquierda; ESTADO (chip) → centrado; acciones → derecha.
const List<AdminColumn> _classroomColumns = [
  AdminColumn.flex(5, header: 'AULA'), // avatar + nombre
  AdminColumn.flex(2, header: 'GRADO / SEC'), // texto
  AdminColumn.flex(4, header: 'DOCENTE'), // ícono + nombre
  AdminColumn.flex(3, header: 'HORARIO'), // texto
  AdminColumn.fixed(124, header: 'ESTADO'), // chip centrado
  AdminColumn.fixed(
    AdminTable.actionColWidth,
    align: Alignment.centerRight,
  ), // acciones
];

// Padding horizontal de la tabla de Aulas (header y filas deben coincidir).
const EdgeInsets _classroomRowPadding = EdgeInsets.symmetric(horizontal: 20);

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AdminClassroomsScreen extends StatefulWidget {
  const AdminClassroomsScreen({super.key});

  @override
  State<AdminClassroomsScreen> createState() => _AdminClassroomsScreenState();
}

class _AdminClassroomsScreenState extends State<AdminClassroomsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _search = TextEditingController();
  String _filterOp = 'all'; // all | ready | no_teacher | no_schedule
  String _query = '';
  int _page = 0; // paginación cliente, 10 por página

  // Fetch active classrooms (getAllClassrooms filters isActive==true).
  // Inactive classrooms view → TODO Fase 5: add isActive filter toggle.
  final Stream<QuerySnapshot> _stream = ClassroomService.getAllClassrooms();
  late final Stream<QuerySnapshot> _teachersStream =
      TeacherService.getTeachersStream();

  @override
  void initState() {
    super.initState();
    _search.addListener(
      () => setState(() {
        _query = _search.text;
        _page = 0; // reiniciar paginación al buscar
      }),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ── Filtering ──────────────────────────────────────────────────────────────

  _OpStatus _opStatus(ClassroomModel c) {
    if (!c.hasTeacher) return _OpStatus.noTeacher;
    if (!c.hasSchedule) return _OpStatus.noSchedule;
    return _OpStatus.ready;
  }

  List<ClassroomModel> _filtered(List<ClassroomModel> all) {
    var list = all;
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.grade.toLowerCase().contains(q) ||
            c.section.toLowerCase().contains(q) ||
            (c.teacherName?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    if (_filterOp != 'all') {
      list = list.where((c) {
        final s = _opStatus(c);
        return switch (_filterOp) {
          'ready' => s == _OpStatus.ready,
          'no_teacher' => s == _OpStatus.noTeacher,
          'no_schedule' => s == _OpStatus.noSchedule,
          _ => true,
        };
      }).toList();
    }
    list.sort((a, b) {
      final g = a.grade.compareTo(b.grade);
      return g != 0 ? g : a.section.compareTo(b.section);
    });
    return list;
  }

  Map<String, String> _teacherNamesByUid(QuerySnapshot? snap) {
    final result = <String, String>{};
    for (final doc in snap?.docs ?? const <QueryDocumentSnapshot>[]) {
      final data = (doc.data() as Map<String, dynamic>?) ?? {};
      final uid = ((data['uid'] as String?) ?? doc.id).trim();
      if (uid.isEmpty) continue;
      final fullName = (data['fullName'] ?? '').toString().trim();
      final firstName = (data['firstName'] ?? '').toString().trim();
      final lastName = (data['lastName'] ?? '').toString().trim();
      final email = (data['email'] ?? '').toString().trim();
      final name = fullName.isNotEmpty
          ? fullName
          : '$firstName $lastName'.trim().isNotEmpty
          ? '$firstName $lastName'.trim()
          : email;
      if (name.isNotEmpty) result[uid] = name;
    }
    return result;
  }

  // ── Dialogs / actions ──────────────────────────────────────────────────────

  void _showCreateDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => const ClassroomFormDialog(),
    );
  }

  void _showEditDialog(ClassroomModel c) {
    showDialog<void>(
      context: context,
      builder: (_) => ClassroomFormDialog(classroom: c),
    );
  }

  void _showAssignTeacher(ClassroomModel c) {
    showDialog<void>(
      context: context,
      builder: (_) => AssignTeacherDialog(classroom: c),
    );
  }

  void _showSchedule(ClassroomModel c) {
    showDialog<void>(
      context: context,
      builder: (_) => ScheduleConfigDialog(classroom: c),
    );
  }

  Future<void> _confirmToggle(ClassroomModel c) async {
    final action = c.isActive ? 'desactivar' : 'activar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppDesignSystem.borderRadiusLG,
        ),
        title: Text(
          '¿${c.isActive ? 'Desactivar' : 'Activar'} aula?',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '${c.isActive ? 'Desactivar' : 'Activar'} el aula "${c.name}" '
          '${c.isActive ? 'la ocultará de los docentes y del sistema.' : 'la volverá a activar.'}',
        ),
        actions: [
          AdminButton.ghost(
            label: 'Cancelar',
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          c.isActive
              ? AdminButton.danger(
                  label: action[0].toUpperCase() + action.substring(1),
                  onPressed: () => Navigator.of(ctx).pop(true),
                )
              : AdminButton.primary(
                  label: action[0].toUpperCase() + action.substring(1),
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = c.isActive
        ? await ClassroomService.deactivateClassroom(c.id!)
        : await ClassroomService.reactivateClassroom(c.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      AdminFeedback.snack(
        ok ? AdminFeedbackType.success : AdminFeedbackType.error,
        ok
            ? 'Aula ${c.isActive ? 'desactivada' : 'activada'} correctamente'
            : 'No se pudo cambiar el estado',
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppDesignSystem.breakpointDesktop;
    final isWeb = width >= AppDesignSystem.breakpointMobile;
    final pad = AdminUi.pagePadding(width);

    // Inter SOLO en el subárbol de Aulas (no afecta login ni docente).
    return DefaultTextStyle.merge(
      style: AdminUi.fontBase,
      child: Scaffold(
        backgroundColor: AdminUi.surface0,
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(pad, pad, pad, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPageHeader(isDesktop),
                    const SizedBox(height: 16),
                    _buildFilterBar(),
                    const SizedBox(height: 16),
                    _buildTable(isWeb),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page header ────────────────────────────────────────────────────────────

  Widget _buildPageHeader(bool isDesktop) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestión de Aulas',
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 15,
                  fontWeight: FontWeight.w700,
                  color: AppDesignSystem.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Administra aulas, docentes asignados y horarios operativos',
                style: TextStyle(
                  fontSize: 12,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        AdminButton.primary(
          label: 'Nueva aula',
          icon: Icons.add_rounded,
          onPressed: _showCreateDialog,
        ),
      ],
    );
  }

  // ── Filter bar ─────────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AdminUi.cardDecoration(elevated: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
          AdminSearchField(
            controller: _search,
            hint: 'Buscar por nombre, grado, sección o docente…',
            hasValue: _query.isNotEmpty,
            onChanged: (_) {},
            onClear: () {
              _search.clear();
              setState(() => _query = '');
            },
          ),
          const SizedBox(height: 12),

          // Operational status filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  'Estado operativo:',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppDesignSystem.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                ..._buildFilterChips(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFilterChips() {
    final options = [
      ('all', 'Todas', Icons.filter_list_rounded),
      ('ready', 'Listas', Icons.check_circle_outline_rounded),
      ('no_teacher', 'Sin docente', Icons.person_off_outlined),
      ('no_schedule', 'Sin horario', Icons.schedule_rounded),
    ];

    return options.map((opt) {
      final (key, label, icon) = opt;
      final selected = _filterOp == key;
      return AdminFilterChip(
        label: label,
        selected: selected,
        icon: icon,
        onTap: () => setState(() {
          _filterOp = key;
          _page = 0;
        }),
      );
    }).toList();
  }

  // ── Table / cards ──────────────────────────────────────────────────────────

  Widget _buildTable(bool showTable) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _skeleton();
        }
        if (snap.hasError) {
          return _errorCard();
        }

        final allModels = (snap.data?.docs ?? [])
            .map((d) => ClassroomModel.fromFirestore(d))
            .toList();
        final models = _filtered(allModels);

        // Paginación cliente: 10 por página (esta tabla pinta filas no-lazy).
        const perPage = AdminPaginationBar.perPage;
        final total = models.length;
        final pageCount = total == 0 ? 1 : (total / perPage).ceil();
        final page = _page.clamp(0, pageCount - 1);
        final pageModels = total == 0
            ? const <ClassroomModel>[]
            : models.sublist(
                page * perPage,
                (page * perPage + perPage).clamp(0, total),
              );

        return StreamBuilder<QuerySnapshot>(
          stream: _teachersStream,
          builder: (context, teachersSnap) {
            final teacherNamesByUid = _teacherNamesByUid(teachersSnap.data);
            return Container(
              decoration: AdminUi.cardDecoration(elevated: false),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Table header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppDesignSystem.primaryColor.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: AppDesignSystem.borderRadiusSM,
                          ),
                          child: const Icon(
                            Icons.class_rounded,
                            size: 17,
                            color: AppDesignSystem.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Aulas (${models.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppDesignSystem.textPrimary,
                          ),
                        ),
                        if (allModels.length != models.length) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.warningColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: AppDesignSystem.borderRadiusFull,
                            ),
                            child: Text(
                              '${allModels.length} total',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppDesignSystem.warningColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Divider(height: 1, color: _kBorder),

                  if (models.isEmpty)
                    _emptyState()
                  else if (showTable)
                    _ClassroomsWebTable(
                      classrooms: pageModels,
                      teacherNamesByUid: teacherNamesByUid,
                      opStatus: _opStatus,
                      onEdit: _showEditDialog,
                      onAssignTeacher: _showAssignTeacher,
                      onSchedule: _showSchedule,
                      onToggle: _confirmToggle,
                    )
                  else
                    _ClassroomsMobileList(
                      classrooms: pageModels,
                      teacherNamesByUid: teacherNamesByUid,
                      opStatus: _opStatus,
                      onEdit: _showEditDialog,
                      onAssignTeacher: _showAssignTeacher,
                      onSchedule: _showSchedule,
                      onToggle: _confirmToggle,
                    ),
                  if (models.isNotEmpty && total > perPage)
                    AdminPaginationBar(
                      page: page,
                      pageCount: pageCount,
                      totalItems: total,
                      onPrev: page > 0
                          ? () => setState(() => _page = page - 1)
                          : null,
                      onNext: page < pageCount - 1
                          ? () => setState(() => _page = page + 1)
                          : null,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _skeleton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDesignSystem.borderRadiusLG,
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(
          5,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                _SkeletonBox(
                  width: 36,
                  height: 36,
                  radius: AppDesignSystem.borderRadiusSM,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(
                        width: double.infinity,
                        height: 12,
                        radius: AppDesignSystem.borderRadiusFull,
                      ),
                      const SizedBox(height: 6),
                      _SkeletonBox(
                        width: 120,
                        height: 10,
                        radius: AppDesignSystem.borderRadiusFull,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _SkeletonBox(
                  width: 70,
                  height: 24,
                  radius: AppDesignSystem.borderRadiusFull,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDesignSystem.borderRadiusLG,
        border: Border.all(color: _kBorder),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 36,
              color: AppDesignSystem.errorColor,
            ),
            const SizedBox(height: 8),
            const Text(
              'Error al cargar aulas',
              style: TextStyle(
                color: AppDesignSystem.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.class_outlined,
              size: 48,
              color: AppDesignSystem.textDisabled,
            ),
            const SizedBox(height: 12),
            Text(
              _query.isNotEmpty || _filterOp != 'all'
                  ? 'Sin resultados para el filtro aplicado'
                  : 'No hay aulas registradas',
              style: const TextStyle(
                fontSize: 14,
                color: AppDesignSystem.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_query.isEmpty && _filterOp == 'all') ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Crear primera aula'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OPERATIONAL STATUS ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum _OpStatus { ready, noTeacher, noSchedule }

// ─────────────────────────────────────────────────────────────────────────────
// WEB TABLE
// ─────────────────────────────────────────────────────────────────────────────

class _ClassroomsWebTable extends StatelessWidget {
  final List<ClassroomModel> classrooms;
  final Map<String, String> teacherNamesByUid;
  final _OpStatus Function(ClassroomModel) opStatus;
  final void Function(ClassroomModel) onEdit;
  final void Function(ClassroomModel) onAssignTeacher;
  final void Function(ClassroomModel) onSchedule;
  final void Function(ClassroomModel) onToggle;

  const _ClassroomsWebTable({
    required this.classrooms,
    required this.teacherNamesByUid,
    required this.opStatus,
    required this.onEdit,
    required this.onAssignTeacher,
    required this.onSchedule,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header row (misma spec de columnas que las filas)
        AdminTable.headerRow(
          _classroomColumns,
          decorated: false,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        ),
        // Data rows
        ...classrooms.asMap().entries.map((e) {
          return _ClassroomTableRow(
            classroom: e.value,
            teacherNamesByUid: teacherNamesByUid,
            status: opStatus(e.value),
            isLast: e.key == classrooms.length - 1,
            onEdit: onEdit,
            onAssignTeacher: onAssignTeacher,
            onSchedule: onSchedule,
            onToggle: onToggle,
          );
        }),
      ],
    );
  }
}

class _ClassroomTableRow extends StatefulWidget {
  final ClassroomModel classroom;
  final Map<String, String> teacherNamesByUid;
  final _OpStatus status;
  final bool isLast;
  final void Function(ClassroomModel) onEdit;
  final void Function(ClassroomModel) onAssignTeacher;
  final void Function(ClassroomModel) onSchedule;
  final void Function(ClassroomModel) onToggle;

  const _ClassroomTableRow({
    required this.classroom,
    required this.teacherNamesByUid,
    required this.status,
    required this.isLast,
    required this.onEdit,
    required this.onAssignTeacher,
    required this.onSchedule,
    required this.onToggle,
  });

  @override
  State<_ClassroomTableRow> createState() => _ClassroomTableRowState();
}

class _ClassroomTableRowState extends State<_ClassroomTableRow> {
  bool _hovered = false;

  String _scheduleLabel() {
    final s = widget.classroom.schedule;
    if (s == null || s.isEmpty) return '—';
    const abbrev = {
      'monday': 'Lun',
      'tuesday': 'Mar',
      'wednesday': 'Mié',
      'thursday': 'Jue',
      'friday': 'Vie',
    };
    final keys = s.keys.toList()..sort();
    return keys.map((k) => abbrev[k] ?? k.substring(0, 3)).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.classroom;
    final teacherInfo = _ClassroomTeacherInfo.from(c, widget.teacherNamesByUid);
    final initial = c.grade.isNotEmpty
        ? c.grade
        : c.name.substring(0, 1).toUpperCase();

    return Column(
      children: [
        if (!widget.isLast) Divider(height: 1, color: _kBorder),
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: AppDesignSystem.durationFast,
            decoration: AdminUi.rowDecoration(
              hovered: _hovered,
              isLast: widget.isLast,
            ),
            padding: _classroomRowPadding,
            child: SizedBox(
              height: AdminTable.rowHeight,
              child: AdminTable.dataRow(_classroomColumns, [
                // AULA — inicial + nombre como celda compuesta.
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppDesignSystem.primaryColor.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: AppDesignSystem.borderRadiusSM,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: AppDesignSystem.primaryColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        c.name,
                        style: AdminType.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // GRADO / SEC (texto)
                Text(
                  c.grade.isNotEmpty ? '${c.grade}° ${c.section}' : '—',
                  style: AdminType.bodySm.copyWith(
                    color: AppDesignSystem.textSecondary,
                  ),
                ),
                // DOCENTE (ícono + nombre)
                _ClassroomTeacherCell(info: teacherInfo),
                // HORARIO (texto)
                Text(
                  _scheduleLabel(),
                  style: AdminType.bodySm.copyWith(
                    color: c.hasSchedule
                        ? AppDesignSystem.textSecondary
                        : AppDesignSystem.infoColor,
                    fontWeight: c.hasSchedule
                        ? FontWeight.w500
                        : FontWeight.w600,
                  ),
                ),
                // ESTADO (chip centrado por la spec)
                _OpStatusChip(status: widget.status),
                // ACCIONES (Editar visible + menú "⋯", derecha)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AdminActionIcon(
                      icon: Icons.edit_outlined,
                      tooltip: 'Editar',
                      onTap: () => widget.onEdit(c),
                    ),
                    _RowMenu(
                      isActive: c.isActive,
                      onAssignTeacher: () => widget.onAssignTeacher(c),
                      onSchedule: () => widget.onSchedule(c),
                      onToggle: () => widget.onToggle(c),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE CARDS
// ─────────────────────────────────────────────────────────────────────────────

class _ClassroomsMobileList extends StatelessWidget {
  final List<ClassroomModel> classrooms;
  final Map<String, String> teacherNamesByUid;
  final _OpStatus Function(ClassroomModel) opStatus;
  final void Function(ClassroomModel) onEdit;
  final void Function(ClassroomModel) onAssignTeacher;
  final void Function(ClassroomModel) onSchedule;
  final void Function(ClassroomModel) onToggle;

  const _ClassroomsMobileList({
    required this.classrooms,
    required this.teacherNamesByUid,
    required this.opStatus,
    required this.onEdit,
    required this.onAssignTeacher,
    required this.onSchedule,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: classrooms.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: _kBorder),
      itemBuilder: (ctx, i) {
        final c = classrooms[i];
        final teacherInfo = _ClassroomTeacherInfo.from(c, teacherNamesByUid);
        final initial = c.grade.isNotEmpty
            ? c.grade
            : c.name.substring(0, 1).toUpperCase();
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppDesignSystem.primaryColor.withValues(alpha: 0.1),
                  borderRadius: AppDesignSystem.borderRadiusMD,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppDesignSystem.primaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppDesignSystem.textPrimary,
                            ),
                          ),
                        ),
                        _OpStatusChip(status: opStatus(c)),
                      ],
                    ),
                    if (c.grade.isNotEmpty)
                      Text(
                        '${c.grade}° ${c.section} · Cap. ${c.capacity}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppDesignSystem.textSecondary,
                        ),
                      ),
                    _MobileTeacherSummary(info: teacherInfo),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _MobileActionChip(
                          label: 'Editar',
                          icon: Icons.edit_outlined,
                          onTap: () => onEdit(c),
                        ),
                        const SizedBox(width: 6),
                        _MobileActionChip(
                          label: 'Docente',
                          icon: Icons.person_add_alt_1_rounded,
                          onTap: () => onAssignTeacher(c),
                        ),
                        const SizedBox(width: 6),
                        _MobileActionChip(
                          label: 'Horario',
                          icon: Icons.schedule_rounded,
                          onTap: () => onSchedule(c),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _ClassroomTeacherInfo {
  final bool hasTeacher;
  final bool isPolidocente;
  final int count;
  final String primaryName;
  final List<String> assignedNames;
  final List<String> additionalNames;

  const _ClassroomTeacherInfo({
    required this.hasTeacher,
    required this.isPolidocente,
    required this.count,
    required this.primaryName,
    required this.assignedNames,
    required this.additionalNames,
  });

  factory _ClassroomTeacherInfo.from(
    ClassroomModel classroom,
    Map<String, String> teacherNamesByUid,
  ) {
    final orderedUids = <String>[];
    void addUid(String? uid) {
      final value = (uid ?? '').trim();
      if (value.isEmpty || orderedUids.contains(value)) return;
      orderedUids.add(value);
    }

    addUid(classroom.teacherUid);
    for (final uid in classroom.effectiveTeacherUids) {
      addUid(uid);
    }

    final primaryUid = orderedUids.isNotEmpty ? orderedUids.first : null;
    final storedPrimaryName = (classroom.teacherName ?? '').trim();

    String labelFor(String uid) {
      if (uid == primaryUid && storedPrimaryName.isNotEmpty) {
        return storedPrimaryName;
      }
      return teacherNamesByUid[uid] ?? _shortUid(uid);
    }

    final assignedNames = orderedUids.map(labelFor).toList();
    final primaryName = assignedNames.isNotEmpty
        ? assignedNames.first
        : storedPrimaryName.isNotEmpty
        ? storedPrimaryName
        : 'Sin asignar';

    return _ClassroomTeacherInfo(
      hasTeacher: orderedUids.isNotEmpty || storedPrimaryName.isNotEmpty,
      isPolidocente: classroom.isPolidocente || orderedUids.length > 1,
      count: orderedUids.length,
      primaryName: primaryName,
      assignedNames: assignedNames,
      additionalNames: assignedNames.length > 1
          ? assignedNames.skip(1).toList()
          : const [],
    );
  }

  String get countLabel => count == 1 ? '1 docente' : '$count docentes';
  String get tooltip => assignedNames.isEmpty
      ? primaryName
      : 'Docentes asignados: ${assignedNames.join(', ')}';
}

String _shortUid(String uid) {
  if (uid.length <= 8) return uid;
  return '${uid.substring(0, 4)}...${uid.substring(uid.length - 4)}';
}

class _ClassroomTeacherCell extends StatelessWidget {
  final _ClassroomTeacherInfo info;

  const _ClassroomTeacherCell({required this.info});

  @override
  Widget build(BuildContext context) {
    final color = info.hasTeacher
        ? AppDesignSystem.textPrimary
        : AppDesignSystem.warningColor;
    final chips = <Widget>[
      if (info.isPolidocente)
        const _TeacherMetaChip(label: 'Polidocente', emphasized: true),
      if (info.count > 0) _TeacherMetaChip(label: info.countLabel),
      if (info.additionalNames.isNotEmpty)
        _TeacherMetaChip(label: info.additionalNames.first),
      if (info.additionalNames.length > 1)
        _TeacherMetaChip(label: '+${info.additionalNames.length - 1}'),
    ];

    return Tooltip(
      message: info.tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                info.hasTeacher
                    ? Icons.person_rounded
                    : Icons.person_off_outlined,
                size: 14,
                color: info.hasTeacher
                    ? AppDesignSystem.textSecondary
                    : AppDesignSystem.warningColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  info.primaryName,
                  style: AdminType.bodySm.copyWith(
                    color: color,
                    fontWeight: info.hasTeacher
                        ? FontWeight.w600
                        : FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 4, runSpacing: 2, children: chips),
          ],
        ],
      ),
    );
  }
}

class _MobileTeacherSummary extends StatelessWidget {
  final _ClassroomTeacherInfo info;

  const _MobileTeacherSummary({required this.info});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (info.isPolidocente)
        const _TeacherMetaChip(label: 'Polidocente', emphasized: true),
      if (info.count > 0) _TeacherMetaChip(label: info.countLabel),
      ...info.additionalNames
          .take(2)
          .map((name) => _TeacherMetaChip(label: name)),
      if (info.additionalNames.length > 2)
        _TeacherMetaChip(label: '+${info.additionalNames.length - 2}'),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.hasTeacher ? info.primaryName : 'Sin docente',
            style: TextStyle(
              fontSize: 12,
              color: info.hasTeacher
                  ? AppDesignSystem.textSecondary
                  : AppDesignSystem.warningColor,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 5, runSpacing: 5, children: chips),
          ],
        ],
      ),
    );
  }
}

class _TeacherMetaChip extends StatelessWidget {
  final String label;
  final bool emphasized;

  const _TeacherMetaChip({required this.label, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    final fg = emphasized
        ? AppDesignSystem.primaryColor
        : AppDesignSystem.textSecondary;
    final bg = emphasized
        ? AppDesignSystem.primaryColor.withValues(alpha: 0.08)
        : AdminUi.canvas;
    final border = emphasized
        ? AppDesignSystem.primaryColor.withValues(alpha: 0.18)
        : AdminUi.border;

    return Container(
      constraints: const BoxConstraints(maxWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppDesignSystem.borderRadiusFull,
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          height: 1.15,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _OpStatusChip extends StatelessWidget {
  final _OpStatus status;
  const _OpStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      _OpStatus.ready => (
        'Lista',
        AppDesignSystem.successColor,
        const Color(0xFFE6F4EA),
      ),
      _OpStatus.noTeacher => (
        'Sin docente',
        AppDesignSystem.warningColor,
        const Color(0xFFFFF3E0),
      ),
      _OpStatus.noSchedule => (
        'Sin horario',
        AppDesignSystem.infoColor,
        const Color(0xFFE3F0FC),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppDesignSystem.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Menú "⋯" que agrupa acciones secundarias del aula para reducir ruido en la
/// fila. Conserva acciones reales: asignar docente, configurar horario y
/// activar/desactivar.
class _RowMenu extends StatelessWidget {
  final bool isActive;
  final VoidCallback onAssignTeacher;
  final VoidCallback onSchedule;
  final VoidCallback onToggle;

  const _RowMenu({
    required this.isActive,
    required this.onAssignTeacher,
    required this.onSchedule,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Más acciones',
      icon: const Icon(
        Icons.more_horiz_rounded,
        size: 18,
        color: AdminUi.neutralAction,
      ),
      padding: EdgeInsets.zero,
      splashRadius: 18,
      position: PopupMenuPosition.under,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: AppDesignSystem.borderRadiusMD,
        side: const BorderSide(color: AdminUi.border),
      ),
      onSelected: (v) {
        switch (v) {
          case 'assign':
            onAssignTeacher();
          case 'schedule':
            onSchedule();
          case 'toggle':
            onToggle();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'assign',
          child: Row(
            children: [
              const Icon(
                Icons.person_add_alt_1_rounded,
                size: 18,
                color: AdminUi.neutralAction,
              ),
              const SizedBox(width: 10),
              Text('Asignar docente', style: AdminType.bodySm),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'schedule',
          child: Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 18,
                color: AdminUi.neutralAction,
              ),
              const SizedBox(width: 10),
              Text('Configurar horario', style: AdminType.bodySm),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'toggle',
          child: Row(
            children: [
              Icon(
                isActive
                    ? Icons.block_rounded
                    : Icons.check_circle_outline_rounded,
                size: 18,
                color: isActive
                    ? AppDesignSystem.errorColor
                    : AppDesignSystem.successColor,
              ),
              const SizedBox(width: 10),
              Text(
                isActive ? 'Desactivar aula' : 'Activar aula',
                style: AdminType.bodySm.copyWith(
                  color: isActive
                      ? AppDesignSystem.errorColor
                      : AppDesignSystem.successColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MobileActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppDesignSystem.borderRadiusFull,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _kCanvas,
          borderRadius: AppDesignSystem.borderRadiusFull,
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppDesignSystem.primaryColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppDesignSystem.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF1),
        borderRadius: radius,
      ),
    );
  }
}

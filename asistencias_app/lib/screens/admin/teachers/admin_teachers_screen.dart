import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/admin_service.dart';
import '../../../theme/app_design_system.dart';
import '../widgets/admin_ui.dart';

// ─── Palette tokens (same as AdminShell) ────────────────────────────────────
const _kBorder = Color(0xFFE6EAF0);
const _kPrimary = Color(0xFF1976D2);

// Columnas de la tabla de Docentes. Header y filas se construyen desde ESTA
// misma spec (AdminTable), por lo que quedan perfectamente columnados.
// El avatar va DENTRO de la celda DOCENTE (no es columna aparte).
const List<AdminColumn> _teacherColumns = [
  // Header "DOCENTE" indentado 48px (avatar 36 + gap 12) para alinear con el
  // nombre del docente, no con el avatar.
  AdminColumn.flex(5, header: 'DOCENTE', headerIndent: 48),
  AdminColumn.flex(4, header: 'EMAIL'),
  AdminColumn.fixed(108, header: 'AULAS'), // chip centrado
  AdminColumn.fixed(128, header: 'ESTADO'), // chip centrado
  AdminColumn.fixed(AdminTable.actionColWidth,
      align: Alignment.centerRight), // acciones (derecha)
];

// ─── Filter options ──────────────────────────────────────────────────────────
enum _TeacherFilter {
  all,
  active,
  inactive,
  noClassroom,
  withClassroom,
  inactiveWithClassroom,
}

/// Pantalla de gestión de docentes del panel admin.
/// Lee desde Firestore (role == 'docente'|'teacher'), sin filtro isActive,
/// para mostrar activos e inactivos. Muestra conteo de aulas asignadas
/// (derivado de un único stream de classrooms, sin N+1 queries).
class AdminTeachersScreen extends StatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  State<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends State<AdminTeachersScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchCtrl = TextEditingController();
  _TeacherFilter _filter = _TeacherFilter.all;
  String _query = '';
  int _page = 0; // paginación cliente, 10 por página

  // Two parallel streams; loaded once in initState.
  late final Stream<QuerySnapshot> _teachersStream;
  late final Stream<QuerySnapshot> _classroomsStream;

  @override
  void initState() {
    super.initState();
    _teachersStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: ['docente', 'teacher'])
        .snapshots();
    _classroomsStream = FirebaseFirestore.instance
        .collection('classrooms')
        .snapshots();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── helpers ───────────────────────────────────────────────────────────────

  String _displayName(Map<String, dynamic> d) {
    final fn = (d['firstName'] ?? '').toString().trim();
    final ln = (d['lastName'] ?? '').toString().trim();
    final full = (d['fullName'] ?? '').toString().trim();
    final email = (d['email'] ?? '').toString().trim();
    final composed = '$fn $ln'.trim();
    if (composed.isNotEmpty) return composed;
    if (full.isNotEmpty) return full;
    return email;
  }

  String _initial(String name) =>
      name.isNotEmpty ? name[0].toUpperCase() : '?';

  List<QueryDocumentSnapshot> _filter_(
    List<QueryDocumentSnapshot> docs,
    Map<String, int> classroomCount,
  ) {
    return docs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final uid = doc.id;
      final isActive = d['isActive'] as bool? ?? false;
      final isDeleted = d['isDeleted'] as bool? ?? false;
      if (isDeleted) return false;

      final hasClassroom = (classroomCount[uid] ?? 0) > 0;

      switch (_filter) {
        case _TeacherFilter.active:
          if (!isActive) return false;
        case _TeacherFilter.inactive:
          if (isActive) return false;
        case _TeacherFilter.noClassroom:
          if (hasClassroom) return false;
        case _TeacherFilter.withClassroom:
          if (!hasClassroom) return false;
        case _TeacherFilter.inactiveWithClassroom:
          if (isActive || !hasClassroom) return false;
        case _TeacherFilter.all:
          break;
      }

      if (_query.isNotEmpty) {
        final name = _displayName(d).toLowerCase();
        final email = (d['email'] ?? '').toString().toLowerCase();
        if (!name.contains(_query) && !email.contains(_query)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final da = a.data() as Map<String, dynamic>;
        final db = b.data() as Map<String, dynamic>;
        final ta = (da['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb = (db['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });
  }

  // ─── actions ───────────────────────────────────────────────────────────────

  Future<void> _toggleStatus(String uid, bool currentlyActive) async {
    final ok = await AdminService.toggleTeacherStatus(
      teacherUid: uid,
      isActive: !currentlyActive,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(AdminFeedback.snack(
        ok ? AdminFeedbackType.success : AdminFeedbackType.error,
        ok ? 'Estado actualizado' : 'No se pudo actualizar el estado',
      ));
    }
  }

  Future<void> _forcePasswordReset(String uid) async {
    final result =
        await AdminService.forcePasswordChange(teacherUid: uid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(AdminFeedback.snack(
        result['success'] == true
            ? AdminFeedbackType.success
            : AdminFeedbackType.error,
        result['message'] ?? 'Solicitud enviada',
      ));
    }
  }

  // ─── dialogs ───────────────────────────────────────────────────────────────

  void _showCreate() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _TeacherCreateDialog(),
    );
  }

  void _showEdit(String uid, String currentName) {
    showDialog(
      context: context,
      builder: (_) => _TeacherEditDialog(uid: uid, currentName: currentName),
    );
  }

  void _confirmToggle(String uid, String name, bool isActive) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: AppDesignSystem.borderRadiusLG),
        title: Text(isActive ? 'Desactivar docente' : 'Activar docente'),
        content: Text(
          isActive
              ? '¿Desactivar a $name? No podrá iniciar sesión hasta reactivarlo.'
              : '¿Activar a $name? Podrá iniciar sesión nuevamente.',
        ),
        actions: [
          AdminButton.ghost(
            label: 'Cancelar',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          isActive
              ? AdminButton.danger(
                  label: 'Desactivar',
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _toggleStatus(uid, isActive);
                  },
                )
              : AdminButton.primary(
                  label: 'Activar',
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _toggleStatus(uid, isActive);
                  },
                ),
        ],
      ),
    );
  }

  void _confirmForceReset(String uid, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: AppDesignSystem.borderRadiusLG),
        title: const Text('Forzar cambio de contraseña'),
        content: Text(
            '$name deberá cambiar su contraseña en el próximo inicio de sesión.'),
        actions: [
          AdminButton.ghost(
            label: 'Cancelar',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          AdminButton.primary(
            label: 'Confirmar',
            onPressed: () {
              Navigator.of(ctx).pop();
              _forcePasswordReset(uid);
            },
          ),
        ],
      ),
    );
  }

  // ─── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1200;
    final isTablet = width >= 600;

    // Inter SOLO en el subárbol de Docentes (no afecta login ni docente app).
    return DefaultTextStyle.merge(
      style: AdminUi.fontBase,
      child: Container(
        color: AdminUi.surface0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AdminUi.pagePadding(width),
                AdminUi.pagePadding(width),
                AdminUi.pagePadding(width),
                0,
              ),
              child: _TeachersHeader(onAdd: _showCreate),
            ),
            const SizedBox(height: 16),
            _buildToolbar(isDesktop || isTablet),
            const SizedBox(height: 16),
            Expanded(child: _buildBody(isDesktop || isTablet)),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(bool wide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AdminUi.pagePaddingTablet),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AdminUi.cardDecoration(elevated: false),
        child: wide
            ? Row(
                children: [
                  Expanded(flex: 3, child: _searchBox()),
                  const SizedBox(width: 16),
                  Flexible(flex: 4, child: _filterChips()),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _searchBox(),
                  const SizedBox(height: 10),
                  _filterChips(),
                ],
              ),
      ),
    );
  }

  Widget _searchBox() {
    return AdminSearchField(
      controller: _searchCtrl,
      hint: 'Buscar por nombre o email…',
      hasValue: _query.isNotEmpty,
      onChanged: (v) => setState(() {
        _query = v.trim().toLowerCase();
        _page = 0;
      }),
      onClear: () {
        _searchCtrl.clear();
        setState(() {
          _query = '';
          _page = 0;
        });
      },
    );
  }

  Widget _filterChips() {
    const specs = <(_TeacherFilter, String, Color?)>[
      (_TeacherFilter.all, 'Todos', null),
      (_TeacherFilter.active, 'Activos', null),
      (_TeacherFilter.inactive, 'Inactivos', null),
      (_TeacherFilter.noClassroom, 'Sin aula', null),
      (_TeacherFilter.withClassroom, 'Con aula', null),
      (_TeacherFilter.inactiveWithClassroom, 'Inactivo con aula', AppDesignSystem.warningColor),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: specs.map((spec) {
          final f = spec.$1;
          final label = spec.$2;
          final accent = spec.$3;
          final sel = f == _filter;
          return AdminFilterChip(
            label: label,
            selected: sel,
            accent: accent,
            onTap: () => setState(() {
              _filter = f;
              _page = 0;
            }),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody(bool wide) {
    return StreamBuilder<QuerySnapshot>(
      stream: _classroomsStream,
      builder: (context, classSnap) {
        // Build uid→classroomCount map once; re-renders only when classrooms change.
        final classroomCount = <String, int>{};
        if (classSnap.hasData) {
          for (final doc in classSnap.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            final uid = (d['teacherUid'] as String?) ?? '';
            if (uid.isNotEmpty) {
              classroomCount[uid] = (classroomCount[uid] ?? 0) + 1;
            }
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _teachersStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return _buildSkeleton(wide);
            }
            if (snap.hasError) {
              return _errorState('${snap.error}');
            }

            final allDocs = snap.data?.docs ?? [];
            final filtered = _filter_(allDocs, classroomCount);

            if (filtered.isEmpty) {
              return _emptyState(allDocs.isEmpty);
            }

            // Paginación cliente: 10 por página sobre la lista filtrada.
            const perPage = AdminPaginationBar.perPage;
            final total = filtered.length;
            final pageCount = (total / perPage).ceil();
            final page = _page.clamp(0, pageCount - 1);
            final start = page * perPage;
            final pageDocs =
                filtered.sublist(start, (start + perPage).clamp(0, total));

            final Widget content = wide
                ? _WebTable(
                    docs: pageDocs,
                    classroomCount: classroomCount,
                    displayName: _displayName,
                    onEdit: (uid, name) => _showEdit(uid, name),
                    onToggle: (uid, name, active) =>
                        _confirmToggle(uid, name, active),
                    onForceReset: (uid, name) => _confirmForceReset(uid, name),
                  )
                : _MobileList(
                    docs: pageDocs,
                    classroomCount: classroomCount,
                    displayName: _displayName,
                    initial: _initial,
                    onEdit: (uid, name) => _showEdit(uid, name),
                    onToggle: (uid, name, active) =>
                        _confirmToggle(uid, name, active),
                    onForceReset: (uid, name) => _confirmForceReset(uid, name),
                  );

            return Column(
              children: [
                Expanded(child: content),
                AdminPaginationBar(
                  page: page,
                  pageCount: pageCount,
                  totalItems: total,
                  onPrev:
                      page > 0 ? () => setState(() => _page = page - 1) : null,
                  onNext: page < pageCount - 1
                      ? () => setState(() => _page = page + 1)
                      : null,
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── empty / error / skeleton ───────────────────────────────────────────────

  Widget _emptyState(bool noTeachers) {
    return AdminEmptyState(
      icon: Icons.people_outline_rounded,
      title: noTeachers
          ? 'No hay docentes registrados'
          : 'No se encontraron docentes',
      message: noTeachers
          ? 'Crea el primer docente con el botón "Nuevo docente".'
          : 'Prueba ajustando el filtro o la búsqueda.',
    );
  }

  Widget _errorState(String msg) {
    return AdminEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Error al cargar docentes',
      message: msg,
      error: true,
    );
  }

  Widget _buildSkeleton(bool wide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: List.generate(
            5,
            (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppDesignSystem.borderRadiusMD,
                      border: Border.all(color: _kBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _kBorder,
                              shape: BoxShape.circle,
                            )),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                    width: 140,
                                    height: 12,
                                    color: _kBorder),
                                const SizedBox(height: 6),
                                Container(
                                    width: 200,
                                    height: 10,
                                    color: _kBorder),
                              ]),
                        ),
                      ]),
                    ),
                  ),
                )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _TeachersHeader extends StatelessWidget {
  final VoidCallback onAdd;

  const _TeachersHeader({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return AdminCompactHeader(
      title: 'Docentes',
      subtitle: 'Gestiona el equipo docente de la institución',
      action: AdminButton.primary(
        label: 'Nuevo docente',
        icon: Icons.add_rounded,
        onPressed: onAdd,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WEB TABLE
// ─────────────────────────────────────────────────────────────────────────────

class _WebTable extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final Map<String, int> classroomCount;
  final String Function(Map<String, dynamic>) displayName;
  final void Function(String uid, String name) onEdit;
  final void Function(String uid, String name, bool active) onToggle;
  final void Function(String uid, String name) onForceReset;

  const _WebTable({
    required this.docs,
    required this.classroomCount,
    required this.displayName,
    required this.onEdit,
    required this.onToggle,
    required this.onForceReset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AdminUi.pagePaddingTablet),
      child: Container(
        decoration: AdminUi.cardDecoration(elevated: false),
        child: Column(
          children: [
            // Header row (misma spec de columnas que las filas)
            AdminTable.headerRow(_teacherColumns),
            // Rows
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final d = doc.data() as Map<String, dynamic>;
                  final uid = doc.id;
                  final name = displayName(d);
                  final email = (d['email'] ?? '').toString();
                  final isActive = d['isActive'] as bool? ?? false;
                  final count = classroomCount[uid] ?? 0;
                  return _TableRow(
                    uid: uid,
                    name: name,
                    email: email,
                    isActive: isActive,
                    classroomCount: count,
                    onEdit: onEdit,
                    onToggle: onToggle,
                    onForceReset: onForceReset,
                    isLast: i == docs.length - 1,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  final String uid;
  final String name;
  final String email;
  final bool isActive;
  final int classroomCount;
  final void Function(String uid, String name) onEdit;
  final void Function(String uid, String name, bool active) onToggle;
  final void Function(String uid, String name) onForceReset;
  final bool isLast;

  const _TableRow({
    required this.uid,
    required this.name,
    required this.email,
    required this.isActive,
    required this.classroomCount,
    required this.onEdit,
    required this.onToggle,
    required this.onForceReset,
    required this.isLast,
  });

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: AdminUi.rowDecoration(
          hovered: _hovered,
          isLast: widget.isLast,
        ),
        height: AdminTable.rowHeight,
        padding: AdminTable.rowPadding,
        child: AdminTable.dataRow(_teacherColumns, [
          // DOCENTE — avatar + nombre como una sola celda compuesta.
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: widget.isActive
                    ? _kPrimary.withValues(alpha: 0.12)
                    : _kBorder,
                child: Text(
                  widget.name.isNotEmpty
                      ? widget.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: widget.isActive
                        ? _kPrimary
                        : AppDesignSystem.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.name,
                  style: AdminType.bodyStrong,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // EMAIL
          Text(
            widget.email,
            style: AdminType.bodySm
                .copyWith(color: AppDesignSystem.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
          // AULAS (chip centrado por la spec de columna)
          _ClassroomCountChip(count: widget.classroomCount),
          // ESTADO (chip centrado por la spec de columna)
          _StatusChip(
            isActive: widget.isActive,
            classroomCount: widget.classroomCount,
          ),
          // ACCIONES (alineadas a la derecha por la spec de columna)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdminActionIcon(
                icon: Icons.edit_outlined,
                tooltip: 'Editar',
                onTap: () => widget.onEdit(widget.uid, widget.name),
              ),
              _RowMenu(
                isActive: widget.isActive,
                onForceReset: () =>
                    widget.onForceReset(widget.uid, widget.name),
                onToggle: () => widget.onToggle(
                    widget.uid, widget.name, widget.isActive),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

/// Menú "⋯" que agrupa las acciones secundarias para reducir ruido en la fila.
/// Mantiene acciones reales: forzar cambio de contraseña y activar/desactivar.
class _RowMenu extends StatelessWidget {
  final bool isActive;
  final VoidCallback onForceReset;
  final VoidCallback onToggle;

  const _RowMenu({
    required this.isActive,
    required this.onForceReset,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Más acciones',
      icon: const Icon(Icons.more_horiz_rounded,
          size: 18, color: AdminUi.neutralAction),
      padding: EdgeInsets.zero,
      splashRadius: 18,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: AppDesignSystem.borderRadiusMD,
        side: const BorderSide(color: AdminUi.border),
      ),
      color: Colors.white,
      onSelected: (v) {
        if (v == 'reset') {
          onForceReset();
        } else if (v == 'toggle') {
          onToggle();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'reset',
          child: Row(
            children: [
              const Icon(Icons.lock_reset_rounded,
                  size: 18, color: AdminUi.neutralAction),
              const SizedBox(width: 10),
              Text('Forzar cambio de contraseña', style: AdminType.bodySm),
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
                isActive ? 'Desactivar docente' : 'Activar docente',
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

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE LIST
// ─────────────────────────────────────────────────────────────────────────────

class _MobileList extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final Map<String, int> classroomCount;
  final String Function(Map<String, dynamic>) displayName;
  final String Function(String) initial;
  final void Function(String uid, String name) onEdit;
  final void Function(String uid, String name, bool active) onToggle;
  final void Function(String uid, String name) onForceReset;

  const _MobileList({
    required this.docs,
    required this.classroomCount,
    required this.displayName,
    required this.initial,
    required this.onEdit,
    required this.onToggle,
    required this.onForceReset,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: docs.length,
      itemBuilder: (ctx, i) {
        final doc = docs[i];
        final d = doc.data() as Map<String, dynamic>;
        final uid = doc.id;
        final name = displayName(d);
        final email = (d['email'] ?? '').toString();
        final isActive = d['isActive'] as bool? ?? false;
        final count = classroomCount[uid] ?? 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppDesignSystem.borderRadiusMD,
              border: Border.all(color: _kBorder),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isActive
                          ? _kPrimary.withValues(alpha: 0.12)
                          : _kBorder,
                      child: Text(
                        initial(name),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? _kPrimary
                              : AppDesignSystem.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppDesignSystem.textPrimary)),
                          Text(email,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppDesignSystem.textSecondary),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    _StatusChip(
                      isActive: isActive,
                      classroomCount: count,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _ClassroomCountChip(count: count),
                    const Spacer(),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                          foregroundColor: _kPrimary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6)),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Editar',
                          style: TextStyle(fontSize: 12)),
                      onPressed: () => onEdit(uid, name),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                          foregroundColor: isActive
                              ? AppDesignSystem.errorColor
                              : AppDesignSystem.successColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6)),
                      icon: Icon(
                          isActive
                              ? Icons.block_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 15),
                      label: Text(isActive ? 'Desactivar' : 'Activar',
                          style: const TextStyle(fontSize: 12)),
                      onPressed: () => onToggle(uid, name, isActive),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHIPS
// ─────────────────────────────────────────────────────────────────────────────

/// Shows: Activo | Inactivo | Inactivo con aula (warning) depending on state.
/// classroomCount is needed to surface the alert when an inactive teacher
/// still has classrooms assigned — those aulas appear "sin docente" to students.
// TODO(phone): UserModel and Firestore user docs do not have a 'phone' field.
// If the institution needs it, add 'phone' to Firestore user doc via admin_service
// and surface it here as a third line in the teacher card / table row detail.
class _StatusChip extends StatelessWidget {
  final bool isActive;
  final int classroomCount;

  const _StatusChip({
    required this.isActive,
    required this.classroomCount,
  });

  @override
  Widget build(BuildContext context) {
    // Inactive teacher with classrooms still assigned — surfaces as a warning.
    final isInactiveWithClassroom = !isActive && classroomCount > 0;

    final Color fg;
    final String label;
    final IconData? icon;

    if (isInactiveWithClassroom) {
      fg = AppDesignSystem.warningColor;
      label = 'Inactivo con aula';
      icon = Icons.warning_amber_rounded;
    } else if (isActive) {
      fg = AppDesignSystem.successColor;
      label = 'Activo';
      icon = null;
    } else {
      fg = AppDesignSystem.errorColor;
      label = 'Inactivo';
      icon = null;
    }

    return AdminStatusChip(label: label, color: fg, icon: icon);
  }
}

class _ClassroomCountChip extends StatelessWidget {
  final int count;
  const _ClassroomCountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final hasClassroom = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: hasClassroom
            ? _kPrimary.withValues(alpha: 0.08)
            : _kBorder,
        borderRadius: AppDesignSystem.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.class_rounded,
              size: 12,
              color: hasClassroom
                  ? _kPrimary
                  : AppDesignSystem.textSecondary),
          const SizedBox(width: 4),
          Text(
            hasClassroom ? '$count ${count == 1 ? 'aula' : 'aulas'}' : 'Sin aula',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: hasClassroom ? _kPrimary : AppDesignSystem.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _TeacherCreateDialog extends StatefulWidget {
  const _TeacherCreateDialog();

  @override
  State<_TeacherCreateDialog> createState() => _TeacherCreateDialogState();
}

class _TeacherCreateDialogState extends State<_TeacherCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final result = await AdminService.createTeacher(
      email: _emailCtrl.text.trim(),
      fullName: _nameCtrl.text.trim(),
      temporaryPassword: _passCtrl.text,
    );

    if (!mounted) return;
    nav.pop();
    messenger.showSnackBar(AdminFeedback.snack(
      result['success'] == true
          ? AdminFeedbackType.success
          : AdminFeedbackType.error,
      result['message'] ?? '',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: AppDesignSystem.borderRadiusLG),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
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
                        color: _kPrimary.withValues(alpha: 0.1),
                        borderRadius: AppDesignSystem.borderRadiusMD,
                      ),
                      child: const Icon(Icons.person_add_rounded,
                          size: 20, color: _kPrimary),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Nuevo docente',
                        style: TextStyle(
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
                const SizedBox(height: 6),
                const Text(
                  'El docente podrá iniciar sesión inmediatamente con la contraseña temporal.',
                  style: TextStyle(
                      fontSize: 12, color: AppDesignSystem.textSecondary),
                ),
                const SizedBox(height: 20),
                Divider(color: _kBorder, height: 1),
                const SizedBox(height: 20),

                // Nombre
                _formField(
                  controller: _nameCtrl,
                  label: 'Nombre completo *',
                  hint: 'Ej: María López Huanca',
                  icon: Icons.person_outline_rounded,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
                ),
                const SizedBox(height: 14),

                // Email
                _formField(
                  controller: _emailCtrl,
                  label: 'Correo electrónico *',
                  hint: 'Ej: mlopez@colegio.edu.pe',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'El email es requerido';
                    final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                    if (!re.hasMatch(v.trim())) return 'Email inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Contraseña
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'La contraseña es requerida';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                  decoration: AdminInputs.decoration(
                    label: 'Contraseña temporal *',
                    hint: 'Mínimo 6 caracteres',
                    prefixIcon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
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
                          _saving ? null : () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    AdminButton.primary(
                      label: 'Crear docente',
                      icon: Icons.check_rounded,
                      loading: _saving,
                      onPressed: _saving ? null : _submit,
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

  Widget _formField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: AdminInputs.decoration(
        label: label,
        hint: hint,
        prefixIcon: icon,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _TeacherEditDialog extends StatefulWidget {
  final String uid;
  final String currentName;

  const _TeacherEditDialog(
      {required this.uid, required this.currentName});

  @override
  State<_TeacherEditDialog> createState() => _TeacherEditDialogState();
}

class _TeacherEditDialogState extends State<_TeacherEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await AdminService.updateTeacher(
      teacherUid: widget.uid,
      fullName: _nameCtrl.text.trim(),
    );

    if (!mounted) return;
    nav.pop();
    messenger.showSnackBar(AdminFeedback.snack(
      ok ? AdminFeedbackType.success : AdminFeedbackType.error,
      ok ? 'Docente actualizado' : 'No se pudo actualizar',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: AppDesignSystem.borderRadiusLG),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _kPrimary.withValues(alpha: 0.1),
                        borderRadius: AppDesignSystem.borderRadiusMD,
                      ),
                      child: const Icon(Icons.edit_rounded,
                          size: 20, color: _kPrimary),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Editar docente',
                        style: TextStyle(
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
                const SizedBox(height: 20),
                Divider(color: _kBorder, height: 1),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'El nombre es requerido'
                          : null,
                  decoration: AdminInputs.decoration(
                    label: 'Nombre completo *',
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AdminButton.ghost(
                      label: 'Cancelar',
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    AdminButton.primary(
                      label: 'Guardar',
                      icon: Icons.save_rounded,
                      loading: _saving,
                      onPressed: _saving ? null : _submit,
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
}

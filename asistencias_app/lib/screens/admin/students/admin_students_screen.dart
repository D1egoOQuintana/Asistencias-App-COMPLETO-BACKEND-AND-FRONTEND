import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/student_model.dart';
import '../../../services/student_service.dart';
import '../../../services/classroom_service.dart';
import '../../../theme/app_design_system.dart';
import 'widgets/student_form_dialog.dart';
import 'widgets/student_qr_dialog.dart';
import 'widgets/student_transfer_dialog.dart';
import '../widgets/admin_ui.dart';

// ─── Palette (same tokens as AdminShell) ────────────────────────────────────
const _kCanvas = Color(0xFFF4F6FA);
const _kBorder = Color(0xFFE6EAF0);
const _kPrimary = Color(0xFF1976D2);

// ─── Filter options ──────────────────────────────────────────────────────────
enum _StudentFilter {
  all,
  active,
  inactive,
  noPhone,
  withPhone,
  noClassroom,
  withQr,
  noQr,
}

/// Panel admin de gestión de estudiantes.
/// Carga dos streams (students + classrooms) y aplica filtros client-side sin N+1 queries.
/// StudentModel no tiene campo telegramLinked → estado siempre "No verificado".
class AdminStudentsScreen extends StatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  State<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends State<AdminStudentsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchCtrl = TextEditingController();
  _StudentFilter _filter = _StudentFilter.all;
  String _query = '';

  // Two parallel streams — initialized once in initState.
  late final Stream<QuerySnapshot> _studentsStream;
  late final Stream<QuerySnapshot> _classroomsStream;

  @override
  void initState() {
    super.initState();
    // No isActive filter — admin must see active AND inactive students.
    _studentsStream = FirebaseFirestore.instance
        .collection('students')
        .snapshots();
    _classroomsStream = ClassroomService.getAllClassrooms();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── helpers ───────────────────────────────────────────────────────────────

  List<QueryDocumentSnapshot> _applyFilter(
    List<QueryDocumentSnapshot> docs,
  ) {
    return docs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final isActive = d['isActive'] as bool? ?? true;
      final phone = ((d['parentPhone'] as String?) ?? '').trim();
      final qrCode = ((d['qrCode'] as String?) ?? '').trim();
      final classroomId = ((d['classroomId'] as String?) ?? '').trim();

      switch (_filter) {
        case _StudentFilter.active:
          if (!isActive) return false;
        case _StudentFilter.inactive:
          if (isActive) return false;
        case _StudentFilter.noPhone:
          if (phone.isNotEmpty) return false;
        case _StudentFilter.withPhone:
          if (phone.isEmpty) return false;
        case _StudentFilter.noClassroom:
          if (classroomId.isNotEmpty) return false;
        case _StudentFilter.withQr:
          if (qrCode.isEmpty) return false;
        case _StudentFilter.noQr:
          if (qrCode.isNotEmpty) return false;
        case _StudentFilter.all:
          break;
      }

      if (_query.isNotEmpty) {
        final first = (d['firstName'] ?? '').toString().toLowerCase();
        final last = (d['lastName'] ?? '').toString().toLowerCase();
        final dni = (d['dni'] ?? '').toString();
        final email = (d['parentEmail'] ?? '').toString().toLowerCase();
        final fullName = '$first $last';
        if (!fullName.contains(_query) &&
            !dni.contains(_query) &&
            !email.contains(_query)) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final da = a.data() as Map<String, dynamic>;
        final db = b.data() as Map<String, dynamic>;
        final ta = (da['createdAt'] as dynamic)?.seconds as int? ?? 0;
        final tb = (db['createdAt'] as dynamic)?.seconds as int? ?? 0;
        return tb.compareTo(ta);
      });
  }

  // ─── actions ───────────────────────────────────────────────────────────────

  Future<void> _toggleStatus(StudentModel student) async {
    final wasActive = student.isActive;
    final ok = wasActive
        ? await StudentService.deactivateStudent(student.id!)
        : await StudentService.reactivateStudent(student.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Estudiante ${wasActive ? 'desactivado' : 'reactivado'}'
            : 'No se pudo actualizar el estado'),
        backgroundColor:
            ok ? AppDesignSystem.successColor : AppDesignSystem.errorColor,
      ));
    }
  }

  // ─── dialogs ───────────────────────────────────────────────────────────────

  void _showCreate() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const StudentFormDialog(),
    );
  }

  void _showEdit(StudentModel student) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StudentFormDialog(student: student),
    );
  }

  void _showQrDialog(StudentModel student) {
    showDialog(
      context: context,
      builder: (_) => StudentQrDialog(student: student),
    );
  }

  void _showTransfer(StudentModel student) {
    showDialog(
      context: context,
      builder: (_) => StudentTransferDialog(student: student),
    );
  }

  void _confirmToggle(StudentModel student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: AppDesignSystem.borderRadiusLG),
        title: Text(
            student.isActive ? 'Desactivar estudiante' : 'Activar estudiante'),
        content: Text(student.isActive
            ? '¿Desactivar a ${student.fullName}? No aparecerá en los registros activos de asistencia.'
            : '¿Activar a ${student.fullName}? Volverá a ser visible en los registros de asistencia.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: student.isActive
                  ? AppDesignSystem.errorColor
                  : AppDesignSystem.successColor,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _toggleStatus(student);
            },
            child: Text(student.isActive ? 'Desactivar' : 'Activar'),
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
    final isWide = width >= 600;

    return Container(
      color: _kCanvas,
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
            child: _StudentsHeader(onAdd: _showCreate),
          ),
          const SizedBox(height: 16),
          _buildToolbar(isWide),
          const SizedBox(height: 16),
          Expanded(child: _buildBody(isWide)),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool wide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AdminUi.pagePaddingTablet),
      child: wide
          ? Row(
              children: [
                Expanded(flex: 3, child: _searchBox()),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: _filterChips()),
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
    );
  }

  Widget _searchBox() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, apellido o DNI…',
          hintStyle: const TextStyle(
              fontSize: 13, color: AppDesignSystem.textSecondary),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 18, color: AppDesignSystem.textSecondary),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: AppDesignSystem.borderRadiusMD,
            borderSide: const BorderSide(color: _kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppDesignSystem.borderRadiusMD,
            borderSide: const BorderSide(color: _kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppDesignSystem.borderRadiusMD,
            borderSide: const BorderSide(color: _kPrimary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _filterChips() {
    const specs = <(_StudentFilter, String, Color?)>[
      (_StudentFilter.all, 'Todos', null),
      (_StudentFilter.active, 'Activos', null),
      (_StudentFilter.inactive, 'Inactivos', null),
      (_StudentFilter.noPhone, 'Sin teléfono', null),
      (_StudentFilter.withPhone, 'Con teléfono', null),
      (_StudentFilter.noClassroom, 'Sin aula', AppDesignSystem.warningColor),
      (_StudentFilter.withQr, 'Con QR', null),
      (_StudentFilter.noQr, 'Sin QR', AppDesignSystem.warningColor),
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
            onTap: () => setState(() => _filter = f),
          );
        }).toList(),
      ),
    );
  }

  // ─── body ──────────────────────────────────────────────────────────────────

  Widget _buildBody(bool wide) {
    return StreamBuilder<QuerySnapshot>(
      stream: _classroomsStream,
      builder: (context, classSnap) {
        // Build classroomId → display label once; no N+1 queries.
        final classroomMap = <String, String>{};
        if (classSnap.hasData) {
          for (final doc in classSnap.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            final grade = (d['grade'] ?? '').toString();
            final section = (d['section'] ?? '').toString();
            final name = (d['name'] ?? '').toString();
            final label = grade.isNotEmpty && section.isNotEmpty
                ? '$grade° $section${name.isNotEmpty ? ' – $name' : ''}'
                : name.isNotEmpty
                    ? name
                    : doc.id;
            classroomMap[doc.id] = label;
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _studentsStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return _buildSkeleton();
            }
            if (snap.hasError) {
              return _errorState('${snap.error}');
            }
            final allDocs = snap.data?.docs ?? [];
            final filtered = _applyFilter(allDocs);

            if (filtered.isEmpty) {
              return _emptyState(allDocs.isEmpty);
            }

            if (wide) {
              return _WebTable(
                docs: filtered,
                classroomMap: classroomMap,
                onEdit: _showEdit,
                onQr: _showQrDialog,
                onTransfer: _showTransfer,
                onToggle: _confirmToggle,
              );
            }
            return _MobileList(
              docs: filtered,
              classroomMap: classroomMap,
              onEdit: _showEdit,
              onQr: _showQrDialog,
              onTransfer: _showTransfer,
              onToggle: _confirmToggle,
            );
          },
        );
      },
    );
  }

  // ─── skeleton / empty / error ───────────────────────────────────────────────

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: List.generate(
          6,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppDesignSystem.borderRadiusMD,
                border: Border.all(color: _kBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: _kBorder, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 160, height: 11, color: _kBorder),
                    const SizedBox(height: 5),
                    Container(width: 220, height: 9, color: _kBorder),
                  ],
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(bool noStudents) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_outlined,
              size: 56,
              color: AppDesignSystem.textSecondary.withValues(alpha: 0.35)),
          const SizedBox(height: 16),
          Text(
            noStudents
                ? 'No hay estudiantes registrados'
                : 'No se encontraron estudiantes',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppDesignSystem.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            noStudents
                ? 'Crea el primer estudiante con el botón "Nuevo estudiante".'
                : 'Prueba ajustando el filtro o la búsqueda.',
            style: const TextStyle(
                fontSize: 13, color: AppDesignSystem.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _errorState(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppDesignSystem.errorColor),
          const SizedBox(height: 12),
          const Text('Error al cargar estudiantes',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppDesignSystem.textPrimary)),
          const SizedBox(height: 4),
          Text(msg,
              style: const TextStyle(
                  fontSize: 12, color: AppDesignSystem.textSecondary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _StudentsHeader extends StatelessWidget {
  final VoidCallback onAdd;

  const _StudentsHeader({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return AdminCompactHeader(
      title: 'Gestión de estudiantes',
      subtitle: 'Administra padrón, aulas, QR y apoderados',
      action: FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: _kPrimary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(
                  borderRadius: AppDesignSystem.borderRadiusMD),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nuevo estudiante'),
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WEB TABLE
// ─────────────────────────────────────────────────────────────────────────────

class _WebTable extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final Map<String, String> classroomMap;
  final void Function(StudentModel) onEdit;
  final void Function(StudentModel) onQr;
  final void Function(StudentModel) onTransfer;
  final void Function(StudentModel) onToggle;

  const _WebTable({
    required this.docs,
    required this.classroomMap,
    required this.onEdit,
    required this.onQr,
    required this.onTransfer,
    required this.onToggle,
  });

  StudentModel _parse(QueryDocumentSnapshot doc) =>
      StudentModel.fromFirestore(doc as dynamic);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AdminUi.pagePaddingTablet),
      child: Container(
        decoration: AdminUi.cardDecoration(elevated: false),
        child: Column(
          children: [
            // Header
            Container(
              decoration: AdminUi.tableHeaderDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: const Row(
                children: [
                  SizedBox(width: 36),
                  SizedBox(width: 12),
                  Expanded(flex: 3, child: _ColHeader('ESTUDIANTE')),
                  SizedBox(width: 80, child: _ColHeader('DNI')),
                  Expanded(flex: 2, child: _ColHeader('AULA')),
                  Expanded(flex: 2, child: _ColHeader('APODERADO / TEL.')),
                  SizedBox(width: 72, child: _ColHeader('QR')),
                  SizedBox(width: 90, child: _ColHeader('ESTADO')),
                  SizedBox(width: 124),
                ],
              ),
            ),
            // Rows
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final student = _parse(docs[i]);
                  return _TableRow(
                    student: student,
                    classroomLabel:
                        classroomMap[student.classroomId] ?? '—',
                    onEdit: onEdit,
                    onQr: onQr,
                    onTransfer: onTransfer,
                    onToggle: onToggle,
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

class _ColHeader extends StatelessWidget {
  final String text;
  const _ColHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AdminUi.tableHeaderTextStyle,
    );
  }
}

class _TableRow extends StatefulWidget {
  final StudentModel student;
  final String classroomLabel;
  final void Function(StudentModel) onEdit;
  final void Function(StudentModel) onQr;
  final void Function(StudentModel) onTransfer;
  final void Function(StudentModel) onToggle;
  final bool isLast;

  const _TableRow({
    required this.student,
    required this.classroomLabel,
    required this.onEdit,
    required this.onQr,
    required this.onTransfer,
    required this.onToggle,
    required this.isLast,
  });

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final hasPhone =
        s.parentPhone != null && s.parentPhone!.isNotEmpty;
    final hasQr = s.qrCode.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: AdminUi.rowDecoration(
          hovered: _hovered,
          isLast: widget.isLast,
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: s.isActive
                  ? _kPrimary.withValues(alpha: 0.12)
                  : _kBorder,
              child: Text(
                s.firstName.isNotEmpty ? s.firstName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: s.isActive ? _kPrimary : AppDesignSystem.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    s.fullName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppDesignSystem.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (s.parentEmail != null && s.parentEmail!.isNotEmpty)
                    Text(
                      s.parentEmail!,
                      style: const TextStyle(
                          fontSize: 10.5,
                          color: AppDesignSystem.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // DNI
            SizedBox(
              width: 80,
              child: Text(
                s.dni.isNotEmpty ? s.dni : '—',
                style: const TextStyle(
                    fontSize: 12.5,
                    color: AppDesignSystem.textSecondary),
              ),
            ),
            // Classroom
            Expanded(
              flex: 2,
              child: Text(
                widget.classroomLabel,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: AppDesignSystem.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Parent / phone
            Expanded(
              flex: 2,
              child: Text(
                hasPhone ? s.parentPhone! : '—',
                style: TextStyle(
                  fontSize: 12.5,
                  color: hasPhone
                      ? AppDesignSystem.textPrimary
                      : AppDesignSystem.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // QR chip
            SizedBox(
              width: 72,
              child: _QrChip(hasQr: hasQr),
            ),
            // Status chip
            SizedBox(
              width: 90,
              child: _StatusChip(isActive: s.isActive),
            ),
            // Actions
            SizedBox(
              width: 124,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionIcon(
                    icon: Icons.edit_outlined,
                    tooltip: 'Editar datos',
                    color: _kPrimary,
                    onTap: () => widget.onEdit(s),
                  ),
                  _ActionIcon(
                    icon: Icons.swap_horiz_rounded,
                    tooltip: 'Transferir aula',
                    color: AppDesignSystem.warningColor,
                    onTap: () => widget.onTransfer(s),
                  ),
                  _ActionIcon(
                    icon: Icons.qr_code_rounded,
                    tooltip: 'Ver QR / Telegram',
                    color: const Color(0xFF00695C),
                    onTap: () => widget.onQr(s),
                  ),
                  _ActionIcon(
                    icon: s.isActive
                        ? Icons.block_rounded
                        : Icons.check_circle_outline_rounded,
                    tooltip: s.isActive ? 'Desactivar' : 'Activar',
                    color: s.isActive
                        ? AppDesignSystem.errorColor
                        : AppDesignSystem.successColor,
                    onTap: () => widget.onToggle(s),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = color == AppDesignSystem.errorColor
        ? AppDesignSystem.errorColor
        : AdminUi.neutralAction;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: AppDesignSystem.borderRadiusSM,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 17, color: fg),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE LIST
// ─────────────────────────────────────────────────────────────────────────────

class _MobileList extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final Map<String, String> classroomMap;
  final void Function(StudentModel) onEdit;
  final void Function(StudentModel) onQr;
  final void Function(StudentModel) onTransfer;
  final void Function(StudentModel) onToggle;

  const _MobileList({
    required this.docs,
    required this.classroomMap,
    required this.onEdit,
    required this.onQr,
    required this.onTransfer,
    required this.onToggle,
  });

  StudentModel _parse(QueryDocumentSnapshot doc) =>
      StudentModel.fromFirestore(doc as dynamic);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: docs.length,
      itemBuilder: (ctx, i) {
        final s = _parse(docs[i]);
        final hasPhone = s.parentPhone != null && s.parentPhone!.isNotEmpty;
        final classroomLabel = classroomMap[s.classroomId] ?? '—';

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
                Row(children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: s.isActive
                        ? _kPrimary.withValues(alpha: 0.12)
                        : _kBorder,
                    child: Text(
                      s.firstName.isNotEmpty
                          ? s.firstName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: s.isActive
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
                        Text(s.fullName,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppDesignSystem.textPrimary)),
                        Text(
                          [
                            if (s.dni.isNotEmpty) 'DNI: ${s.dni}',
                            classroomLabel,
                          ].join(' · '),
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppDesignSystem.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(isActive: s.isActive),
                ]),
                if (hasPhone || s.parentEmail != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (hasPhone) s.parentPhone!,
                      if (s.parentEmail != null && s.parentEmail!.isNotEmpty)
                        s.parentEmail!,
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 12, color: AppDesignSystem.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: [
                    _SmallActionBtn(
                      icon: Icons.edit_outlined,
                      label: 'Editar',
                      color: _kPrimary,
                      onTap: () => onEdit(s),
                    ),
                    _SmallActionBtn(
                      icon: Icons.qr_code_rounded,
                      label: 'QR / Telegram',
                      color: const Color(0xFF00695C),
                      onTap: () => onQr(s),
                    ),
                    _SmallActionBtn(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Transferir',
                      color: AppDesignSystem.warningColor,
                      onTap: () => onTransfer(s),
                    ),
                    _SmallActionBtn(
                      icon: s.isActive
                          ? Icons.block_rounded
                          : Icons.check_circle_outline_rounded,
                      label: s.isActive ? 'Desactivar' : 'Activar',
                      color: s.isActive
                          ? AppDesignSystem.errorColor
                          : AppDesignSystem.successColor,
                      onTap: () => onToggle(s),
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

class _SmallActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SmallActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppDesignSystem.borderRadiusSM,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppDesignSystem.borderRadiusSM,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGE CHIPS
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final bool isActive;
  const _StatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? AppDesignSystem.successColor.withValues(alpha: 0.1)
            : AppDesignSystem.errorColor.withValues(alpha: 0.08),
        borderRadius: AppDesignSystem.borderRadiusFull,
      ),
      child: Text(
        isActive ? 'Activo' : 'Inactivo',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: isActive
              ? AppDesignSystem.successColor
              : AppDesignSystem.errorColor,
        ),
      ),
    );
  }
}

class _QrChip extends StatelessWidget {
  final bool hasQr;
  const _QrChip({required this.hasQr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasQr
            ? const Color(0xFF00695C).withValues(alpha: 0.09)
            : _kBorder,
        borderRadius: AppDesignSystem.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_rounded,
              size: 11,
              color: hasQr
                  ? const Color(0xFF00695C)
                  : AppDesignSystem.textSecondary),
          const SizedBox(width: 3),
          Text(
            hasQr ? 'QR' : 'Sin QR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: hasQr
                  ? const Color(0xFF00695C)
                  : AppDesignSystem.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

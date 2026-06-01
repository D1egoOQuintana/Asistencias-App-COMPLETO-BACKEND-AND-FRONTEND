import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/classroom_service.dart';
import '../../../theme/app_design_system.dart';
import '../widgets/admin_ui.dart';

// ─── Palette tokens ──────────────────────────────────────────────────────────
const _kBorder = Color(0xFFE6EAF0);
const _kPrimary = Color(0xFF1976D2);
const _kNavy = Color(0xFF0D1B2A);

// ─── Abandoned threshold ─────────────────────────────────────────────────────
const _kAbandonedHours = 4;

// Columnas de la tabla de Sesiones (header y filas comparten esta spec).
// Texto → izquierda; ESTADO (chip) → centrado; info → derecha.
const List<AdminColumn> _sessionColumns = [
  AdminColumn.flex(3, header: 'AULA'),
  AdminColumn.flex(2, header: 'DOCENTE'),
  AdminColumn.fixed(110, header: 'ESTADO'), // chip centrado
  AdminColumn.fixed(72, align: Alignment.centerLeft, header: 'INICIO'),
  AdminColumn.fixed(72, align: Alignment.centerLeft, header: 'FIN'),
  AdminColumn.fixed(68, align: Alignment.centerLeft, header: 'DURACIÓN'),
  AdminColumn.fixed(68, align: Alignment.centerLeft, header: 'REG.'),
  AdminColumn.fixed(56, align: Alignment.centerRight), // info (pasivo)
];

// ─── Session status ───────────────────────────────────────────────────────────
enum _SessionStatus { notStarted, active, finished, abandoned }

// ─── Filter ──────────────────────────────────────────────────────────────────
enum _SessionFilter { all, active, finished, notStarted, abandoned }

/// Fila combinada: aula + su sesión del día seleccionado (si existe).
class _SessionRow {
  final String classroomId;
  final String classroomLabel; // "3° A – Matemáticas"
  final String teacherName;
  final String? sessionId;
  final bool? isActive;
  final DateTime? startTime;
  final DateTime? endTime;
  final int attendanceCount;
  final _SessionStatus status;

  const _SessionRow({
    required this.classroomId,
    required this.classroomLabel,
    required this.teacherName,
    this.sessionId,
    this.isActive,
    this.startTime,
    this.endTime,
    this.attendanceCount = 0,
    required this.status,
  });
}

/// Panel de supervisión de sesiones de asistencia.
/// El administrador observa; el docente sigue siendo quien abre y cierra sesiones.
///
/// Queries:
/// - `attendance_sessions` filtradas por `date == dateStr` (una sola igualdad, sin índice compuesto).
/// - `classrooms` via ClassroomService.getAllClassrooms() — una sola carga.
/// Merge client-side: por classroomId. Sin N+1 queries.
///
// TODO(admin-close-session): No existe lógica segura de cierre administrativo.
// Si se necesita, debe incluir trazabilidad (closedByAdmin, adminUid, closeReason)
// y notificación al docente. Implementar como Cloud Function con validación.
class AdminSessionsScreen extends StatefulWidget {
  const AdminSessionsScreen({super.key});

  @override
  State<AdminSessionsScreen> createState() => _AdminSessionsScreenState();
}

class _AdminSessionsScreenState extends State<AdminSessionsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime _selectedDate = DateTime.now();
  _SessionFilter _filter = _SessionFilter.all;

  // Classrooms stream — loaded once; rebuilt only if screen is recreated.
  late final Stream<QuerySnapshot> _classroomsStream;

  @override
  void initState() {
    super.initState();
    _classroomsStream = ClassroomService.getAllClassrooms();
  }

  String get _dateStr {
    final d = _selectedDate;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  // Sessions stream is rebuilt whenever _selectedDate changes.
  Stream<QuerySnapshot> get _sessionsStream => FirebaseFirestore.instance
      .collection('attendance_sessions')
      .where('date', isEqualTo: _dateStr)
      .snapshots()
      .handleError((_) {}); // silently ignore missing-index or permission errors

  // ─── date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  // ─── build combined rows ────────────────────────────────────────────────────

  List<_SessionRow> _buildRows(
    List<QueryDocumentSnapshot> classroomDocs,
    List<QueryDocumentSnapshot> sessionDocs,
  ) {
    // Build session map by classroomId
    final sessionMap = <String, QueryDocumentSnapshot>{};
    for (final s in sessionDocs) {
      final d = s.data() as Map<String, dynamic>;
      final cid = (d['classroomId'] as String?) ?? '';
      if (cid.isNotEmpty) sessionMap[cid] = s;
    }

    final now = DateTime.now();
    final rows = <_SessionRow>[];

    for (final cDoc in classroomDocs) {
      final cd = cDoc.data() as Map<String, dynamic>;
      final grade = (cd['grade'] ?? '').toString();
      final section = (cd['section'] ?? '').toString();
      final name = (cd['name'] ?? '').toString();
      final label = grade.isNotEmpty && section.isNotEmpty
          ? '$grade° $section${name.isNotEmpty ? ' – $name' : ''}'
          : name.isNotEmpty
              ? name
              : cDoc.id;
      final teacherName = (cd['teacherName'] as String?) ?? '—';

      final sDoc = sessionMap[cDoc.id];
      if (sDoc == null) {
        rows.add(_SessionRow(
          classroomId: cDoc.id,
          classroomLabel: label,
          teacherName: teacherName,
          status: _SessionStatus.notStarted,
        ));
      } else {
        final sd = sDoc.data() as Map<String, dynamic>;
        final isActive = sd['isActive'] as bool? ?? false;
        final startTs = sd['startTime'] as Timestamp?;
        final endTs = sd['endTime'] as Timestamp?;
        final count = (sd['attendanceCount'] as int?) ?? 0;
        final startTime = startTs?.toDate();
        final endTime = endTs?.toDate();

        _SessionStatus status;
        if (!isActive) {
          status = _SessionStatus.finished;
        } else if (startTime != null &&
            now.difference(startTime).inHours >= _kAbandonedHours) {
          status = _SessionStatus.abandoned;
        } else {
          status = _SessionStatus.active;
        }

        rows.add(_SessionRow(
          classroomId: cDoc.id,
          classroomLabel: label,
          teacherName: teacherName,
          sessionId: sDoc.id,
          isActive: isActive,
          startTime: startTime,
          endTime: endTime,
          attendanceCount: count,
          status: status,
        ));
      }
    }

    // Sort: active first, then abandoned, finished, not started
    rows.sort((a, b) => _statusOrder(a.status).compareTo(_statusOrder(b.status)));
    return rows;
  }

  int _statusOrder(_SessionStatus s) {
    switch (s) {
      case _SessionStatus.abandoned:
        return 0;
      case _SessionStatus.active:
        return 1;
      case _SessionStatus.finished:
        return 2;
      case _SessionStatus.notStarted:
        return 3;
    }
  }

  List<_SessionRow> _applyFilter(List<_SessionRow> rows) {
    switch (_filter) {
      case _SessionFilter.active:
        return rows.where((r) => r.status == _SessionStatus.active).toList();
      case _SessionFilter.finished:
        return rows.where((r) => r.status == _SessionStatus.finished).toList();
      case _SessionFilter.notStarted:
        return rows
            .where((r) => r.status == _SessionStatus.notStarted)
            .toList();
      case _SessionFilter.abandoned:
        return rows
            .where((r) => r.status == _SessionStatus.abandoned)
            .toList();
      case _SessionFilter.all:
        return rows;
    }
  }

  // ─── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 600;

    // Inter SOLO en el subárbol de Sesiones (no afecta login ni docente).
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
              child: _buildHeader(context, width >= 1200),
            ),
            const SizedBox(height: 16),
            _buildToolbar(context, isWide),
            const SizedBox(height: 16),
            Expanded(child: _buildBody(isWide)),
          ],
        ),
      ),
    );
  }

  // ─── header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return Row(
      children: [
        Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sesiones de asistencia',
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 15,
                    fontWeight: FontWeight.w700,
                    color: AppDesignSystem.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Supervisa la apertura, estado y cierre de sesiones por aula',
                  style: TextStyle(
                      fontSize: 12, color: AppDesignSystem.textSecondary),
                ),
              ],
            ),
        ),
        // Date selector chip
        GestureDetector(
            onTap: () => _pickDate(context),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _isToday
                    ? _kPrimary.withValues(alpha: 0.08)
                    : Colors.white,
                borderRadius: AppDesignSystem.borderRadiusMD,
                border: Border.all(
                    color: _isToday
                        ? _kPrimary.withValues(alpha: 0.4)
                        : _kBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 14,
                      color: _isToday ? _kPrimary : AppDesignSystem.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    _isToday ? 'Hoy, ${_formatDate(_selectedDate)}' : _formatDate(_selectedDate),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isToday ? _kPrimary : AppDesignSystem.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down_rounded,
                      size: 18,
                      color: _isToday ? _kPrimary : AppDesignSystem.textSecondary),
                ],
              ),
            ),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  // ─── toolbar ───────────────────────────────────────────────────────────────

  Widget _buildToolbar(BuildContext context, bool wide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AdminUi.pagePaddingTablet),
      child: _filterChips(),
    );
  }

  Widget _filterChips() {
    const specs = <(_SessionFilter, String, Color?)>[
      (_SessionFilter.all, 'Todas', null),
      (_SessionFilter.active, 'Activas', AppDesignSystem.successColor),
      (_SessionFilter.finished, 'Finalizadas', null),
      (_SessionFilter.notStarted, 'No iniciadas', null),
      (_SessionFilter.abandoned, 'Abandonadas', AppDesignSystem.warningColor),
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
        final classroomDocs = classSnap.data?.docs ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: _sessionsStream,
          builder: (context, sessSnap) {
            if (sessSnap.connectionState == ConnectionState.waiting &&
                classSnap.connectionState == ConnectionState.waiting) {
              return _buildSkeleton();
            }

            final sessionDocs = sessSnap.data?.docs ?? [];
            final allRows = _buildRows(classroomDocs, sessionDocs);
            final filtered = _applyFilter(allRows);

            return Column(
              children: [
                // KPI strip
                _KpiStrip(rows: allRows, isToday: _isToday),
                const SizedBox(height: 16),
                // Table / cards
                Expanded(
                  child: filtered.isEmpty
                      ? _emptyState()
                      : wide
                          ? _WebTable(rows: filtered)
                          : _MobileList(rows: filtered),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── empty / skeleton ───────────────────────────────────────────────────────

  Widget _emptyState() {
    return const AdminEmptyState(
      icon: Icons.event_note_rounded,
      title: 'Sin sesiones para este filtro',
      message: 'Prueba seleccionando "Todas" o cambia la fecha.',
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: List.generate(
          5,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppDesignSystem.borderRadiusMD,
                border: Border.all(color: _kBorder),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI STRIP
// ─────────────────────────────────────────────────────────────────────────────

class _KpiStrip extends StatelessWidget {
  final List<_SessionRow> rows;
  final bool isToday;

  const _KpiStrip({required this.rows, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final active = rows.where((r) => r.status == _SessionStatus.active).length;
    final finished =
        rows.where((r) => r.status == _SessionStatus.finished).length;
    final notStarted =
        rows.where((r) => r.status == _SessionStatus.notStarted).length;
    final abandoned =
        rows.where((r) => r.status == _SessionStatus.abandoned).length;
    final totalAttendance =
        rows.fold<int>(0, (acc, r) => acc + r.attendanceCount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            AdminKpiCard(
              label: 'Activas',
              value: '$active',
              color: AppDesignSystem.successColor,
              icon: Icons.play_circle_outline_rounded,
              width: 150,
            ),
            const SizedBox(width: 12),
            AdminKpiCard(
              label: 'Finalizadas',
              value: '$finished',
              color: _kPrimary,
              icon: Icons.check_circle_outline_rounded,
              width: 150,
            ),
            const SizedBox(width: 12),
            AdminKpiCard(
              label: 'Sin iniciar',
              value: '$notStarted',
              color: AppDesignSystem.textSecondary,
              icon: Icons.radio_button_unchecked_rounded,
              width: 150,
            ),
            const SizedBox(width: 12),
            AdminKpiCard(
              label: 'Abandonadas',
              value: '$abandoned',
              color: AppDesignSystem.warningColor,
              icon: Icons.warning_amber_rounded,
              alert: abandoned > 0,
              width: 150,
            ),
            const SizedBox(width: 12),
            AdminKpiCard(
              label: isToday ? 'Registros hoy' : 'Registros',
              value: '$totalAttendance',
              color: _kNavy,
              icon: Icons.people_outline_rounded,
              width: 150,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WEB TABLE
// ─────────────────────────────────────────────────────────────────────────────

class _WebTable extends StatelessWidget {
  final List<_SessionRow> rows;
  const _WebTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: AdminUi.cardDecoration(elevated: false),
        child: Column(
          children: [
            // Header (misma spec de columnas que las filas)
            AdminTable.headerRow(_sessionColumns),
            // Rows
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (ctx, i) => _TableRow(
                  row: rows[i],
                  isLast: i == rows.length - 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  final _SessionRow row;
  final bool isLast;
  const _TableRow({required this.row, required this.isLast});

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  String _time(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _duration(DateTime? start, DateTime? end) {
    if (start == null) return '—';
    final finish = end ?? DateTime.now();
    final diff = finish.difference(start);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: AdminTable.rowHeight,
        padding: AdminTable.rowPadding,
        decoration: AdminUi.rowDecoration(
          hovered: _hovered,
          isLast: widget.isLast,
        ),
        child: AdminTable.dataRow(_sessionColumns, [
          // AULA (texto)
          Text(
            r.classroomLabel,
            style: AdminType.bodyStrong,
            overflow: TextOverflow.ellipsis,
          ),
          // DOCENTE (texto)
          Text(
            r.teacherName,
            style:
                AdminType.bodySm.copyWith(color: AppDesignSystem.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
          // ESTADO (chip centrado por la spec)
          _StatusChip(status: r.status),
          // INICIO
          Text(
            _time(r.startTime),
            style:
                AdminType.bodySm.copyWith(color: AppDesignSystem.textSecondary),
          ),
          // FIN
          Text(
            _time(r.endTime),
            style:
                AdminType.bodySm.copyWith(color: AppDesignSystem.textSecondary),
          ),
          // DURACIÓN
          Text(
            _duration(r.startTime, r.endTime),
            style:
                AdminType.bodySm.copyWith(color: AppDesignSystem.textSecondary),
          ),
          // REG. (conteo)
          Row(
            children: [
              if (r.sessionId != null) ...[
                Icon(Icons.people_outline_rounded,
                    size: 13,
                    color: r.attendanceCount > 0
                        ? _kPrimary
                        : AppDesignSystem.textSecondary),
                const SizedBox(width: 4),
              ],
              Text(
                r.sessionId != null ? '${r.attendanceCount}' : '—',
                style: AdminType.bodySm.copyWith(
                  fontWeight: r.attendanceCount > 0
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: r.attendanceCount > 0
                      ? AppDesignSystem.textPrimary
                      : AppDesignSystem.textSecondary,
                ),
              ),
            ],
          ),
          // INFO (pasivo — sin acción real; admin solo observa)
          // TODO(session-detail): Implement per-session attendance list view.
          // Needs: query classrooms/{classroomId}/attendance where sessionId == r.sessionId.
          // TODO(admin-close-session): Admin close button intentionally omitted.
          // Requires secure Cloud Function with trazabilidad (adminUid, reason, timestamp).
          Tooltip(
            message: r.sessionId != null
                ? 'Detalle de sesión (próxima versión)'
                : 'Sin sesión iniciada',
            child: Icon(
              Icons.info_outline_rounded,
              size: 17,
              color: r.sessionId != null
                  ? AppDesignSystem.textSecondary
                  : _kBorder,
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE LIST
// ─────────────────────────────────────────────────────────────────────────────

class _MobileList extends StatelessWidget {
  final List<_SessionRow> rows;
  const _MobileList({required this.rows});

  String _time(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _duration(DateTime? start, DateTime? end) {
    if (start == null) return '—';
    final finish = end ?? DateTime.now();
    final diff = finish.difference(start);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: rows.length,
      itemBuilder: (ctx, i) {
        final r = rows[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppDesignSystem.borderRadiusMD,
              border: Border.all(
                color: r.status == _SessionStatus.abandoned
                    ? AppDesignSystem.warningColor.withValues(alpha: 0.4)
                    : _kBorder,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.classroomLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppDesignSystem.textPrimary,
                        ),
                      ),
                    ),
                    _StatusChip(status: r.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  r.teacherName,
                  style: const TextStyle(
                      fontSize: 12, color: AppDesignSystem.textSecondary),
                ),
                if (r.sessionId != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoChip(
                          icon: Icons.play_arrow_rounded,
                          label: _time(r.startTime)),
                      const SizedBox(width: 8),
                      _InfoChip(
                          icon: Icons.stop_rounded,
                          label: _time(r.endTime)),
                      const SizedBox(width: 8),
                      _InfoChip(
                          icon: Icons.timer_outlined,
                          label: _duration(r.startTime, r.endTime)),
                      const SizedBox(width: 8),
                      _InfoChip(
                          icon: Icons.people_outline_rounded,
                          label: '${r.attendanceCount} reg.'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppDesignSystem.textSecondary),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(
                fontSize: 11.5, color: AppDesignSystem.textSecondary)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final _SessionStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;
    final IconData icon;

    switch (status) {
      case _SessionStatus.active:
        bg = AppDesignSystem.successColor.withValues(alpha: 0.1);
        fg = AppDesignSystem.successColor;
        label = 'Activa';
        icon = Icons.circle;
      case _SessionStatus.finished:
        bg = _kPrimary.withValues(alpha: 0.08);
        fg = _kPrimary;
        label = 'Finalizada';
        icon = Icons.check_circle_rounded;
      case _SessionStatus.notStarted:
        bg = _kBorder;
        fg = AppDesignSystem.textSecondary;
        label = 'No iniciada';
        icon = Icons.radio_button_unchecked_rounded;
      case _SessionStatus.abandoned:
        bg = AppDesignSystem.warningColor.withValues(alpha: 0.12);
        fg = AppDesignSystem.warningColor;
        label = 'Abandonada';
        icon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppDesignSystem.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: status == _SessionStatus.active ? 7 : 11,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

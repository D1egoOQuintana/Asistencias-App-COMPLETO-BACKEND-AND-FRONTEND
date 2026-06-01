import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/admin_service.dart';
import '../../../services/classroom_service.dart';
import '../../../theme/app_design_system.dart';
import '../widgets/admin_ui.dart';

const _kBorder = Color(0xFFE6EAF0);
const _kCanvas = Color(0xFFF4F6FA);

// ── Soft Enterprise (ref. Stitch) — tokens locales del Dashboard ────────────
const _kBg = Color(0xFFF7F9FD); // workspace gris claro (surface Stitch)
const _kCardBorder = Color(0xFFE6EAF0);
const _kInk = Color(0xFF191C1F); // on-surface (titulares)
const _kPrimary = Color(0xFF1976D2);

/// Profundidad "tonal": borde definido + sombra casi imperceptible (no drop
/// shadow pesado). Coherente con el sistema Soft Enterprise de la referencia.
const List<BoxShadow> _kSoftShadow = [
  BoxShadow(color: Color(0x080D1B2A), blurRadius: 3, offset: Offset(0, 1)),
];

BoxDecoration _surfaceDecoration({double radius = 12}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _kCardBorder),
      boxShadow: _kSoftShadow,
    );

// Anchos de columna COMPARTIDOS (header y filas deben coincidir exacto).
// Tabla "Aulas registradas":
const double _cwLead = 36; // avatar
const double _cwGap = 10;
const double _cwEstado = 124;
const double _cwChevron = 28;
// Lista "Actividad reciente":
const double _awTime = 46; // hora (columna propia, derecha)
const double _awStatus = 92; // estado (columna propia, derecha)

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AdminDashboardScreen extends StatefulWidget {
  /// Callback to navigate to a sibling module by index (sidebar order).
  final ValueChanged<int>? onNavigate;

  const AdminDashboardScreen({super.key, this.onNavigate});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with AutomaticKeepAliveClientMixin {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  late final Stream<QuerySnapshot> _teachersStream;
  late final Stream<QuerySnapshot> _classroomsStream;
  late final Stream<QuerySnapshot> _studentsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _activityStream;
  late final Stream<QuerySnapshot> _attendanceTodayStream;
  late final Stream<QuerySnapshot> _lateAttendanceTodayStream;
  late final Stream<QuerySnapshot> _activeSessionsStream;

  @override
  bool get wantKeepAlive => true;

  String get _todayStr =>
      '${_now.year}-${_now.month.toString().padLeft(2, '0')}-${_now.day.toString().padLeft(2, '0')}';

  String get _greeting {
    final h = _now.hour;
    if (h < 12) return 'Buenos días';
    if (h < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  void initState() {
    super.initState();
    _teachersStream = AdminService.getActiveTeachers();
    _classroomsStream = ClassroomService.getAllClassrooms();
    _studentsStream = FirebaseFirestore.instance
        .collection('students')
        .where('isActive', isEqualTo: true)
        .snapshots();
    _activityStream = FirebaseFirestore.instance
        .collection('attendance')
        .orderBy('timestamp', descending: true)
        .limit(8)
        .snapshots();
    _attendanceTodayStream = FirebaseFirestore.instance
        .collection('attendance')
        .where('date', isEqualTo: _todayStr)
        .snapshots();
    // Requires composite index (date + isLate). Graceful fallback if missing.
    _lateAttendanceTodayStream = FirebaseFirestore.instance
        .collection('attendance')
        .where('date', isEqualTo: _todayStr)
        .where('isLate', isEqualTo: true)
        .snapshots()
        .handleError((_) {});
    // Falls back to 0 if collection doesn't exist yet.
    _activeSessionsStream = FirebaseFirestore.instance
        .collection('attendance_sessions')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .handleError((_) {});

    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final firstName = (user?.fullName.trim().isEmpty ?? true)
        ? 'Admin'
        : user!.fullName.trim().split(' ').first;

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppDesignSystem.breakpointDesktop;
    final pad = AdminUi.pagePadding(width);

    return Scaffold(
      backgroundColor: _kBg,
      // Inter SOLO en el subárbol del dashboard (no afecta login ni docente):
      // el texto con estilos sin fontFamily hereda Inter desde aquí.
      body: DefaultTextStyle.merge(
        style: AdminUi.fontBase,
        child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(pad, pad, pad, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GreetingHeader(
              greeting: _greeting,
              firstName: firstName,
              isDesktop: isDesktop,
              onNavigate: widget.onNavigate,
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, thickness: 1, color: _kCardBorder),
            const SizedBox(height: 20),
            _buildKpiGrid(width),
            const SizedBox(height: 20),
            _buildMainSection(width),
          ],
        ),
        ),
      ),
    );
  }

  // ── KPI grid (6 cards, 3 cols desktop / 2 cols otherwise) ─────────────────

  Widget _buildKpiGrid(double width) {
    final kpis = <({String label, IconData icon, Color color, String ctx, Stream<QuerySnapshot> stream})>[
      (
        label: 'Docentes activos',
        icon: Icons.school_rounded,
        color: AdminUi.kpiPrimary, // azul institucional
        ctx: 'Personal registrado',
        stream: _teachersStream,
      ),
      (
        label: 'Aulas activas',
        icon: Icons.class_rounded,
        color: AdminUi.kpiNeutral, // slate (no-semántico)
        ctx: 'Período actual',
        stream: _classroomsStream,
      ),
      (
        label: 'Estudiantes',
        icon: Icons.people_rounded,
        color: AdminUi.kpiInfo, // azul info (no-semántico)
        ctx: 'Matriculados activos',
        stream: _studentsStream,
      ),
      (
        label: 'Asistencias hoy',
        icon: Icons.check_circle_rounded,
        color: AdminUi.success, // semántico real: presencia
        ctx: 'Registradas hoy',
        stream: _attendanceTodayStream,
      ),
      (
        label: 'Tardanzas hoy',
        icon: Icons.schedule_rounded,
        color: AdminUi.warning, // semántico real: tardanza
        ctx: 'Llegadas tardías',
        stream: _lateAttendanceTodayStream,
      ),
      (
        label: 'Sesiones activas',
        icon: Icons.bolt_rounded,
        color: AdminUi.kpiPrimary, // azul institucional (operación)
        ctx: 'En progreso ahora',
        stream: _activeSessionsStream,
      ),
    ];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        // Ref. Stitch: 6 KPIs en UNA fila en desktop; 3 en tablet; 2 en móvil.
        final w = constraints.maxWidth;
        final cols = w >= 1080
            ? 6
            : w >= 720
                ? 3
                : 2;
        const gap = 12.0;
        final cardW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: kpis
              .map(
                (k) => SizedBox(
                  width: cardW,
                  child: _EnterpriseKpiCard(
                    label: k.label,
                    icon: k.icon,
                    color: k.color,
                    contextLabel: k.ctx,
                    stream: k.stream,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  // ── Quick actions ──────────────────────────────────────────────────────────

  // ignore: unused_element
  Widget _buildQuickActions() {
    final actions = <({String label, IconData icon, Color color, int idx})>[
      (label: 'Nuevo\nDocente', icon: Icons.person_add_alt_1_rounded, color: const Color(0xFF1565C0), idx: 1),
      (label: 'Nuevo\nEstudiante', icon: Icons.school_rounded, color: const Color(0xFF00695C), idx: 2),
      (label: 'Nueva\nAula', icon: Icons.add_box_rounded, color: const Color(0xFFE65100), idx: 3),
      (label: 'Ver\nReportes', icon: Icons.bar_chart_rounded, color: const Color(0xFF6A1B9A), idx: 5),
    ];

    return _SectionCard(
      title: 'Acciones rápidas',
      icon: Icons.flash_on_rounded,
      child: Row(
        children: actions.map((a) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _QuickActionButton(
                label: a.label,
                icon: a.icon,
                color: a.color,
                onTap: widget.onNavigate != null
                    ? () => widget.onNavigate!(a.idx)
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Main 60/40 section ─────────────────────────────────────────────────────

  Widget _buildMainSection(double width) {
    final isWide = width >= AppDesignSystem.breakpointTablet;
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: _buildClassroomsSection(showTable: true)),
          const SizedBox(width: 20),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                _buildActivitySection(),
                const SizedBox(height: 20),
                _buildIncidenciasSection(),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        _buildClassroomsSection(showTable: false),
        const SizedBox(height: 20),
        _buildActivitySection(),
        const SizedBox(height: 20),
        _buildIncidenciasSection(),
      ],
    );
  }

  // ── Classrooms section ─────────────────────────────────────────────────────

  Widget _buildClassroomsSection({required bool showTable}) {
    return _SectionCard(
      title: 'Aulas registradas',
      icon: Icons.class_rounded,
      trailing: TextButton.icon(
        onPressed:
            widget.onNavigate != null ? () => widget.onNavigate!(3) : null,
        icon: const Icon(Icons.arrow_forward_rounded, size: 14),
        label: const Text('Ver todas'),
        style: TextButton.styleFrom(
          foregroundColor: AppDesignSystem.primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: _classroomsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _skeletonRows(5);
          }
          if (snapshot.hasError) {
            return const _EmptyState(
              icon: Icons.error_outline_rounded,
              message: 'Error al cargar aulas',
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const _EmptyState(
              icon: Icons.class_outlined,
              message: 'No hay aulas registradas',
            );
          }
          final docs = snapshot.data!.docs.take(6).toList();
          if (showTable) {
            return _ClassroomWebTable(docs: docs);
          }
          return Column(
            children: docs
                .map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ClassroomMobileCard(doc: d),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  // ── Activity feed ──────────────────────────────────────────────────────────

  Widget _buildActivitySection() {
    return _SectionCard(
      title: 'Actividad reciente',
      icon: Icons.bolt_rounded,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _activityStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _skeletonRows(4);
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const _EmptyState(
              icon: Icons.inbox_outlined,
              message: 'Sin actividad reciente',
            );
          }
          return Column(
            children: [
              for (var i = 0; i < docs.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, thickness: 1, color: _kCardBorder),
                Builder(builder: (_) {
                  final data = docs[i].data();
                  final name =
                      (data['studentName'] ?? 'Estudiante').toString();
                  final classroom = (data['classroomName'] ?? '').toString();
                  final isExit = data['exitAt'] != null;
                  final isLate = data['isLate'] as bool? ?? false;
                  final ts = data['timestamp'];
                  var timeLabel = '--:--';
                  if (ts is Timestamp) {
                    final dt = ts.toDate();
                    timeLabel =
                        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                  }
                  return _ActivityRow(
                    name: name,
                    classroom: classroom,
                    time: timeLabel,
                    isExit: isExit,
                    isLate: isLate,
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }

  // ── Incidencias (derived from classrooms stream — no extra query) ───────────

  Widget _buildIncidenciasSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _classroomsStream,
      builder: (context, snapshot) {
        final loading =
            snapshot.connectionState == ConnectionState.waiting;

        final items = <({String label, String reason, bool isWarning})>[];
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? 'Aula').toString();
            final grade = (data['grade'] ?? '').toString();
            final sec = (data['section'] ?? '').toString();
            final display =
                grade.isNotEmpty ? '$name · $grade° $sec' : name;
            final teacherUid = (data['teacherUid'] as String? ?? '').trim();
            final schedule = data['schedule'] as Map?;

            if (teacherUid.isEmpty) {
              items.add((
                label: display,
                reason: 'Sin docente asignado',
                isWarning: true,
              ));
            } else if (schedule == null || schedule.isEmpty) {
              items.add((
                label: display,
                reason: 'Sin horario configurado',
                isWarning: false,
              ));
            }
            // TODO: Aula sin estudiantes — requires N sub-queries; defer to Fase 4.
            // TODO: Sesión activa >4h — requires attendance_sessions timestamp; defer to Fase 4.
          }
        }

        // Badge de conteo real en el header (solo si hay incidencias).
        final Widget? trailing = (!loading && items.isNotEmpty)
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppDesignSystem.warningColor.withValues(alpha: 0.12),
                  borderRadius: AppDesignSystem.borderRadiusFull,
                ),
                child: Text(
                  '${items.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.warningColor,
                  ),
                ),
              )
            : null;

        final Widget body;
        if (loading) {
          body = _skeletonRows(3);
        } else if (items.isEmpty) {
          body = const _EmptyState(
            icon: Icons.check_circle_outline_rounded,
            message: 'Sin incidencias detectadas',
            isSuccess: true,
          );
        } else {
          body = Column(
            children: items.take(5).map((inc) {
              final color = inc.isWarning
                  ? AppDesignSystem.warningColor
                  : AppDesignSystem.infoColor;
              final bg = inc.isWarning
                  ? const Color(0xFFFFF3E0)
                  : const Color(0xFFE3F0FC);
              // Sin side-stripe (anti-patrón): borde completo suave + badge de ícono.
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.22)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          inc.isWarning
                              ? Icons.warning_amber_rounded
                              : Icons.info_outline_rounded,
                          size: 18,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inc.label,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppDesignSystem.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              inc.reason,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        }

        return _SectionCard(
          title: 'Atención requerida',
          icon: Icons.error_outline_rounded,
          trailing: trailing,
          child: body,
        );
      },
    );
  }

  Widget _skeletonRows(int count) => Column(
        children: List.generate(
          count,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _SkeletonRow(),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO BAND — primera impresión: saludo display + acciones rápidas
// ─────────────────────────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  final String greeting;
  final String firstName;
  final bool isDesktop;
  final ValueChanged<int>? onNavigate;

  const _GreetingHeader({
    required this.greeting,
    required this.firstName,
    required this.isDesktop,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    // Saludo sobre el canvas (sin card), display grande con jerarquía Stitch.
    final greetingBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$greeting, $firstName',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: isDesktop ? AdminType.display : AdminType.displaySm,
        ),
        const SizedBox(height: 4),
        Text(
          'Panel institucional de asistencia y control general',
          style: AdminType.bodySm.copyWith(
            color: AdminUi.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    final actions = _QuickActionsRow(onNavigate: onNavigate);

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: greetingBlock),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              actions,
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        greetingBlock,
        const SizedBox(height: 14),
        actions,
      ],
    );
  }
}

/// Acciones rápidas sobrias (sin las 4 cards de colores). Reutiliza onNavigate.
class _QuickActionsRow extends StatelessWidget {
  final ValueChanged<int>? onNavigate;
  const _QuickActionsRow({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        AdminButton.primary(
          label: 'Nuevo docente',
          icon: Icons.person_add_alt_1_rounded,
          onPressed: onNavigate == null ? null : () => onNavigate!(1),
        ),
        AdminButton.secondary(
          label: 'Estudiante',
          icon: Icons.school_outlined,
          onPressed: onNavigate == null ? null : () => onNavigate!(2),
        ),
        AdminButton.secondary(
          label: 'Aula',
          icon: Icons.add_box_outlined,
          onPressed: onNavigate == null ? null : () => onNavigate!(3),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _DateChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _kCanvas,
        borderRadius: AppDesignSystem.borderRadiusFull,
        border: Border.all(color: _kCardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _kPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppDesignSystem.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENTERPRISE KPI CARD
// ─────────────────────────────────────────────────────────────────────────────

class _EnterpriseKpiCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String contextLabel;
  final Stream<QuerySnapshot> stream;

  const _EnterpriseKpiCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.contextLabel,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (ctx, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final hasError = snap.hasError;
        final count = snap.hasData ? snap.data!.docs.length : 0;
        final accent = hasError ? AppDesignSystem.textDisabled : color;

        // KPI compacto (ref. Stitch): etiqueta + ícono arriba, número grande,
        // contexto corto abajo. Denso, sin sparkline (no hay serie real).
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: _surfaceDecoration(radius: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AdminType.label.copyWith(height: 1.2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: accent),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (loading)
                const AdminSkeletonBox(width: 44, height: 26)
              else
                Text(
                  hasError ? 'N/D' : count.toString(),
                  style: AdminType.kpiValue.copyWith(
                    color: hasError ? AppDesignSystem.textDisabled : _kInk,
                  ),
                ),
              const SizedBox(height: 3),
              Text(
                contextLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminType.caption,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION CARD (white card with header)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _surfaceDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: _kPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: AdminType.sectionTitle),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTION BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      borderRadius: AppDesignSystem.borderRadiusMD,
      child: InkWell(
        borderRadius: AppDesignSystem.borderRadiusMD,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: enabled ? color.withValues(alpha: 0.06) : _kCanvas,
            borderRadius: AppDesignSystem.borderRadiusMD,
            border: Border.all(
              color: enabled ? color.withValues(alpha: 0.2) : _kBorder,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: enabled ? color.withValues(alpha: 0.12) : _kCanvas,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: enabled ? color : AppDesignSystem.textDisabled,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: enabled ? AppDesignSystem.textPrimary : AppDesignSystem.textDisabled,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLASSROOM WEB TABLE (desktop / tablet)
// ─────────────────────────────────────────────────────────────────────────────

class _ClassroomWebTable extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;

  const _ClassroomWebTable({required this.docs});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppDesignSystem.borderRadiusMD,
      child: Column(
        children: [
          // Header
          Container(
            color: _kCanvas,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: const Row(
              children: [
                SizedBox(width: _cwLead),
                SizedBox(width: _cwGap),
                Expanded(flex: 4, child: _ColHeader('AULA')),
                Expanded(flex: 3, child: _ColHeader('GRADO / SECCIÓN')),
                // Indent 32px (avatar 24 + gap 8) para alinear "DOCENTE" con
                // el nombre del profesor, no con su mini-avatar.
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(start: 32),
                    child: _ColHeader('DOCENTE'),
                  ),
                ),
                SizedBox(
                  width: _cwEstado,
                  child: Center(child: _ColHeader('ESTADO')),
                ),
                SizedBox(width: _cwChevron),
              ],
            ),
          ),
          // Rows
          ...docs.asMap().entries.map((e) {
            return _ClassroomTableRow(doc: e.value, isLast: e.key == docs.length - 1);
          }),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String text;
  const _ColHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AdminType.overline);
  }
}

class _ClassroomTableRow extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final bool isLast;

  const _ClassroomTableRow({required this.doc, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['name'] ?? 'Aula').toString();
    final grade = (data['grade'] ?? '').toString();
    final section = (data['section'] ?? '').toString();
    final teacherName = (data['teacherName'] ?? '').toString().trim();
    final teacherUid = (data['teacherUid'] as String? ?? '').trim();
    final schedule = data['schedule'] as Map?;
    final initial = grade.isNotEmpty ? grade : name.substring(0, 1).toUpperCase();

    final String status;
    final Color statusColor;
    final Color statusBg;

    if (teacherUid.isEmpty) {
      status = 'Sin docente';
      statusColor = AppDesignSystem.warningColor;
      statusBg = const Color(0xFFFFF3E0);
    } else if (schedule == null || schedule.isEmpty) {
      status = 'Sin horario';
      statusColor = AppDesignSystem.infoColor;
      statusBg = const Color(0xFFE3F0FC);
    } else {
      status = 'Activa';
      statusColor = AppDesignSystem.successColor;
      statusBg = const Color(0xFFE6F4EA);
    }

    return Column(
      children: [
        if (!isLast) Divider(height: 1, color: _kBorder),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppDesignSystem.primaryColor.withValues(alpha: 0.08),
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
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppDesignSystem.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  grade.isNotEmpty ? '$grade° $section' : '—',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppDesignSystem.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: teacherName.isNotEmpty
                            ? AdminUi.slate.withValues(alpha: 0.12)
                            : _kCanvas,
                        shape: BoxShape.circle,
                        border: teacherName.isEmpty
                            ? Border.all(color: _kCardBorder)
                            : null,
                      ),
                      child: teacherName.isNotEmpty
                          ? Text(
                              teacherName[0].toUpperCase(),
                              style: AdminType.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AdminUi.slate,
                              ),
                            )
                          : Icon(Icons.person_off_outlined,
                              size: 12, color: AppDesignSystem.textDisabled),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        teacherName.isNotEmpty ? teacherName : 'Sin asignar',
                        style: AdminType.bodySm.copyWith(
                          color: teacherName.isNotEmpty
                              ? AppDesignSystem.textPrimary
                              : AppDesignSystem.textSecondary,
                          fontWeight: teacherName.isNotEmpty
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: _cwEstado,
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: AppDesignSystem.borderRadiusFull,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: _cwChevron,
                child: Center(
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppDesignSystem.textDisabled,
                  ),
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
// CLASSROOM MOBILE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ClassroomMobileCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;

  const _ClassroomMobileCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['name'] ?? 'Aula').toString();
    final grade = (data['grade'] ?? '').toString();
    final section = (data['section'] ?? '').toString();
    final teacherName = (data['teacherName'] ?? '').toString().trim();
    final teacherUid = (data['teacherUid'] as String? ?? '').trim();
    final initial = grade.isNotEmpty ? grade : name.substring(0, 1).toUpperCase();
    final hasTeacher = teacherUid.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCanvas,
        borderRadius: AppDesignSystem.borderRadiusMD,
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppDesignSystem.primaryColor.withValues(alpha: 0.1),
              borderRadius: AppDesignSystem.borderRadiusSM,
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
                if (grade.isNotEmpty)
                  Text(
                    '$grade° $section',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppDesignSystem.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasTeacher
                  ? const Color(0xFFE6F4EA)
                  : const Color(0xFFFFF3E0),
              borderRadius: AppDesignSystem.borderRadiusFull,
            ),
            child: Text(
              hasTeacher
                  ? (teacherName.isNotEmpty
                      ? teacherName.split(' ').first
                      : 'Activa')
                  : 'Sin docente',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: hasTeacher
                    ? AppDesignSystem.successColor
                    : AppDesignSystem.warningColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY ROW
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityRow extends StatelessWidget {
  final String name;
  final String classroom;
  final String time;
  final bool isExit;
  final bool isLate;

  const _ActivityRow({
    required this.name,
    required this.classroom,
    required this.time,
    required this.isExit,
    required this.isLate,
  });

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    final String chipLabel;
    final Color chipColor;
    final Color chipBg;

    if (isExit) {
      dotColor = AppDesignSystem.textSecondary;
      chipLabel = 'Salida';
      chipColor = AppDesignSystem.textSecondary;
      chipBg = const Color(0xFFF4F6FA);
    } else if (isLate) {
      dotColor = AppDesignSystem.warningColor;
      chipLabel = 'Tardanza';
      chipColor = AppDesignSystem.warningColor;
      chipBg = const Color(0xFFFFF3E0);
    } else {
      dotColor = AppDesignSystem.successColor;
      chipLabel = 'Entrada';
      chipColor = AppDesignSystem.successColor;
      chipBg = const Color(0xFFE6F4EA);
    }

    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          // Avatar con inicial + punto de estado superpuesto (ref. Stitch).
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: chipColor,
                  ),
                ),
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppDesignSystem.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (classroom.isNotEmpty)
                  Text(
                    classroom,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppDesignSystem.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Columna HORA (ancho fijo, alineada a la derecha).
          SizedBox(
            width: _awTime,
            child: Text(
              time,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppDesignSystem.textSecondary,
                fontWeight: FontWeight.w500,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Columna ESTADO (ancho fijo, chip alineado a la derecha).
          SizedBox(
            width: _awStatus,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: AppDesignSystem.borderRadiusFull,
                ),
                child: Text(
                  chipLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: chipColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isSuccess;

  const _EmptyState({
    required this.icon,
    required this.message,
    this.isSuccess = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSuccess
        ? AppDesignSystem.successColor
        : AppDesignSystem.textDisabled;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SkeletonBox(
          width: 36,
          height: 36,
          borderRadius: AppDesignSystem.borderRadiusSM,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBox(
                width: double.infinity,
                height: 12,
                borderRadius: AppDesignSystem.borderRadiusFull,
              ),
              const SizedBox(height: 6),
              _SkeletonBox(
                width: 100,
                height: 10,
                borderRadius: AppDesignSystem.borderRadiusFull,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _SkeletonBox(
          width: 50,
          height: 22,
          borderRadius: AppDesignSystem.borderRadiusFull,
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF1),
        borderRadius: borderRadius ?? AppDesignSystem.borderRadiusSM,
      ),
    );
  }
}

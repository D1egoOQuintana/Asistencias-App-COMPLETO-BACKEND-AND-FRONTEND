import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/classroom_model.dart';
import '../../../models/student_model.dart';
import '../../../services/admin_service_final.dart';
import '../../../services/classroom_service.dart';
import '../../../services/student_service.dart';
import '../../../theme/app_design_system.dart';
import '../widgets/admin_ui.dart';
import '../classrooms/widgets/assign_teacher_dialog.dart';
import '../classrooms/widgets/schedule_config_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers de presentación (top-level para poder usarlos en resolvers)
// ─────────────────────────────────────────────────────────────────────────────

String _classLabel(Map<String, dynamic> d) {
  final g = (d['grade'] ?? '').toString();
  final s = (d['section'] ?? '').toString();
  final n = (d['name'] ?? '').toString();
  if (g.isNotEmpty && s.isNotEmpty) {
    return '$g° $s${n.isNotEmpty ? ' – $n' : ''}';
  }
  return n.isNotEmpty ? n : 'Aula';
}

String _teacherLabel(Map<String, dynamic> d) {
  final fn = (d['firstName'] ?? '').toString().trim();
  final ln = (d['lastName'] ?? '').toString().trim();
  final full = (d['fullName'] ?? '').toString().trim();
  final email = (d['email'] ?? '').toString().trim();
  final composed = '$fn $ln'.trim();
  if (composed.isNotEmpty) return composed;
  if (full.isNotEmpty) return full;
  return email.isNotEmpty ? email : 'Docente';
}

String _studentLabel(Map<String, dynamic> d) {
  final fn = (d['firstName'] ?? '').toString().trim();
  final ln = (d['lastName'] ?? '').toString().trim();
  final name = '$fn $ln'.trim();
  return name.isNotEmpty ? name : 'Estudiante';
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelo
// ─────────────────────────────────────────────────────────────────────────────

enum _Sev { critical, warning, info }

enum _IncidentType {
  aulasSinDocente,
  aulasSinHorario,
  sesionesAbandonadas,
  tardanzasHoy,
  docentesInactivos,
  estudiantesSinAula,
  estudiantesSinQr,
}

class _Incident {
  final _IncidentType type;
  final _Sev severity;
  final IconData icon;
  final String title;
  final String description;
  final String origin;
  final int count;
  final List<String> examples;
  // Documentos afectados reales — permiten resolución inline sin salir de pantalla.
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> affectedDocs;

  /// Si `true` este tipo de incidencia tiene un modal resolutivo inline.
  bool get hasResolver => type != _IncidentType.sesionesAbandonadas &&
      type != _IncidentType.tardanzasHoy;

  const _Incident({
    required this.type,
    required this.severity,
    required this.icon,
    required this.title,
    required this.description,
    required this.origin,
    required this.count,
    required this.examples,
    required this.affectedDocs,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla principal
// ─────────────────────────────────────────────────────────────────────────────

/// Incidencias derivadas de los datos actuales. Cada tarjeta de incidencia
/// incluye un botón "Resolver" que abre un modal inline con la lista exacta
/// de elementos afectados y acciones por ítem — sin redirigir a otra pantalla.
class AdminIncidentsScreen extends StatefulWidget {
  const AdminIncidentsScreen({super.key});

  @override
  State<AdminIncidentsScreen> createState() => _AdminIncidentsScreenState();
}

class _AdminIncidentsScreenState extends State<AdminIncidentsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const int _cap = 500;
  static const int _abandonedHours = 4;
  static const Duration _queryTimeout = Duration(seconds: 3);
  static const Duration _cacheMaxAge = Duration(minutes: 2);

  static List<_Incident>? _cachedIncidents;
  static DateTime? _cachedAt;

  Future<List<_Incident>>? _future;
  bool _silentRefreshing = false;

  @override
  void initState() {
    super.initState();
    final cached = _cachedIncidents;
    if (cached != null) {
      _future = Future.value(cached);
      final cacheAge = DateTime.now().difference(
        _cachedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
      if (cacheAge > _cacheMaxAge) {
        _silentRefresh();
      }
    } else {
      _future = _load();
    }
  }

  String _todayStr() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _safeQueryDocs(
    Query<Map<String, dynamic>> query, {
    Source source = Source.serverAndCache,
  }) async {
    try {
      final snap = await query
          .get(GetOptions(source: source))
          .timeout(_queryTimeout);
      return snap.docs;
    } catch (_) {
      return const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }
  }

  Future<void> _silentRefresh() async {
    if (_silentRefreshing) return;
    _silentRefreshing = true;
    try {
      final fresh = await _load(forceServer: true);
      if (!mounted) return;
      setState(() => _future = Future.value(fresh));
    } finally {
      _silentRefreshing = false;
    }
  }

  Future<List<_Incident>> _load({bool forceServer = false}) async {
    final db = FirebaseFirestore.instance;
    final todayStr = _todayStr();
    final source = forceServer ? Source.server : Source.serverAndCache;

    final futures = <Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>[
      _safeQueryDocs(
        db.collection('classrooms').where('isActive', isEqualTo: true),
        source: source,
      ),
      _safeQueryDocs(
        db.collection('users').where('role', whereIn: ['docente', 'teacher']),
        source: source,
      ),
      _safeQueryDocs(
        db.collection('students').limit(_cap),
        source: source,
      ),
      _safeQueryDocs(
        db.collection('attendance_sessions').where('date', isEqualTo: todayStr),
        source: source,
      ),
      _safeQueryDocs(
        db.collection('attendance').where('date', isEqualTo: todayStr).limit(_cap),
        source: source,
      ),
    ];

    final results = await Future.wait(futures);
    final classrooms = results[0];
    final teachers = results[1];
    final students = results[2];
    final sessions = results[3];
    final attToday = results[4];

    final classroomCount = <String, int>{};
    for (final c in classrooms) {
      final uid = (c.data()['teacherUid'] as String?)?.trim() ?? '';
      if (uid.isNotEmpty) {
        classroomCount[uid] = (classroomCount[uid] ?? 0) + 1;
      }
    }

    final incidents = <_Incident>[];
    final now = DateTime.now();
    final classLabelById = <String, String>{
      for (final c in classrooms) c.id: _classLabel(c.data()),
    };

    // ── Operativas ────────────────────────────────────────────────────────
    final sinDocente = classrooms
        .where((c) =>
            ((c.data()['teacherUid'] as String?) ?? '').trim().isEmpty)
        .toList();
    if (sinDocente.isNotEmpty) {
      incidents.add(_Incident(
        type: _IncidentType.aulasSinDocente,
        severity: _Sev.warning,
        icon: Icons.person_off_outlined,
        title: 'Aulas sin docente asignado',
        description:
            'Estas aulas no tienen docente; los alumnos no pueden registrar asistencia hasta asignarlo.',
        origin: 'Aulas',
        count: sinDocente.length,
        examples:
            sinDocente.take(3).map((c) => _classLabel(c.data())).toList(),
        affectedDocs: sinDocente,
      ));
    }

    final sinHorario = classrooms.where((c) {
      final sch = c.data()['schedule'];
      return sch == null || (sch is Map && sch.isEmpty);
    }).toList();
    if (sinHorario.isNotEmpty) {
      incidents.add(_Incident(
        type: _IncidentType.aulasSinHorario,
        severity: _Sev.warning,
        icon: Icons.schedule_rounded,
        title: 'Aulas sin horario configurado',
        description:
            'Sin horario no se calculan tardanzas ni el cierre de sesión por aula.',
        origin: 'Aulas',
        count: sinHorario.length,
        examples:
            sinHorario.take(3).map((c) => _classLabel(c.data())).toList(),
        affectedDocs: sinHorario,
      ));
    }

    final abandoned = sessions.where((s) {
      final m = s.data();
      final active = m['isActive'] as bool? ?? false;
      final start = (m['startTime'] as Timestamp?)?.toDate();
      return active &&
          start != null &&
          now.difference(start).inHours >= _abandonedHours;
    }).toList();
    if (abandoned.isNotEmpty) {
      incidents.add(_Incident(
        type: _IncidentType.sesionesAbandonadas,
        severity: _Sev.critical,
        icon: Icons.warning_amber_rounded,
        title: 'Sesiones abandonadas',
        description:
            'Sesiones activas hace más de $_abandonedHours h sin cerrar. El docente debería cerrarlas.',
        origin: 'Sesiones',
        count: abandoned.length,
        examples: abandoned
            .take(3)
            .map((s) =>
                classLabelById[
                    (s.data()['classroomId'] ?? '').toString()] ??
                'Aula')
            .toList(),
        affectedDocs: abandoned,
      ));
    }

    final tardanzas =
        attToday.where((a) => a.data()['isLate'] == true).length;
    if (tardanzas > 0) {
      incidents.add(_Incident(
        type: _IncidentType.tardanzasHoy,
        severity: _Sev.info,
        icon: Icons.timer_outlined,
        title: 'Tardanzas registradas hoy',
        description:
            'Llegadas marcadas como tardanza en la jornada de hoy.',
        origin: 'Asistencia',
        count: tardanzas,
        examples: const [],
        affectedDocs: const [],
      ));
    }

    final inactivoConAulas = teachers.where((t) {
      final m = t.data();
      final isActive = m['isActive'] as bool? ?? false;
      final uid = (m['uid'] as String?) ?? t.id;
      return !isActive && (classroomCount[uid] ?? 0) > 0;
    }).toList();
    if (inactivoConAulas.isNotEmpty) {
      incidents.add(_Incident(
        type: _IncidentType.docentesInactivos,
        severity: _Sev.warning,
        icon: Icons.no_accounts_rounded,
        title: 'Docentes inactivos con aulas',
        description:
            'Docentes desactivados que aún tienen aulas asignadas; esas aulas quedan sin docente real.',
        origin: 'Docentes',
        count: inactivoConAulas.length,
        examples: inactivoConAulas
            .take(3)
            .map((t) => _teacherLabel(t.data()))
            .toList(),
        affectedDocs: inactivoConAulas,
      ));
    }

    final sinAulaList = students
        .where((s) =>
            ((s.data()['classroomId'] as String?) ?? '').trim().isEmpty)
        .toList();
    if (sinAulaList.isNotEmpty) {
      incidents.add(_Incident(
        type: _IncidentType.estudiantesSinAula,
        severity: _Sev.warning,
        icon: Icons.group_off_outlined,
        title: 'Estudiantes sin aula',
        description:
            'No están asignados a un aula, por lo que no se les registra asistencia.',
        origin: 'Estudiantes',
        count: sinAulaList.length,
        examples: const [],
        affectedDocs: sinAulaList,
      ));
    }

    final sinQrList = students
        .where((s) =>
            ((s.data()['qrCode'] as String?) ?? '').trim().isEmpty)
        .toList();
    if (sinQrList.isNotEmpty) {
      incidents.add(_Incident(
        type: _IncidentType.estudiantesSinQr,
        severity: _Sev.info,
        icon: Icons.qr_code_2_rounded,
        title: 'Estudiantes sin código QR',
        description:
            'Sin QR no pueden marcar asistencia por escaneo. Regenera el código desde aquí.',
        origin: 'Estudiantes',
        count: sinQrList.length,
        examples: const [],
        affectedDocs: sinQrList,
      ));
    }

    incidents.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    _cachedIncidents = incidents;
    _cachedAt = DateTime.now();
    return incidents;
  }

  void _refresh() => setState(() => _future = _load(forceServer: true));

  // Abre el modal resolutivo correcto según el tipo de incidencia.
  void _openResolver(_Incident incident) {
    switch (incident.type) {
      case _IncidentType.aulasSinDocente:
        showDialog(
          context: context,
          builder: (_) => _AulasSinDocenteResolver(
            docs: incident.affectedDocs,
            onClose: _refresh,
          ),
        );
      case _IncidentType.aulasSinHorario:
        showDialog(
          context: context,
          builder: (_) => _AulasSinHorarioResolver(
            docs: incident.affectedDocs,
            onClose: _refresh,
          ),
        );
      case _IncidentType.docentesInactivos:
        showDialog(
          context: context,
          builder: (_) => _DocentesInactivosResolver(
            docs: incident.affectedDocs,
            onClose: _refresh,
          ),
        );
      case _IncidentType.estudiantesSinAula:
        showDialog(
          context: context,
          builder: (_) => _EstudiantesSinAulaResolver(
            docs: incident.affectedDocs,
            onClose: _refresh,
          ),
        );
      case _IncidentType.estudiantesSinQr:
        showDialog(
          context: context,
          builder: (_) => _EstudiantesSinQrResolver(
            docs: incident.affectedDocs,
            onClose: _refresh,
          ),
        );
      case _IncidentType.sesionesAbandonadas:
      case _IncidentType.tardanzasHoy:
        break; // sin resolver inline
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    final pad = AdminUi.pagePadding(width);

    return DefaultTextStyle.merge(
      style: AdminUi.fontBase,
      child: Container(
        color: AdminUi.surface0,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, pad, pad, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 20),
              FutureBuilder<List<_Incident>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const _IncidentsLoadingState();
                  }
                  final items = snap.data ?? const <_Incident>[];
                  if (items.isEmpty) {
                    return const AdminEmptyState(
                      icon: Icons.verified_rounded,
                      title: 'Sin incidencias detectadas',
                      message:
                          'Aulas, docentes, estudiantes y sesiones están en orden.',
                    );
                  }
                  return _groups(items);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Atención requerida', style: AdminType.display),
              const SizedBox(height: 4),
              Text(
                'Incidencias detectadas a partir de los datos actuales',
                style:
                    AdminType.bodySm.copyWith(color: AdminUi.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        AdminButton.secondary(
          label: 'Actualizar',
          icon: Icons.refresh_rounded,
          onPressed: _refresh,
        ),
      ],
    );
  }

  Widget _groups(List<_Incident> items) {
    final crit = items.where((i) => i.severity == _Sev.critical).toList();
    final warn = items.where((i) => i.severity == _Sev.warning).toList();
    final info = items.where((i) => i.severity == _Sev.info).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Críticas', crit),
        _section('Advertencias', warn),
        _section('Información', info),
      ],
    );
  }

  Widget _section(String title, List<_Incident> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              '$title · ${items.length}',
              style: AdminType.label.copyWith(letterSpacing: 0.3),
            ),
          ),
          ...items.map((i) => _IncidentCard(
                incident: i,
                onResolve: i.hasResolver ? () => _openResolver(i) : null,
              )),
        ],
      ),
    );
  }
}

class _IncidentsLoadingState extends StatelessWidget {
  const _IncidentsLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text(
                'Analizando incidencias...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AdminUi.textSecondary,
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < 3; i++)
          Container(
            height: 90,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AdminUi.surface,
              borderRadius: AppDesignSystem.borderRadiusLG,
              border: Border.all(color: AdminUi.border),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA DE INCIDENCIA
// ─────────────────────────────────────────────────────────────────────────────

class _IncidentCard extends StatelessWidget {
  final _Incident incident;
  final VoidCallback? onResolve;

  const _IncidentCard({
    required this.incident,
    this.onResolve,
  });

  ({Color accent, Color bg}) _colors() {
    switch (incident.severity) {
      case _Sev.critical:
        return (accent: AdminUi.error, bg: AdminUi.errorBg);
      case _Sev.warning:
        return (accent: AdminUi.warning, bg: AdminUi.warningBg);
      case _Sev.info:
        return (accent: AdminUi.info, bg: AdminUi.infoBg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminUi.surface,
        borderRadius: AppDesignSystem.borderRadiusLG,
        border: Border.all(color: AdminUi.border),
        boxShadow: AdminUi.shadowSoft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(11),
              border:
                  Border.all(color: c.accent.withValues(alpha: 0.20)),
            ),
            child: Icon(incident.icon, size: 19, color: c.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        incident.title,
                        style: AdminType.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.12),
                        borderRadius: AppDesignSystem.borderRadiusFull,
                      ),
                      child: Text(
                        '${incident.count}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: c.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  incident.description,
                  style: AdminType.bodySm
                      .copyWith(color: AdminUi.textSecondary),
                ),
                if (incident.examples.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    incident.examples.join(' · ') +
                        (incident.count > incident.examples.length
                            ? ' · +${incident.count - incident.examples.length} más'
                            : ''),
                    style: AdminType.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _originChip(incident.origin),
                    const Spacer(),
                    if (onResolve != null)
                      FilledButton.icon(
                        onPressed: onResolve,
                        style: FilledButton.styleFrom(
                          backgroundColor: c.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          textStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppDesignSystem.borderRadiusMD,
                          ),
                        ),
                        icon: const Icon(Icons.build_outlined, size: 15),
                        label:
                            Text('Resolver (${incident.count})'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _originChip(String origin) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AdminUi.surface2,
        borderRadius: AppDesignSystem.borderRadiusFull,
      ),
      child: Text(
        'Origen: $origin',
        style:
            AdminType.caption.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHELL COMÚN DE RESOLVER (header + body + footer)
// ─────────────────────────────────────────────────────────────────────────────

class _ResolverShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final int remaining;
  final VoidCallback onClose;
  final Widget body;

  const _ResolverShell({
    required this.title,
    required this.subtitle,
    required this.remaining,
    required this.onClose,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: AppDesignSystem.borderRadiusLG),
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: 580, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 18, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AdminType.sectionTitle),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AdminType.bodySm.copyWith(
                              color: AdminUi.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: AdminUi.textSecondary,
                    tooltip: 'Cerrar',
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE6EAF0)),
            // Body
            if (remaining == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 40, color: AdminUi.success),
                    const SizedBox(height: 10),
                    Text(
                      'Todas las incidencias de este tipo\nhan sido resueltas',
                      style: AdminType.bodyStrong.copyWith(
                          color: AdminUi.success),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Flexible(child: body),
            const Divider(height: 1, color: Color(0xFFE6EAF0)),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (remaining > 0)
                    Text(
                      '$remaining pendiente${remaining != 1 ? 's' : ''}',
                      style: AdminType.caption,
                    ),
                  const Spacer(),
                  AdminButton.primary(
                    label: remaining == 0 ? 'Cerrar' : 'Cerrar',
                    onPressed: onClose,
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

// ─────────────────────────────────────────────────────────────────────────────
// RESOLVER 1 — Aulas sin docente
// ─────────────────────────────────────────────────────────────────────────────

class _AulasSinDocenteResolver extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final VoidCallback onClose;

  const _AulasSinDocenteResolver(
      {required this.docs, required this.onClose});

  @override
  State<_AulasSinDocenteResolver> createState() =>
      _AulasSinDocenteResolverState();
}

class _AulasSinDocenteResolverState
    extends State<_AulasSinDocenteResolver> {
  late List<QueryDocumentSnapshot<Map<String, dynamic>>> _items;
  bool _anyResolved = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.docs);
  }

  void _close() {
    Navigator.of(context).pop();
    if (_anyResolved) widget.onClose();
  }

  void _removeById(String id) {
    setState(() {
      _items.removeWhere((d) => d.id == id);
      _anyResolved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ResolverShell(
      title: 'Asignar docentes',
      subtitle:
          '${_items.length} aula${_items.length != 1 ? 's' : ''} sin docente asignado',
      remaining: _items.length,
      onClose: _close,
      body: ListView.separated(
        shrinkWrap: true,
        itemCount: _items.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFE6EAF0)),
        itemBuilder: (ctx, i) {
          final doc = _items[i];
          final classroom = ClassroomModel.fromFirestore(doc);
          return _AulaRow(
            key: ValueKey(doc.id),
            label: _classLabel(doc.data()),
            grade: (doc.data()['grade'] ?? '').toString(),
            actionLabel: 'Asignar docente',
            actionIcon: Icons.person_add_outlined,
            onAction: () async {
              await showDialog(
                context: context,
                builder: (_) =>
                    AssignTeacherDialog(classroom: classroom),
              );
              // Re-verificar si el aula ya tiene docente asignado.
              try {
                final snap = await FirebaseFirestore.instance
                    .collection('classrooms')
                    .doc(doc.id)
                    .get();
                final uid =
                    ((snap.data()?['teacherUid'] as String?) ?? '')
                        .trim();
                if (uid.isNotEmpty && mounted) _removeById(doc.id);
              } catch (_) {}
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESOLVER 2 — Aulas sin horario
// ─────────────────────────────────────────────────────────────────────────────

class _AulasSinHorarioResolver extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final VoidCallback onClose;

  const _AulasSinHorarioResolver(
      {required this.docs, required this.onClose});

  @override
  State<_AulasSinHorarioResolver> createState() =>
      _AulasSinHorarioResolverState();
}

class _AulasSinHorarioResolverState
    extends State<_AulasSinHorarioResolver> {
  late List<QueryDocumentSnapshot<Map<String, dynamic>>> _items;
  bool _anyResolved = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.docs);
  }

  void _close() {
    Navigator.of(context).pop();
    if (_anyResolved) widget.onClose();
  }

  void _removeById(String id) {
    setState(() {
      _items.removeWhere((d) => d.id == id);
      _anyResolved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ResolverShell(
      title: 'Configurar horarios',
      subtitle:
          '${_items.length} aula${_items.length != 1 ? 's' : ''} sin horario configurado',
      remaining: _items.length,
      onClose: _close,
      body: ListView.separated(
        shrinkWrap: true,
        itemCount: _items.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFE6EAF0)),
        itemBuilder: (ctx, i) {
          final doc = _items[i];
          final classroom = ClassroomModel.fromFirestore(doc);
          return _AulaRow(
            key: ValueKey(doc.id),
            label: _classLabel(doc.data()),
            grade: (doc.data()['grade'] ?? '').toString(),
            actionLabel: 'Configurar horario',
            actionIcon: Icons.schedule_rounded,
            onAction: () async {
              await showDialog(
                context: context,
                builder: (_) =>
                    ScheduleConfigDialog(classroom: classroom),
              );
              // Re-verificar si ya tiene horario.
              try {
                final snap = await FirebaseFirestore.instance
                    .collection('classrooms')
                    .doc(doc.id)
                    .get();
                final sch = snap.data()?['schedule'];
                final hasSchedule =
                    sch != null && (sch is Map && sch.isNotEmpty);
                if (hasSchedule && mounted) _removeById(doc.id);
              } catch (_) {}
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESOLVER 3 — Docentes inactivos con aulas
// ─────────────────────────────────────────────────────────────────────────────

class _DocentesInactivosResolver extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final VoidCallback onClose;

  const _DocentesInactivosResolver(
      {required this.docs, required this.onClose});

  @override
  State<_DocentesInactivosResolver> createState() =>
      _DocentesInactivosResolverState();
}

class _DocentesInactivosResolverState
    extends State<_DocentesInactivosResolver> {
  late List<QueryDocumentSnapshot<Map<String, dynamic>>> _items;
  bool _anyResolved = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.docs);
  }

  void _close() {
    Navigator.of(context).pop();
    if (_anyResolved) widget.onClose();
  }

  void _removeById(String id) {
    setState(() {
      _items.removeWhere((d) => d.id == id);
      _anyResolved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ResolverShell(
      title: 'Activar docentes',
      subtitle:
          '${_items.length} docente${_items.length != 1 ? 's' : ''} inactivo${_items.length != 1 ? 's' : ''} con aulas asignadas',
      remaining: _items.length,
      onClose: _close,
      body: ListView.separated(
        shrinkWrap: true,
        itemCount: _items.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFE6EAF0)),
        itemBuilder: (ctx, i) {
          final doc = _items[i];
          return _DocenteActivarRow(
            key: ValueKey(doc.id),
            doc: doc,
            onActivated: () => _removeById(doc.id),
          );
        },
      ),
    );
  }
}

class _DocenteActivarRow extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onActivated;

  const _DocenteActivarRow(
      {super.key, required this.doc, required this.onActivated});

  @override
  State<_DocenteActivarRow> createState() => _DocenteActivarRowState();
}

class _DocenteActivarRowState extends State<_DocenteActivarRow> {
  bool _loading = false;

  Future<void> _activate() async {
    setState(() => _loading = true);
    final teacherUid =
        (widget.doc.data()['uid'] as String?) ?? widget.doc.id;
    final ok = await AdminService.toggleTeacherStatus(
      teacherUid: teacherUid,
      isActive: true,
    );
    if (!mounted) return;
    if (ok) {
      widget.onActivated();
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo activar el docente'),
        backgroundColor: AdminUi.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final name = _teacherLabel(data);
    final email = (data['email'] ?? '').toString();
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: AdminUi.warningBg,
            child: Text(initial,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AdminUi.warning,
                    fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AdminType.bodyStrong,
                    overflow: TextOverflow.ellipsis),
                if (email.isNotEmpty)
                  Text(email,
                      style: AdminType.caption,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (_loading)
            const SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(strokeWidth: 2))
          else
            AdminButton.secondary(
              label: 'Activar',
              icon: Icons.check_circle_outline_rounded,
              onPressed: _activate,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESOLVER 4 — Estudiantes sin aula
// ─────────────────────────────────────────────────────────────────────────────

class _EstudiantesSinAulaResolver extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final VoidCallback onClose;

  const _EstudiantesSinAulaResolver(
      {required this.docs, required this.onClose});

  @override
  State<_EstudiantesSinAulaResolver> createState() =>
      _EstudiantesSinAulaResolverState();
}

class _EstudiantesSinAulaResolverState
    extends State<_EstudiantesSinAulaResolver> {
  late List<QueryDocumentSnapshot<Map<String, dynamic>>> _items;
  List<QueryDocumentSnapshot>? _classrooms;
  bool _loadingClassrooms = true;
  bool _anyResolved = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.docs);
    _loadClassrooms();
  }

  Future<void> _loadClassrooms() async {
    try {
      final snap =
          await ClassroomService.getAllClassrooms().first;
      if (mounted) {
        setState(() {
          _classrooms = snap.docs;
          _loadingClassrooms = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingClassrooms = false);
    }
  }

  void _close() {
    Navigator.of(context).pop();
    if (_anyResolved) widget.onClose();
  }

  void _removeById(String id) {
    setState(() {
      _items.removeWhere((d) => d.id == id);
      _anyResolved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingClassrooms) {
      return Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: AppDesignSystem.borderRadiusLG),
        child: const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return _ResolverShell(
      title: 'Asignar aulas',
      subtitle:
          '${_items.length} estudiante${_items.length != 1 ? 's' : ''} sin aula asignada',
      remaining: _items.length,
      onClose: _close,
      body: ListView.separated(
        shrinkWrap: true,
        itemCount: _items.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFE6EAF0)),
        itemBuilder: (ctx, i) {
          final doc = _items[i];
          return _EstudianteSinAulaRow(
            key: ValueKey(doc.id),
            doc: doc,
            classrooms: _classrooms ?? const [],
            onAssigned: () => _removeById(doc.id),
          );
        },
      ),
    );
  }
}

class _EstudianteSinAulaRow extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final List<QueryDocumentSnapshot> classrooms;
  final VoidCallback onAssigned;

  const _EstudianteSinAulaRow({
    super.key,
    required this.doc,
    required this.classrooms,
    required this.onAssigned,
  });

  @override
  State<_EstudianteSinAulaRow> createState() =>
      _EstudianteSinAulaRowState();
}

class _EstudianteSinAulaRowState
    extends State<_EstudianteSinAulaRow> {
  String? _selectedId;
  bool _loading = false;

  Future<void> _assign() async {
    if (_selectedId == null) return;
    setState(() => _loading = true);
    final ok = await StudentService.transferStudent(
      studentId: widget.doc.id,
      newClassroomId: _selectedId!,
    );
    if (!mounted) return;
    if (ok) {
      widget.onAssigned();
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo asignar el aula'),
        backgroundColor: AdminUi.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _studentLabel(widget.doc.data());
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : '?';

    final items = widget.classrooms.map((c) {
      final cd = c.data() as Map<String, dynamic>;
      return DropdownMenuItem<String>(
        value: c.id,
        child: Text(_classLabel(cd),
            style: const TextStyle(fontSize: 13)),
      );
    }).toList();

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: AdminUi.infoBg,
            child: Text(initial,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AdminUi.primary,
                    fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: AdminType.bodyStrong,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedId,
              items: items,
              onChanged: (v) =>
                  setState(() => _selectedId = v),
              hint: const Text('Aula',
                  style: TextStyle(fontSize: 12)),
              decoration: AdminInputs.decoration(),
            ),
          ),
          const SizedBox(width: 6),
          if (_loading)
            const SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(strokeWidth: 2))
          else
            Tooltip(
              message: 'Asignar',
              child: IconButton(
                icon: const Icon(Icons.check_circle_rounded),
                iconSize: 22,
                color: _selectedId != null
                    ? AdminUi.primary
                    : AdminUi.textHint,
                onPressed:
                    _selectedId != null ? _assign : null,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESOLVER 5 — Estudiantes sin QR
// ─────────────────────────────────────────────────────────────────────────────

class _EstudiantesSinQrResolver extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final VoidCallback onClose;

  const _EstudiantesSinQrResolver(
      {required this.docs, required this.onClose});

  @override
  State<_EstudiantesSinQrResolver> createState() =>
      _EstudiantesSinQrResolverState();
}

class _EstudiantesSinQrResolverState
    extends State<_EstudiantesSinQrResolver> {
  late List<QueryDocumentSnapshot<Map<String, dynamic>>> _items;
  bool _anyResolved = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.docs);
  }

  void _close() {
    Navigator.of(context).pop();
    if (_anyResolved) widget.onClose();
  }

  void _removeById(String id) {
    setState(() {
      _items.removeWhere((d) => d.id == id);
      _anyResolved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ResolverShell(
      title: 'Regenerar códigos QR',
      subtitle:
          '${_items.length} estudiante${_items.length != 1 ? 's' : ''} sin código QR',
      remaining: _items.length,
      onClose: _close,
      body: ListView.separated(
        shrinkWrap: true,
        itemCount: _items.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFE6EAF0)),
        itemBuilder: (ctx, i) {
          final doc = _items[i];
          return _QrRegenerateRow(
            key: ValueKey(doc.id),
            doc: doc,
            onRegenerated: () => _removeById(doc.id),
          );
        },
      ),
    );
  }
}

class _QrRegenerateRow extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onRegenerated;

  const _QrRegenerateRow(
      {super.key,
      required this.doc,
      required this.onRegenerated});

  @override
  State<_QrRegenerateRow> createState() =>
      _QrRegenerateRowState();
}

class _QrRegenerateRowState extends State<_QrRegenerateRow> {
  bool _loading = false;

  Future<void> _regenerate() async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.doc.id)
          .update({
        'qrCode': StudentModel.generateQRCode(),
        'updatedAt':
            Timestamp.fromDate(DateTime.now()),
      });
      if (mounted) widget.onRegenerated();
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
          content: Text('No se pudo regenerar el QR'),
          backgroundColor: AdminUi.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _studentLabel(widget.doc.data());
    final dni =
        (widget.doc.data()['dni'] ?? '').toString();
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: AdminUi.infoBg,
            child: Text(initial,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AdminUi.primary,
                    fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AdminType.bodyStrong,
                    overflow: TextOverflow.ellipsis),
                if (dni.isNotEmpty)
                  Text('DNI: $dni',
                      style: AdminType.caption),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (_loading)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2))
          else
            AdminButton.secondary(
              label: 'Regenerar QR',
              icon: Icons.qr_code_2_rounded,
              onPressed: _regenerate,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILA GENÉRICA DE AULA (compartida por Resolvers 1 y 2)
// ─────────────────────────────────────────────────────────────────────────────

class _AulaRow extends StatelessWidget {
  final String label;
  final String grade;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  const _AulaRow({
    super.key,
    required this.label,
    required this.grade,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        grade.isNotEmpty ? grade.substring(0, 1) : 'A';

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AdminUi.infoBg,
              borderRadius: AppDesignSystem.borderRadiusSM,
            ),
            child: Text(initial,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AdminUi.primary,
                    fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: AdminType.bodyStrong,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),
          AdminButton.secondary(
            label: actionLabel,
            icon: actionIcon,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../services/classroom_service.dart';
import '../../../theme/app_design_system.dart';
import '../widgets/admin_ui.dart';
import 'csv_download_io.dart'
    if (dart.library.html) 'csv_download_web.dart'
    as csv_download;

const _kBorder = Color(0xFFE6EAF0);
const _kPrimary = Color(0xFF1976D2);

const List<AdminColumn> _classroomColumns = [
  AdminColumn.flex(5, header: 'AULA'),
  AdminColumn.fixed(78, header: 'ASIST.'),
  AdminColumn.fixed(78, header: 'TARD.'),
  AdminColumn.fixed(90, header: '% TARD.'),
  AdminColumn.flex(4, header: 'VOLUMEN'),
  AdminColumn.fixed(94, align: Alignment.centerRight, header: 'DETALLE'),
];

enum _RangePreset { today, sevenDays, thirtyDays, custom }

enum _AttendanceStatusKind { present, late, absent }

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  _RangePreset _preset = _RangePreset.sevenDays;

  late final Stream<QuerySnapshot> _classroomsStream;
  late final Stream<QuerySnapshot> _studentsStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _attendanceStream;

  final Set<String> _expandedClassrooms = <String>{};
  String? _savingStudentKey;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _rangeEnd = today;
    _rangeStart = today.subtract(const Duration(days: 6));

    _classroomsStream = ClassroomService.getAllClassrooms();
    _studentsStream = FirebaseFirestore.instance
        .collection('students')
        .where('isActive', isEqualTo: true)
        .snapshots();
    _attendanceStream = _buildAttendanceStream();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildAttendanceStream() {
    final startKey = _dateKey(_rangeStart);
    final endKey = _dateKey(_rangeEnd);

    return FirebaseFirestore.instance
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: startKey)
        .where('date', isLessThanOrEqualTo: endKey)
        .snapshots();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dateKey(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String _dateLabel(DateTime d) {
    const months = [
      '',
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month]} ${d.year}';
  }

  String _rangeLabel() =>
      '${_dateLabel(_rangeStart)} - ${_dateLabel(_rangeEnd)}';

  void _applyPreset(_RangePreset preset) {
    final today = _dateOnly(DateTime.now());
    DateTime start = _rangeStart;
    DateTime end = _rangeEnd;

    switch (preset) {
      case _RangePreset.today:
        start = today;
        end = today;
      case _RangePreset.sevenDays:
        end = today;
        start = today.subtract(const Duration(days: 6));
      case _RangePreset.thirtyDays:
        end = today;
        start = today.subtract(const Duration(days: 29));
      case _RangePreset.custom:
        break;
    }

    setState(() {
      _preset = preset;
      _rangeStart = start;
      _rangeEnd = end;
      _attendanceStream = _buildAttendanceStream();
      _expandedClassrooms.clear();
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
      firstDate: DateTime(DateTime.now().year - 2, 1, 1),
      lastDate: _dateOnly(DateTime.now()),
      helpText: 'Seleccionar rango',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      fieldStartHintText: 'Inicio',
      fieldEndHintText: 'Fin',
    );

    if (picked == null || !mounted) return;
    setState(() {
      _preset = _RangePreset.custom;
      _rangeStart = _dateOnly(picked.start);
      _rangeEnd = _dateOnly(picked.end);
      _attendanceStream = _buildAttendanceStream();
      _expandedClassrooms.clear();
    });
  }

  _AttendanceStatusKind _statusFromRaw(dynamic raw) {
    final status = raw?.toString().toLowerCase().trim() ?? '';
    if (status == 'late' || status == 'tarde' || status == 'tardanza') {
      return _AttendanceStatusKind.late;
    }
    if (status == 'absent' || status == 'ausente') {
      return _AttendanceStatusKind.absent;
    }
    return _AttendanceStatusKind.present;
  }

  String _statusToStoredValue(_AttendanceStatusKind status) {
    switch (status) {
      case _AttendanceStatusKind.late:
        return 'late';
      case _AttendanceStatusKind.absent:
        return 'absent';
      case _AttendanceStatusKind.present:
        return 'present';
    }
  }

  String _statusLabel(_AttendanceStatusKind status) {
    switch (status) {
      case _AttendanceStatusKind.late:
        return 'Tardanza';
      case _AttendanceStatusKind.absent:
        return 'Ausente';
      case _AttendanceStatusKind.present:
        return 'Presente';
    }
  }

  ({Color bg, Color fg}) _statusColors(_AttendanceStatusKind status) {
    switch (status) {
      case _AttendanceStatusKind.present:
        return (
          bg: AppDesignSystem.successColor.withValues(alpha: 0.1),
          fg: AppDesignSystem.successColor,
        );
      case _AttendanceStatusKind.late:
        return (
          bg: AppDesignSystem.warningColor.withValues(alpha: 0.12),
          fg: AppDesignSystem.warningColor,
        );
      case _AttendanceStatusKind.absent:
        return (
          bg: AppDesignSystem.errorColor.withValues(alpha: 0.08),
          fg: AppDesignSystem.errorColor,
        );
    }
  }

  DateTime _extractTimestamp(Map<String, dynamic> data) {
    final candidates = [
      data['timestamp'],
      data['entryAt'],
      data['updatedAt'],
      data['editedAt'],
      data['createdAt'],
    ];
    for (final value in candidates) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
    }
    final now = DateTime.now();
    return now;
  }

  String _extractDateKey(Map<String, dynamic> data) {
    final direct = (data['date'] ?? '').toString().trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(direct)) return direct;
    final ts = _extractTimestamp(data);
    return _dateKey(ts);
  }

  List<_ClassroomMeta> _parseClassrooms(List<QueryDocumentSnapshot> docs) {
    final rows = <_ClassroomMeta>[];
    for (final doc in docs) {
      final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
      final grade = (data['grade'] ?? '').toString().trim();
      final section = (data['section'] ?? '').toString().trim();
      final name = (data['name'] ?? '').toString().trim();

      final label = grade.isNotEmpty
          ? '$grade° $section${name.isNotEmpty ? ' - $name' : ''}'
          : (name.isNotEmpty ? name : doc.id);

      rows.add(
        _ClassroomMeta(
          id: doc.id,
          label: label,
          teacherName: (data['teacherName'] ?? '').toString().trim(),
          grade: grade,
          section: section,
        ),
      );
    }

    rows.sort((a, b) {
      final gradeCmp = a.grade.compareTo(b.grade);
      if (gradeCmp != 0) return gradeCmp;
      final sectionCmp = a.section.compareTo(b.section);
      if (sectionCmp != 0) return sectionCmp;
      return a.label.compareTo(b.label);
    });
    return rows;
  }

  List<_StudentMeta> _parseStudents(List<QueryDocumentSnapshot> docs) {
    final rows = <_StudentMeta>[];
    for (final doc in docs) {
      final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
      final firstName = (data['firstName'] ?? '').toString().trim();
      final lastName = (data['lastName'] ?? '').toString().trim();
      final fullName = '$firstName $lastName'.trim();
      rows.add(
        _StudentMeta(
          id: doc.id,
          fullName: fullName.isNotEmpty ? fullName : 'Estudiante',
          dni: (data['dni'] ?? '').toString().trim(),
          classroomId: (data['classroomId'] ?? '').toString().trim(),
        ),
      );
    }
    return rows;
  }

  List<_AttendanceRecord> _parseAttendance(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final rows = <_AttendanceRecord>[];
    for (final doc in docs) {
      final data = doc.data();
      final studentId = (data['studentId'] ?? '').toString().trim();
      if (studentId.isEmpty) continue;
      final classroomId = (data['classroomId'] ?? '').toString().trim();
      if (classroomId.isEmpty) continue;

      final dateKey = _extractDateKey(data);
      rows.add(
        _AttendanceRecord(
          docId: doc.id,
          studentId: studentId,
          classroomId: classroomId,
          classroomName: (data['classroomName'] ?? '').toString().trim(),
          studentName: (data['studentName'] ?? '').toString().trim(),
          dateKey: dateKey,
          status: _statusFromRaw(data['status']),
          timestamp: _extractTimestamp(data),
          hasExit: data['exitAt'] != null,
          raw: data,
        ),
      );
    }
    return rows;
  }

  _ReportData _buildReportData({
    required List<_ClassroomMeta> classrooms,
    required List<_StudentMeta> students,
    required List<_AttendanceRecord> records,
  }) {
    final classroomMap = <String, _ClassroomMeta>{
      for (final c in classrooms) c.id: c,
    };

    for (final r in records) {
      classroomMap.putIfAbsent(
        r.classroomId,
        () => _ClassroomMeta(
          id: r.classroomId,
          label: r.classroomName.isNotEmpty
              ? r.classroomName
              : 'Aula no encontrada (${r.classroomId})',
          teacherName: '',
          grade: '',
          section: '',
        ),
      );
    }

    final studentsByClassroom = <String, List<_StudentMeta>>{};
    for (final s in students) {
      if (s.classroomId.isEmpty) continue;
      (studentsByClassroom[s.classroomId] ??= <_StudentMeta>[]).add(s);
    }
    for (final list in studentsByClassroom.values) {
      list.sort((a, b) => a.fullName.compareTo(b.fullName));
    }

    final recordsByClassroom = <String, List<_AttendanceRecord>>{};
    for (final r in records) {
      (recordsByClassroom[r.classroomId] ??= <_AttendanceRecord>[]).add(r);
    }

    final todayKey = _dateKey(_rangeEnd);
    final rows = <_ClassroomReportRow>[];

    for (final classroom in classroomMap.values) {
      final classroomRecords = recordsByClassroom[classroom.id] ?? const [];
      final classroomStudents = studentsByClassroom[classroom.id] ?? const [];

      final distinctWithRecords = <String>{};
      final latestDayRecordByStudent = <String, _AttendanceRecord>{};
      final latestRangeRecordByStudent = <String, _AttendanceRecord>{};

      for (final record in classroomRecords) {
        distinctWithRecords.add(record.studentId);

        final latestRange = latestRangeRecordByStudent[record.studentId];
        if (latestRange == null ||
            record.timestamp.isAfter(latestRange.timestamp)) {
          latestRangeRecordByStudent[record.studentId] = record;
        }

        if (record.dateKey == todayKey) {
          final latestToday = latestDayRecordByStudent[record.studentId];
          if (latestToday == null ||
              record.timestamp.isAfter(latestToday.timestamp)) {
            latestDayRecordByStudent[record.studentId] = record;
          }
        }
      }

      final withoutRecords = classroomStudents
          .where((s) => !distinctWithRecords.contains(s.id))
          .toList();

      final entriesCount = classroomRecords
          .where((r) => r.status != _AttendanceStatusKind.absent)
          .length;
      final lateCount = classroomRecords
          .where((r) => r.status == _AttendanceStatusKind.late)
          .length;
      final exitCount = classroomRecords.where((r) => r.hasExit).length;
      final latePercent = entriesCount > 0
          ? (lateCount / entriesCount) * 100
          : 0.0;

      rows.add(
        _ClassroomReportRow(
          classroom: classroom,
          students: classroomStudents,
          records: classroomRecords,
          studentsWithoutRecords: withoutRecords,
          latestDayRecordByStudent: latestDayRecordByStudent,
          latestRangeRecordByStudent: latestRangeRecordByStudent,
          entriesCount: entriesCount,
          lateCount: lateCount,
          exitCount: exitCount,
          latePercent: latePercent,
        ),
      );
    }

    rows.sort((a, b) => a.classroom.label.compareTo(b.classroom.label));
    final maxEntries = rows.fold<int>(
      0,
      (acc, r) => math.max(acc, r.entriesCount),
    );

    final totalRecords = records.length;
    final totalEntries = records
        .where((r) => r.status != _AttendanceStatusKind.absent)
        .length;
    final totalLate = records
        .where((r) => r.status == _AttendanceStatusKind.late)
        .length;
    final totalExits = records.where((r) => r.hasExit).length;
    final totalLatePercent = totalEntries > 0
        ? (totalLate / totalEntries) * 100
        : 0.0;

    return _ReportData(
      rows: rows,
      maxEntries: maxEntries,
      totalRecords: totalRecords,
      totalEntries: totalEntries,
      totalLate: totalLate,
      totalExits: totalExits,
      totalLatePercent: totalLatePercent,
    );
  }

  Future<void> _exportCsv(_ReportData data) async {
    final buffer = StringBuffer()
      ..writeln(
        'aula,docente,asistencias,tardanzas,porcentaje_tardanza,registros,estudiantes_sin_registro',
      );
    for (final row in data.rows) {
      buffer.writeln(
        '"${row.classroom.label.replaceAll('"', '""')}",'
        '"${(row.classroom.teacherName.isEmpty ? 'Sin docente' : row.classroom.teacherName).replaceAll('"', '""')}",'
        '${row.entriesCount},'
        '${row.lateCount},'
        '${row.latePercent.toStringAsFixed(1)},'
        '${row.records.length},'
        '${row.studentsWithoutRecords.length}',
      );
    }

    final filename =
        'reporte_asistencia_${_dateKey(_rangeStart)}_a_${_dateKey(_rangeEnd)}.csv';
    csv_download.downloadCsv(filename, buffer.toString());

    if (!mounted) return;
    AdminFeedback.success(context, 'CSV exportado correctamente');
  }

  Future<void> _exportCurrentRangeCsv() async {
    try {
      final startKey = _dateKey(_rangeStart);
      final endKey = _dateKey(_rangeEnd);

      final classroomsFuture = FirebaseFirestore.instance
          .collection('classrooms')
          .where('isActive', isEqualTo: true)
          .get();
      final studentsFuture = FirebaseFirestore.instance
          .collection('students')
          .where('isActive', isEqualTo: true)
          .get();
      final attendanceFuture = FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: startKey)
          .where('date', isLessThanOrEqualTo: endKey)
          .get();

      final results = await Future.wait([
        classroomsFuture,
        studentsFuture,
        attendanceFuture,
      ]);
      final classroomsSnap = results[0];
      final studentsSnap = results[1];
      final attendanceSnap = results[2];

      final data = _buildReportData(
        classrooms: _parseClassrooms(classroomsSnap.docs),
        students: _parseStudents(studentsSnap.docs),
        records: _parseAttendance(attendanceSnap.docs),
      );

      await _exportCsv(data);
    } catch (e) {
      if (!mounted) return;
      AdminFeedback.error(context, 'No se pudo exportar: $e');
    }
  }

  Future<void> _saveAttendance({
    required _ClassroomMeta classroom,
    required _StudentMeta student,
    required _AttendanceStatusKind status,
    _AttendanceRecord? previous,
  }) async {
    final dayKey = _dateKey(_rangeEnd);
    final studentDocId = '${student.id}_$dayKey';
    final savingKey = '${classroom.id}_${student.id}';

    setState(() => _savingStudentKey = savingKey);
    try {
      final docId = previous?.docId ?? studentDocId;
      final ref = FirebaseFirestore.instance
          .collection('classrooms')
          .doc(classroom.id)
          .collection('attendance')
          .doc(docId);

      final payload = <String, dynamic>{
        'classroomId': classroom.id,
        'classroomName': classroom.label,
        'studentId': student.id,
        'studentName': student.fullName,
        'studentDni': student.dni,
        'date': dayKey,
        'status': _statusToStoredValue(status),
        'timestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'editedAt': FieldValue.serverTimestamp(),
        'source': 'manual_edit',
        'eventDriven': false,
        'qrCodeScanned': FieldValue.delete(),
        'qrCode': FieldValue.delete(),
        'qr': FieldValue.delete(),
        'codigoQr': FieldValue.delete(),
      };

      if (status == _AttendanceStatusKind.absent) {
        payload['entryAt'] = null;
      } else {
        payload['entryAt'] =
            previous?.raw['entryAt'] ?? FieldValue.serverTimestamp();
      }

      await ref.set(payload, SetOptions(merge: true));

      if (!mounted) return;
      AdminFeedback.success(
        context,
        'Asistencia de ${student.fullName} actualizada sin notificar Telegram',
      );
    } catch (e) {
      if (!mounted) return;
      AdminFeedback.error(context, 'No se pudo actualizar: $e');
    } finally {
      if (mounted) setState(() => _savingStudentKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 700;

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
              child: const AdminCompactHeader(
                title: 'Resumen de asistencia',
                subtitle: 'Vista institucional por aulas y rango de fechas',
              ),
            ),
            const SizedBox(height: 12),
            _buildToolbar(isWide),
            const SizedBox(height: 12),
            Expanded(child: _buildBody(width)),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(bool isWide) {
    final content = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AdminFilterChip(
          label: 'Hoy',
          selected: _preset == _RangePreset.today,
          onTap: () => _applyPreset(_RangePreset.today),
        ),
        AdminFilterChip(
          label: '7 días',
          selected: _preset == _RangePreset.sevenDays,
          onTap: () => _applyPreset(_RangePreset.sevenDays),
        ),
        AdminFilterChip(
          label: '30 días',
          selected: _preset == _RangePreset.thirtyDays,
          onTap: () => _applyPreset(_RangePreset.thirtyDays),
        ),
        InkWell(
          borderRadius: AppDesignSystem.borderRadiusFull,
          onTap: _pickCustomRange,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppDesignSystem.borderRadiusFull,
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: AppDesignSystem.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _rangeLabel(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppDesignSystem.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminUi.pagePaddingTablet,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: AdminUi.cardDecoration(elevated: false),
        child: isWide
            ? Row(
                children: [
                  Expanded(child: content),
                  const SizedBox(width: 12),
                  AdminButton.secondary(
                    label: 'Exportar CSV',
                    icon: Icons.download_rounded,
                    onPressed: _exportCurrentRangeCsv,
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  content,
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      height: 38,
                      child: AdminButton.secondary(
                        label: 'Exportar CSV',
                        icon: Icons.download_rounded,
                        onPressed: _exportCurrentRangeCsv,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBody(double width) {
    return StreamBuilder<QuerySnapshot>(
      stream: _classroomsStream,
      builder: (context, classroomSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: _studentsStream,
          builder: (context, studentSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _attendanceStream,
              builder: (context, attendanceSnap) {
                if (classroomSnap.connectionState == ConnectionState.waiting ||
                    studentSnap.connectionState == ConnectionState.waiting ||
                    attendanceSnap.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                if (classroomSnap.hasError ||
                    studentSnap.hasError ||
                    attendanceSnap.hasError) {
                  final msg = [
                    if (classroomSnap.error != null) '${classroomSnap.error}',
                    if (studentSnap.error != null) '${studentSnap.error}',
                    if (attendanceSnap.error != null) '${attendanceSnap.error}',
                  ].join(' | ');
                  return AdminEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Error al cargar reportes',
                    message: msg,
                    error: true,
                  );
                }

                final classrooms = _parseClassrooms(
                  classroomSnap.data?.docs ?? <QueryDocumentSnapshot>[],
                );
                final students = _parseStudents(
                  studentSnap.data?.docs ?? <QueryDocumentSnapshot>[],
                );
                final records = _parseAttendance(
                  attendanceSnap.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                );

                final data = _buildReportData(
                  classrooms: classrooms,
                  students: students,
                  records: records,
                );

                // Scroll vertical ÚNICO: KPIs + tabla de aulas scrollean
                // juntos. Antes la tabla iba en Expanded y, cuando los KPIs
                // ocupaban casi toda la altura (móvil), la tabla se desbordaba
                // por abajo y no se podía hacer scroll.
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildKpiGrid(data),
                      const SizedBox(height: 12),
                      _buildClassroomSection(data, width),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AdminUi.pagePaddingTablet,
        0,
        AdminUi.pagePaddingTablet,
        16,
      ),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(
            5,
            (_) => Container(
              width: 180,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFECEFF1),
                borderRadius: AppDesignSystem.borderRadiusMD,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppDesignSystem.borderRadiusMD,
            border: Border.all(color: _kBorder),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid(_ReportData data) {
    final cards = <({String label, String value, Color color, IconData icon})>[
      (
        label: 'Asistencias',
        value: '${data.totalRecords}',
        color: AdminUi.kpiPrimary,
        icon: Icons.fact_check_rounded,
      ),
      (
        label: 'Entradas',
        value: '${data.totalEntries}',
        color: AppDesignSystem.successColor,
        icon: Icons.login_rounded,
      ),
      (
        label: 'Tardanzas',
        value: '${data.totalLate}',
        color: AppDesignSystem.warningColor,
        icon: Icons.schedule_rounded,
      ),
      (
        label: 'Salidas',
        value: '${data.totalExits}',
        color: AdminUi.neutralAction,
        icon: Icons.logout_rounded,
      ),
      (
        label: '% Tardanza',
        value: '${data.totalLatePercent.toStringAsFixed(1)}%',
        color: AdminUi.kpiInfo,
        icon: Icons.percent_rounded,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminUi.pagePaddingTablet,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final cols = w >= 1300
              ? 5
              : w >= 900
              ? 3
              : 2;
          const gap = 10.0;
          final cardWidth = (w - (cols - 1) * gap) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: cards
                .map(
                  (k) => SizedBox(
                    width: cardWidth,
                    child: _ReportKpiCard(
                      label: k.label,
                      value: k.value,
                      color: k.color,
                      icon: k.icon,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildClassroomSection(_ReportData data, double width) {
    final isWide = width >= 900;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AdminUi.pagePaddingTablet,
        0,
        AdminUi.pagePaddingTablet,
        16,
      ),
      child: Container(
        decoration: AdminUi.cardDecoration(elevated: false),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _kBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.1),
                      borderRadius: AppDesignSystem.borderRadiusSM,
                    ),
                    child: const Icon(
                      Icons.book_rounded,
                      size: 14,
                      color: _kPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Asistencia por aula',
                      style: AdminType.sectionTitle,
                    ),
                  ),
                  if (isWide)
                    Text(
                      'Se muestran todas las aulas, incluso sin registros',
                      style: AdminType.caption,
                    ),
                  if (!isWide)
                    Tooltip(
                      message:
                          'Se muestran todas las aulas, incluso sin registros',
                      child: const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppDesignSystem.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            // La tabla tiene 6 columnas densas. En anchos estrechos no caben,
            // así que se le da un ancho mínimo y se habilita scroll horizontal
            // (en vez de desbordar). En desktop usa el ancho completo.
            LayoutBuilder(
              builder: (context, constraints) {
                const minTableWidth = 640.0;
                final needsHScroll = constraints.maxWidth < minTableWidth;
                final tableWidth =
                    needsHScroll ? minTableWidth : constraints.maxWidth;

                final table = SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      AdminTable.headerRow(_classroomColumns, decorated: false),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: data.rows.length,
                        itemBuilder: (context, index) {
                          final row = data.rows[index];
                          final expanded = _expandedClassrooms.contains(
                            row.classroom.id,
                          );
                          final isLast =
                              index == data.rows.length - 1 && !expanded;
                          return Column(
                            children: [
                              _ClassroomSummaryRow(
                                row: row,
                                maxEntries: data.maxEntries,
                                isExpanded: expanded,
                                isLast: isLast,
                                onToggle: () {
                                  setState(() {
                                    if (expanded) {
                                      _expandedClassrooms
                                          .remove(row.classroom.id);
                                    } else {
                                      _expandedClassrooms.add(row.classroom.id);
                                    }
                                  });
                                },
                              ),
                              if (expanded)
                                _ClassroomDetailsPanel(
                                  key: ValueKey('details_${row.classroom.id}'),
                                  row: row,
                                  isLast: index == data.rows.length - 1,
                                  savingStudentKey: _savingStudentKey,
                                  statusColors: _statusColors,
                                  statusLabel: _statusLabel,
                                  onSaveStatus: (student, status) {
                                    final previous = row
                                        .latestDayRecordByStudent[student.id];
                                    return _saveAttendance(
                                      classroom: row.classroom,
                                      student: student,
                                      status: status,
                                      previous: previous,
                                    );
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );

                if (!needsHScroll) return table;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: table,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassroomSummaryRow extends StatefulWidget {
  final _ClassroomReportRow row;
  final int maxEntries;
  final bool isExpanded;
  final bool isLast;
  final VoidCallback onToggle;

  const _ClassroomSummaryRow({
    required this.row,
    required this.maxEntries,
    required this.isExpanded,
    required this.isLast,
    required this.onToggle,
  });

  @override
  State<_ClassroomSummaryRow> createState() => _ClassroomSummaryRowState();
}

class _ClassroomSummaryRowState extends State<_ClassroomSummaryRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final volume = widget.maxEntries <= 0
        ? 0.0
        : (row.entriesCount / widget.maxEntries).clamp(0.0, 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 58,
        padding: AdminTable.rowPadding,
        decoration: AdminUi.rowDecoration(
          hovered: _hovered,
          isLast: widget.isLast,
        ),
        child: AdminTable.dataRow(_classroomColumns, [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.classroom.label,
                  style: AdminType.bodyStrong,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text('${row.entriesCount}', style: AdminType.bodySm),
          Text('${row.lateCount}', style: AdminType.bodySm),
          Text(
            '${row.latePercent.toStringAsFixed(1)}%',
            style: AdminType.bodySm,
          ),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: volume,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFEFF2F6),
                    valueColor: const AlwaysStoppedAnimation(_kPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${row.records.length}', style: AdminType.caption),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: widget.onToggle,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                foregroundColor: _kPrimary,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                widget.isExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 16,
              ),
              label: Text(
                widget.isExpanded ? 'Ocultar' : 'Ver',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ClassroomDetailsPanel extends StatelessWidget {
  final _ClassroomReportRow row;
  final bool isLast;
  final String? savingStudentKey;
  final ({Color bg, Color fg}) Function(_AttendanceStatusKind) statusColors;
  final String Function(_AttendanceStatusKind) statusLabel;
  final Future<void> Function(
    _StudentMeta student,
    _AttendanceStatusKind status,
  )
  onSaveStatus;

  const _ClassroomDetailsPanel({
    super.key,
    required this.row,
    required this.isLast,
    required this.savingStudentKey,
    required this.statusColors,
    required this.statusLabel,
    required this.onSaveStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        border: Border(
          bottom: BorderSide(color: isLast ? Colors.transparent : _kBorder),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _MetaBadge(
                icon: Icons.groups_rounded,
                label: '${row.students.length} estudiantes',
              ),
              _MetaBadge(
                icon: Icons.fact_check_rounded,
                label:
                    '${row.students.length - row.studentsWithoutRecords.length} con registro',
              ),
              _MetaBadge(
                icon: Icons.remove_circle_outline_rounded,
                label: '${row.studentsWithoutRecords.length} sin registro',
                warning: row.studentsWithoutRecords.isNotEmpty,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (row.students.isEmpty)
            const AdminEmptyState(
              icon: Icons.groups_outlined,
              title: 'Esta aula no tiene estudiantes activos',
              message:
                  'Aun así se mantiene visible para control institucional.',
            )
          else
            Column(
              children: row.students.map((student) {
                final latestRange = row.latestRangeRecordByStudent[student.id];
                final dayRecord = row.latestDayRecordByStudent[student.id];
                final key = '${row.classroom.id}_${student.id}';
                final isSaving = savingStudentKey == key;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppDesignSystem.borderRadiusSM,
                    border: Border.all(color: _kBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.fullName,
                              style: AdminType.bodyStrong,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              student.dni.isNotEmpty
                                  ? 'DNI ${student.dni}'
                                  : 'Sin DNI',
                              style: AdminType.caption,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StudentStatusChip(
                        record: dayRecord ?? latestRange,
                        statusColors: statusColors,
                        statusLabel: statusLabel,
                      ),
                      const SizedBox(width: 10),
                      PopupMenuButton<_AttendanceStatusKind>(
                        tooltip: 'Editar asistencia',
                        icon: isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.edit_calendar_rounded,
                                size: 18,
                                color: AdminUi.neutralAction,
                              ),
                        enabled: !isSaving,
                        onSelected: (status) => onSaveStatus(student, status),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: _AttendanceStatusKind.present,
                            child: Text('Marcar Presente'),
                          ),
                          const PopupMenuItem(
                            value: _AttendanceStatusKind.late,
                            child: Text('Marcar Tardanza'),
                          ),
                          const PopupMenuItem(
                            value: _AttendanceStatusKind.absent,
                            child: Text('Marcar Ausente'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 2),
          Text(
            'Los cambios manuales se guardan como edición administrativa y no envían Telegram.',
            style: AdminType.caption,
          ),
        ],
      ),
    );
  }
}

class _StudentStatusChip extends StatelessWidget {
  final _AttendanceRecord? record;
  final ({Color bg, Color fg}) Function(_AttendanceStatusKind) statusColors;
  final String Function(_AttendanceStatusKind) statusLabel;

  const _StudentStatusChip({
    required this.record,
    required this.statusColors,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (record == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4F8),
          borderRadius: AppDesignSystem.borderRadiusFull,
        ),
        child: Text('Sin registro', style: AdminType.caption),
      );
    }

    final c = statusColors(record!.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppDesignSystem.borderRadiusFull,
      ),
      child: Text(
        statusLabel(record!.status),
        style: AdminType.caption.copyWith(
          color: c.fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReportKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _ReportKpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 124,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDesignSystem.borderRadiusMD,
        border: Border.all(color: _kBorder),
        boxShadow: [AppDesignSystem.getShadowSM()],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppDesignSystem.borderRadiusSM,
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 36 * 0.62,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppDesignSystem.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool warning;

  const _MetaBadge({
    required this.icon,
    required this.label,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppDesignSystem.warningColor : _kPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppDesignSystem.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassroomMeta {
  final String id;
  final String label;
  final String teacherName;
  final String grade;
  final String section;

  const _ClassroomMeta({
    required this.id,
    required this.label,
    required this.teacherName,
    required this.grade,
    required this.section,
  });
}

class _StudentMeta {
  final String id;
  final String fullName;
  final String dni;
  final String classroomId;

  const _StudentMeta({
    required this.id,
    required this.fullName,
    required this.dni,
    required this.classroomId,
  });
}

class _AttendanceRecord {
  final String docId;
  final String studentId;
  final String classroomId;
  final String classroomName;
  final String studentName;
  final String dateKey;
  final _AttendanceStatusKind status;
  final DateTime timestamp;
  final bool hasExit;
  final Map<String, dynamic> raw;

  const _AttendanceRecord({
    required this.docId,
    required this.studentId,
    required this.classroomId,
    required this.classroomName,
    required this.studentName,
    required this.dateKey,
    required this.status,
    required this.timestamp,
    required this.hasExit,
    required this.raw,
  });
}

class _ClassroomReportRow {
  final _ClassroomMeta classroom;
  final List<_StudentMeta> students;
  final List<_AttendanceRecord> records;
  final List<_StudentMeta> studentsWithoutRecords;
  final Map<String, _AttendanceRecord> latestDayRecordByStudent;
  final Map<String, _AttendanceRecord> latestRangeRecordByStudent;
  final int entriesCount;
  final int lateCount;
  final int exitCount;
  final double latePercent;

  const _ClassroomReportRow({
    required this.classroom,
    required this.students,
    required this.records,
    required this.studentsWithoutRecords,
    required this.latestDayRecordByStudent,
    required this.latestRangeRecordByStudent,
    required this.entriesCount,
    required this.lateCount,
    required this.exitCount,
    required this.latePercent,
  });
}

class _ReportData {
  final List<_ClassroomReportRow> rows;
  final int maxEntries;
  final int totalRecords;
  final int totalEntries;
  final int totalLate;
  final int totalExits;
  final double totalLatePercent;

  const _ReportData({
    required this.rows,
    required this.maxEntries,
    required this.totalRecords,
    required this.totalEntries,
    required this.totalLate,
    required this.totalExits,
    required this.totalLatePercent,
  });
}

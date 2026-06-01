import 'dart:async';
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
const _kBorder = Color(0xFFE6EAF0);
const _kPrimary = Color(0xFF1976D2);

// Columnas de la tabla de Estudiantes (header y filas comparten esta spec).
// Texto → izquierda; chips (QR, ESTADO) → centrados; acciones → derecha.
const List<AdminColumn> _studentColumns = [
  AdminColumn.flex(4, header: 'ESTUDIANTE'), // avatar + nombre
  AdminColumn.fixed(84, align: Alignment.centerLeft, header: 'DNI'),
  AdminColumn.flex(3, header: 'AULA'), // texto
  AdminColumn.flex(3, header: 'APODERADO / TEL.'), // texto
  AdminColumn.fixed(76, header: 'QR'), // chip centrado
  AdminColumn.fixed(96, header: 'ESTADO'), // chip centrado
  AdminColumn.fixed(AdminTable.actionColWidth,
      align: Alignment.centerRight), // acciones
];

// ─── Filter options ──────────────────────────────────────────────────────────
enum _StatusFilter { all, active, inactive }

enum _SecondaryFilter {
  withPhone,
  noPhone,
  withQr,
  noQr,
  withClassroom,
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
  _StatusFilter _statusFilter = _StatusFilter.all;
  final Set<_SecondaryFilter> _secondaryFilters = <_SecondaryFilter>{};
  String _query = '';
  String? _classroomFilter; // id de aula seleccionada; null = todas
  bool _onlyWithoutClassroom = false; // selector principal "Sin aula"

  // ── Performance: ventana de carga (servidor) + paginación (cliente) ─────────
  // No se cargan TODOS los alumnos de golpe: se trae una ventana del servidor
  // y se muestran de a 10 por página. Al pasar de la última página de la
  // ventana, se amplía la ventana. Reduce memoria, parseo y filas renderizadas.
  static const int _windowSize = 100; // tamaño de ventana del servidor
  int _limit = _windowSize;
  int _page = 0; // página actual (0-based), 10 por página
  Timer? _searchDebounce;

  // Stream de estudiantes (ventana limitada) + stream de aulas (para etiquetas).
  late Stream<QuerySnapshot> _studentsStream;
  late final Stream<QuerySnapshot> _classroomsStream;

  void _initStudentsStream() {
    // Sin filtro isActive: el admin debe ver activos e inactivos.
    // Filtro por aula server-side (campo existente classroomId) → solo trae
    // los alumnos de esa aula. limit() acota la ventana de memoria.
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection('students');
    if (_classroomFilter != null && !_onlyWithoutClassroom) {
      q = q.where('classroomId', isEqualTo: _classroomFilter);
    }
    _studentsStream = q.limit(_limit).snapshots();
  }

  @override
  void initState() {
    super.initState();
    _initStudentsStream();
    _classroomsStream = ClassroomService.getAllClassrooms();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Amplía la ventana del servidor y avanza a la página [nextPage].
  void _growWindow(int nextPage) {
    setState(() {
      _limit += _windowSize;
      _initStudentsStream();
      _page = nextPage;
    });
  }

  void _onSearchChanged(String v) {
    // Debounce: no refiltrar ni reconstruir en cada tecla.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final q = v.trim().toLowerCase();
      if (q != _query) {
        setState(() {
          _query = q;
          _page = 0; // reiniciar paginación al cambiar la búsqueda
        });
      }
    });
  }

  String _statusLabel(_StatusFilter f) {
    switch (f) {
      case _StatusFilter.active:
        return 'Activos';
      case _StatusFilter.inactive:
        return 'Inactivos';
      case _StatusFilter.all:
        return 'Todos';
    }
  }

  String _secondaryLabel(_SecondaryFilter f) {
    switch (f) {
      case _SecondaryFilter.withPhone:
        return 'Con telefono';
      case _SecondaryFilter.noPhone:
        return 'Sin telefono';
      case _SecondaryFilter.withQr:
        return 'Con QR';
      case _SecondaryFilter.noQr:
        return 'Sin QR';
      case _SecondaryFilter.withClassroom:
        return 'Con aula';
    }
  }

  void _toggleSecondary(_SecondaryFilter filter) {
    setState(() {
      if (_secondaryFilters.contains(filter)) {
        _secondaryFilters.remove(filter);
      } else {
        if (filter == _SecondaryFilter.withPhone) {
          _secondaryFilters.remove(_SecondaryFilter.noPhone);
        }
        if (filter == _SecondaryFilter.noPhone) {
          _secondaryFilters.remove(_SecondaryFilter.withPhone);
        }
        if (filter == _SecondaryFilter.withQr) {
          _secondaryFilters.remove(_SecondaryFilter.noQr);
        }
        if (filter == _SecondaryFilter.noQr) {
          _secondaryFilters.remove(_SecondaryFilter.withQr);
        }
        _secondaryFilters.add(filter);
      }
      _page = 0;
    });
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

      // Filtro principal: aula.
      if (_onlyWithoutClassroom) {
        if (classroomId.isNotEmpty) return false;
      } else if (_classroomFilter != null && classroomId != _classroomFilter) {
        return false;
      }

      // Estado (selector dedicado).
      if (_statusFilter == _StatusFilter.active && !isActive) return false;
      if (_statusFilter == _StatusFilter.inactive && isActive) return false;

      // Filtros secundarios ("Más filtros").
      if (_secondaryFilters.contains(_SecondaryFilter.withPhone) &&
          phone.isEmpty) {
        return false;
      }
      if (_secondaryFilters.contains(_SecondaryFilter.noPhone) &&
          phone.isNotEmpty) {
        return false;
      }
      if (_secondaryFilters.contains(_SecondaryFilter.withQr) &&
          qrCode.isEmpty) {
        return false;
      }
      if (_secondaryFilters.contains(_SecondaryFilter.noQr) &&
          qrCode.isNotEmpty) {
        return false;
      }
      if (_secondaryFilters.contains(_SecondaryFilter.withClassroom) &&
          classroomId.isEmpty) {
        return false;
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
      ScaffoldMessenger.of(context).showSnackBar(AdminFeedback.snack(
        ok ? AdminFeedbackType.success : AdminFeedbackType.error,
        ok
            ? 'Estudiante ${wasActive ? 'desactivado' : 'reactivado'}'
            : 'No se pudo actualizar el estado',
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
          AdminButton.ghost(
            label: 'Cancelar',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          student.isActive
              ? AdminButton.danger(
                  label: 'Desactivar',
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _toggleStatus(student);
                  },
                )
              : AdminButton.primary(
                  label: 'Activar',
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _toggleStatus(student);
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
    final isWide = width >= 600;

    // Inter SOLO en el subárbol de Estudiantes (no afecta login ni docente).
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
              child: const _StudentsHeader(),
            ),
            const SizedBox(height: 16),
            _buildToolbar(isWide),
            const SizedBox(height: 16),
            Expanded(child: _buildBody(isWide)),
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
        child: LayoutBuilder(
          builder: (context, c) {
            final isDesktop = c.maxWidth >= 1050;
            final isTablet = c.maxWidth >= 720;

            if (isDesktop) {
              return Row(
                children: [
                  SizedBox(width: 240, child: _classroomSelector(false)),
                  const SizedBox(width: 10),
                  Expanded(child: _searchBox()),
                  const SizedBox(width: 10),
                  SizedBox(width: 150, child: _statusSelector()),
                  const SizedBox(width: 10),
                  SizedBox(width: 150, child: _moreFiltersMenu()),
                  const SizedBox(width: 10),
                  AdminButton.primary(
                    label: 'Nuevo estudiante',
                    icon: Icons.add_rounded,
                    onPressed: _showCreate,
                  ),
                ],
              );
            }

            if (isTablet && wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _searchBox()),
                      const SizedBox(width: 10),
                      SizedBox(width: 220, child: _classroomSelector(false)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(width: 150, child: _statusSelector()),
                      const SizedBox(width: 10),
                      SizedBox(width: 150, child: _moreFiltersMenu()),
                      const SizedBox(width: 10),
                      AdminButton.primary(
                        label: 'Nuevo estudiante',
                        icon: Icons.add_rounded,
                        onPressed: _showCreate,
                      ),
                    ],
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _classroomSelector(true),
                const SizedBox(height: 10),
                _searchBox(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _statusSelector()),
                    const SizedBox(width: 8),
                    Expanded(child: _moreFiltersMenu()),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: AdminButton.primary(
                    label: 'Nuevo estudiante',
                    icon: Icons.add_rounded,
                    onPressed: _showCreate,
                    expand: true,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Selector de aula (server-side por classroomId). null = todas las aulas.
  Widget _classroomSelector(bool fullWidth) {
    return StreamBuilder<QuerySnapshot>(
      stream: _classroomsStream,
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final options = <({String id, String label})>[];
        for (final d in docs) {
          final m = d.data() as Map<String, dynamic>;
          final grade = (m['grade'] ?? '').toString();
          final section = (m['section'] ?? '').toString();
          final name = (m['name'] ?? '').toString();
          final label = grade.isNotEmpty && section.isNotEmpty
              ? '$grade° $section${name.isNotEmpty ? ' – $name' : ''}'
              : name.isNotEmpty
                  ? name
                  : d.id;
          options.add((id: d.id, label: label));
        }
        options.sort((a, b) => a.label.compareTo(b.label));

        var current = 'Todas las aulas';
        if (_onlyWithoutClassroom) {
          current = 'Sin aula';
        } else if (_classroomFilter != null) {
          current = options
              .firstWhere((o) => o.id == _classroomFilter,
                  orElse: () => (id: _classroomFilter!, label: 'Aula'))
              .label;
        }

        final selectedValue = _onlyWithoutClassroom
            ? _AulaDropdown.withoutAula
            : (_classroomFilter ?? _AulaDropdown.allAulas);

        return _AulaDropdown(
          currentLabel: current,
          selectedValue: selectedValue,
          options: options,
          fullWidth: fullWidth,
          onSelected: (value) => setState(() {
            if (value == _AulaDropdown.allAulas) {
              _classroomFilter = null;
              _onlyWithoutClassroom = false;
            } else if (value == _AulaDropdown.withoutAula) {
              _classroomFilter = null;
              _onlyWithoutClassroom = true;
              _secondaryFilters.remove(_SecondaryFilter.withClassroom);
            } else {
              _classroomFilter = value;
              _onlyWithoutClassroom = false;
            }
            _page = 0;
            _initStudentsStream();
          }),
        );
      },
    );
  }

  Widget _searchBox() {
    return AdminSearchField(
      controller: _searchCtrl,
      hint: 'Buscar por nombre, apellido o DNI…',
      hasValue: _query.isNotEmpty,
      onChanged: _onSearchChanged,
      onClear: () {
        _searchDebounce?.cancel();
        _searchCtrl.clear();
        setState(() {
          _query = '';
          _page = 0;
        });
      },
    );
  }

  Widget _statusSelector() {
    return _ToolbarDropdown<_StatusFilter>(
      icon: Icons.flag_outlined,
      label: 'Estado: ${_statusLabel(_statusFilter)}',
      tooltip: 'Filtrar por estado',
      highlighted: _statusFilter != _StatusFilter.all,
      selected: _statusFilter,
      options: const {
        _StatusFilter.all: 'Todos',
        _StatusFilter.active: 'Activos',
        _StatusFilter.inactive: 'Inactivos',
      },
      onSelected: (status) => setState(() {
        _statusFilter = status;
        _page = 0;
      }),
    );
  }

  Widget _moreFiltersMenu() {
    final activeCount = _secondaryFilters.length;
    return _ToolbarDropdown<_SecondaryFilter>(
      icon: Icons.tune_rounded,
      label: activeCount == 0 ? 'Más filtros' : 'Más filtros ($activeCount)',
      tooltip: 'Filtros secundarios',
      highlighted: activeCount > 0,
      selectedValues: _secondaryFilters,
      options: const {
        _SecondaryFilter.withPhone: 'Con teléfono',
        _SecondaryFilter.noPhone: 'Sin teléfono',
        _SecondaryFilter.withQr: 'Con QR',
        _SecondaryFilter.noQr: 'Sin QR',
        _SecondaryFilter.withClassroom: 'Con aula',
      },
      multi: true,
      onSelectedMulti: _toggleSecondary,
    );
  }

  // ─── body ──────────────────────────────────────────────────────────────────

  Widget _buildContextSummary({
    required int visibleCount,
    required Map<String, String> classroomMap,
    required Map<String, Map<String, dynamic>> classroomData,
  }) {
    String title;
    String subtitle;
    final tags = <Widget>[];

    if (_onlyWithoutClassroom) {
      title = 'Estudiantes sin aula asignada';
      subtitle = '$visibleCount visibles en esta vista';
      tags.add(const _SummaryTag(
        icon: Icons.info_outline_rounded,
        label: 'Asignar aula recomendado',
      ));
    } else if (_classroomFilter != null) {
      final id = _classroomFilter!;
      final data = classroomData[id];
      final teacher = (data?['teacherName'] ?? '').toString().trim();
      final hasTeacher = teacher.isNotEmpty;
      final schedule = data?['schedule'];
      final hasSchedule = schedule is Map && schedule.isNotEmpty;
      final isActive = data?['isActive'] as bool? ?? true;

      title = classroomMap[id] ?? 'Aula seleccionada';
      subtitle = '$visibleCount estudiantes visibles';
      tags.add(_SummaryTag(
        icon: Icons.person_outline_rounded,
        label: hasTeacher ? teacher : 'Sin docente',
      ));
      tags.add(_SummaryTag(
        icon: Icons.schedule_rounded,
        label: hasSchedule ? 'Horario listo' : 'Sin horario',
      ));
      tags.add(_SummaryTag(
        icon: isActive
            ? Icons.check_circle_outline_rounded
            : Icons.block_rounded,
        label: isActive ? 'Activa' : 'Inactiva',
      ));
    } else {
      title = 'Todos los estudiantes';
      subtitle = '$visibleCount visibles en esta vista';
      tags.add(const _SummaryTag(
        icon: Icons.apartment_outlined,
        label: 'Todas las aulas',
      ));
    }

    if (_statusFilter != _StatusFilter.all) {
      tags.add(_SummaryTag(
        icon: Icons.flag_outlined,
        label: _statusLabel(_statusFilter),
      ));
    }
    if (_query.isNotEmpty) {
      tags.add(const _SummaryTag(
        icon: Icons.search_rounded,
        label: 'Busqueda activa',
      ));
    }
    for (final filter in _secondaryFilters) {
      tags.add(_SummaryTag(
        icon: Icons.tune_rounded,
        label: _secondaryLabel(filter),
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AdminUi.pagePaddingTablet),
      child: Container(
        decoration: AdminUi.cardDecoration(elevated: false),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AdminUi.softBg(AdminUi.primary),
                borderRadius: AppDesignSystem.borderRadiusSM,
              ),
              child: const Icon(
                Icons.groups_2_outlined,
                size: 17,
                color: AdminUi.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AdminType.bodyStrong),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AdminType.caption),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool wide) {
    return StreamBuilder<QuerySnapshot>(
      stream: _classroomsStream,
      builder: (context, classSnap) {
        // Build classroomId → display label once; no N+1 queries.
        final classroomMap = <String, String>{};
        final classroomData = <String, Map<String, dynamic>>{};
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
            classroomData[doc.id] = d;
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
            final contextSummary = _buildContextSummary(
              visibleCount: filtered.length,
              classroomMap: classroomMap,
              classroomData: classroomData,
            );

            if (filtered.isEmpty) {
              return Column(
                children: [
                  contextSummary,
                  const SizedBox(height: 12),
                  Expanded(child: _emptyState(allDocs.isEmpty)),
                ],
              );
            }

            // Paginación cliente: 10 por página sobre la lista filtrada.
            const perPage = AdminPaginationBar.perPage;
            final total = filtered.length;
            final pageCount = (total / perPage).ceil();
            final page = _page.clamp(0, pageCount - 1);
            final start = page * perPage;
            final pageDocs =
                filtered.sublist(start, (start + perPage).clamp(0, total));
            // ¿La ventana del servidor podría tener más registros?
            final canGrow = allDocs.length >= _limit;

            final Widget content = wide
                ? _WebTable(
                    docs: pageDocs,
                    classroomMap: classroomMap,
                    onEdit: _showEdit,
                    onQr: _showQrDialog,
                    onTransfer: _showTransfer,
                    onToggle: _confirmToggle,
                  )
                : _MobileList(
                    docs: pageDocs,
                    classroomMap: classroomMap,
                    onEdit: _showEdit,
                    onQr: _showQrDialog,
                    onTransfer: _showTransfer,
                    onToggle: _confirmToggle,
                  );

            return Column(
              children: [
                contextSummary,
                const SizedBox(height: 12),
                Expanded(child: content),
                AdminPaginationBar(
                  page: page,
                  pageCount: pageCount,
                  totalItems: total,
                  onPrev:
                      page > 0 ? () => setState(() => _page = page - 1) : null,
                  onNext: page < pageCount - 1
                      ? () => setState(() => _page = page + 1)
                      : (canGrow ? () => _growWindow(page + 1) : null),
                ),
              ],
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
    return AdminEmptyState(
      icon: Icons.school_outlined,
      title: noStudents
          ? 'No hay estudiantes registrados'
          : 'No se encontraron estudiantes',
      message: noStudents
          ? 'Crea el primer estudiante con el botón "Nuevo estudiante".'
          : 'Prueba ajustando el filtro o la búsqueda.',
    );
  }

  Widget _errorState(String msg) {
    return AdminEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Error al cargar estudiantes',
      message: msg,
      error: true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _StudentsHeader extends StatelessWidget {
  const _StudentsHeader();

  @override
  Widget build(BuildContext context) {
    return const AdminCompactHeader(
      title: 'Gestión de estudiantes',
      subtitle: 'Administra padrón, aulas, QR y apoderados',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WEB TABLE
// ─────────────────────────────────────────────────────────────────────────────

/// Selector de aula con estilo de chip/input (PopupMenuButton). Sentinela
/// `_allAulas` representa "Todas las aulas" (filtro = null).
class _AulaDropdown extends StatelessWidget {
  static const String allAulas = '__all__';
  static const String withoutAula = '__without__';

  final String currentLabel;
  final String selectedValue;
  final List<({String id, String label})> options;
  final ValueChanged<String> onSelected;
  final bool fullWidth;

  const _AulaDropdown({
    required this.currentLabel,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
    required this.fullWidth,
  });

  @override
  Widget build(BuildContext context) {
    final menuMaxWidth = fullWidth ? 420.0 : 320.0;
    final field = Container(
      height: AdminUi.fieldHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AdminUi.surface,
        borderRadius: AppDesignSystem.borderRadiusMD,
        border: Border.all(
          color: selectedValue != allAulas
              ? _kPrimary.withValues(alpha: 0.45)
              : _kBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.class_outlined,
              size: 18,
              color: selectedValue != allAulas
                  ? _kPrimary
                  : AdminUi.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              currentLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AdminType.bodySm.copyWith(
                fontWeight:
                    selectedValue != allAulas ? FontWeight.w600 : FontWeight.w500,
                color:
                    selectedValue != allAulas ? _kPrimary : AdminUi.textPrimary,
              ),
            ),
          ),
          Icon(Icons.arrow_drop_down_rounded,
              size: 20, color: AdminUi.textSecondary),
        ],
      ),
    );

    return PopupMenuButton<String>(
      tooltip: 'Filtrar por aula',
      position: PopupMenuPosition.under,
      color: Colors.white,
      constraints: BoxConstraints(minWidth: 240, maxWidth: menuMaxWidth),
      shape: RoundedRectangleBorder(
        borderRadius: AppDesignSystem.borderRadiusMD,
        side: const BorderSide(color: AdminUi.border),
      ),
      onSelected: onSelected,
      itemBuilder: (_) => [
        _item(allAulas, 'Todas las aulas', selectedValue == allAulas),
        _item(withoutAula, 'Sin aula', selectedValue == withoutAula),
        ...options.map((o) => _item(o.id, o.label, o.id == selectedValue)),
      ],
      child: field,
    );
  }

  PopupMenuItem<String> _item(String value, String label, bool selected) {
    final defaultIcon = value == withoutAula
        ? Icons.person_off_outlined
        : (value == allAulas ? Icons.apartment_outlined : Icons.class_outlined);
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_rounded : defaultIcon,
            size: 16,
            color: selected ? _kPrimary : AdminUi.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AdminType.bodySm.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _kPrimary : AdminUi.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarDropdown<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final Map<T, String> options;
  final T? selected;
  final Set<T>? selectedValues;
  final ValueChanged<T>? onSelected;
  final ValueChanged<T>? onSelectedMulti;
  final bool multi;
  final bool highlighted;

  const _ToolbarDropdown({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.options,
    this.selected,
    this.selectedValues,
    this.onSelected,
    this.onSelectedMulti,
    this.multi = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = highlighted || (multi
        ? (selectedValues?.isNotEmpty ?? false)
        : selected != null);

    final trigger = Container(
      height: AdminUi.fieldHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AdminUi.surface,
        borderRadius: AppDesignSystem.borderRadiusMD,
        border: Border.all(
          color: active ? _kPrimary.withValues(alpha: 0.45) : _kBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: active ? _kPrimary : AdminUi.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AdminType.bodySm.copyWith(
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? _kPrimary : AdminUi.textPrimary,
              ),
            ),
          ),
          const Icon(
            Icons.arrow_drop_down_rounded,
            size: 20,
            color: AdminUi.textSecondary,
          ),
        ],
      ),
    );

    return PopupMenuButton<T>(
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      color: Colors.white,
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
      shape: RoundedRectangleBorder(
        borderRadius: AppDesignSystem.borderRadiusMD,
        side: const BorderSide(color: AdminUi.border),
      ),
      onSelected: (value) {
        if (multi) {
          onSelectedMulti?.call(value);
        } else {
          onSelected?.call(value);
        }
      },
      itemBuilder: (_) => options.entries.map((entry) {
        final isSelected = multi
            ? (selectedValues?.contains(entry.key) ?? false)
            : selected == entry.key;
        return PopupMenuItem<T>(
          value: entry.key,
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_rounded : Icons.radio_button_unchecked,
                size: 16,
                color: isSelected ? _kPrimary : AdminUi.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminType.bodySm.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? _kPrimary : AdminUi.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: trigger,
    );
  }
}

class _SummaryTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SummaryTag({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AdminUi.surface2,
        border: Border.all(color: AdminUi.border),
        borderRadius: AppDesignSystem.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AdminUi.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AdminType.caption.copyWith(
              color: AdminUi.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

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
            // Header (misma spec de columnas que las filas)
            AdminTable.headerRow(_studentColumns),
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
        height: AdminTable.rowHeight,
        padding: AdminTable.rowPadding,
        decoration: AdminUi.rowDecoration(
          hovered: _hovered,
          isLast: widget.isLast,
        ),
        child: AdminTable.dataRow(_studentColumns, [
          // ESTUDIANTE — avatar + nombre (+ email) como celda compuesta.
          Row(
            children: [
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
                    color:
                        s.isActive ? _kPrimary : AppDesignSystem.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      s.fullName,
                      style: AdminType.bodyStrong,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (s.parentEmail != null && s.parentEmail!.isNotEmpty)
                      Text(
                        s.parentEmail!,
                        style: AdminType.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          // DNI (texto, izquierda)
          Text(
            s.dni.isNotEmpty ? s.dni : '—',
            style: AdminType.bodySm.copyWith(color: AppDesignSystem.textSecondary),
          ),
          // AULA (texto, izquierda)
          Text(
            widget.classroomLabel,
            style: AdminType.bodySm.copyWith(color: AppDesignSystem.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
          // APODERADO / TEL. (texto, izquierda)
          Text(
            hasPhone ? s.parentPhone! : '—',
            style: AdminType.bodySm.copyWith(
              color: hasPhone
                  ? AppDesignSystem.textPrimary
                  : AppDesignSystem.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          // QR (chip centrado)
          _QrChip(hasQr: hasQr),
          // ESTADO (chip centrado)
          _StatusChip(isActive: s.isActive),
          // ACCIONES (Editar visible + menú "⋯", derecha)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdminActionIcon(
                icon: Icons.edit_outlined,
                tooltip: 'Editar datos',
                onTap: () => widget.onEdit(s),
              ),
              _RowMenu(
                isActive: s.isActive,
                onQr: () => widget.onQr(s),
                onTransfer: () => widget.onTransfer(s),
                onToggle: () => widget.onToggle(s),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

/// Menú "⋯" que agrupa acciones secundarias del estudiante para reducir ruido
/// en la fila. Conserva acciones reales: ver QR/Telegram, transferir aula y
/// activar/desactivar.
class _RowMenu extends StatelessWidget {
  final bool isActive;
  final VoidCallback onQr;
  final VoidCallback onTransfer;
  final VoidCallback onToggle;

  const _RowMenu({
    required this.isActive,
    required this.onQr,
    required this.onTransfer,
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
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: AppDesignSystem.borderRadiusMD,
        side: const BorderSide(color: AdminUi.border),
      ),
      onSelected: (v) {
        switch (v) {
          case 'qr':
            onQr();
            break;
          case 'transfer':
            onTransfer();
            break;
          case 'toggle':
            onToggle();
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'qr',
          child: Row(
            children: [
              const Icon(Icons.qr_code_rounded,
                  size: 18, color: Color(0xFF00695C)),
              const SizedBox(width: 10),
              Text('Ver QR / Telegram', style: AdminType.bodySm),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'transfer',
          child: Row(
            children: [
              const Icon(Icons.swap_horiz_rounded,
                  size: 18, color: AdminUi.neutralAction),
              const SizedBox(width: 10),
              Text('Transferir aula', style: AdminType.bodySm),
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
                isActive ? 'Desactivar estudiante' : 'Activar estudiante',
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/classroom_model.dart';
import '../../../../services/classroom_service.dart';
import '../../../../services/teacher_service.dart';
import '../../../../theme/app_design_system.dart';
import '../../widgets/admin_ui.dart';

const _kBorder = Color(0xFFE6EAF0);

/// Diálogo para crear o editar un aula.
/// Pasa [classroom] == null para crear, o una instancia para editar.
class ClassroomFormDialog extends StatefulWidget {
  final ClassroomModel? classroom;

  const ClassroomFormDialog({super.key, this.classroom});

  @override
  State<ClassroomFormDialog> createState() => _ClassroomFormDialogState();
}

class _ClassroomFormDialogState extends State<ClassroomFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _grade;
  late final TextEditingController _section;
  late final TextEditingController _capacity;

  bool _isLoading = false;
  bool _teachersLoaded = false;
  bool _hasActiveTeachers = false;
  bool get _isEditing => widget.classroom != null;

  static const _grades = ['1', '2', '3', '4', '5', '6'];
  static const _sections = ['A', 'B', 'C', 'D', 'E'];

  // Tutor (obligatorio) — equivale a teacherUid principal.
  String? _teacherUid;
  String? _teacherName;
  // Auxiliar (opcional) — se persiste como 2º miembro de teacherUids.
  String? _auxiliarUid;
  // Cache uid → nombre, alimentada por el stream (lo que ya cargó).
  final Map<String, String> _teacherNameByUid = <String, String>{};
  // Cache uid → isAuxiliar, para filtrar tutores vs auxiliares sin
  // re-suscribirse al stream.
  final Map<String, bool> _teacherIsAuxByUid = <String, bool>{};
  late final Stream<QuerySnapshot> _teachersStream;
  // Aulas legacy con >2 teacherUids: registramos los descartados (más allá
  // del primer auxiliar) para mostrar una nota una sola vez.
  final List<String> _legacyDroppedUids = <String>[];

  @override
  void initState() {
    super.initState();
    final c = widget.classroom;
    _name = TextEditingController(text: c?.name ?? '');
    _grade = TextEditingController(text: c?.grade ?? '');
    _section = TextEditingController(text: c?.section ?? '');
    _capacity = TextEditingController(
      text: c != null ? c.capacity.toString() : '',
    );
    _teacherUid = c?.teacherUid;
    _teacherName = c?.teacherName;
    // Compatibilidad: aulas antiguas pueden no traer teacherUids;
    // effectiveTeacherUids del modelo ya hace fallback a [teacherUid].
    // En el nuevo modelo solo hay UN auxiliar; tomamos el primer uid distinto
    // del tutor. Los demás se reportan como deuda legacy.
    if (c != null) {
      for (final uid in c.effectiveTeacherUids) {
        if (uid == _teacherUid) continue;
        if (_auxiliarUid == null) {
          _auxiliarUid = uid;
        } else {
          _legacyDroppedUids.add(uid);
        }
      }
    }
    _teachersStream = TeacherService.getTeachersStream();
  }

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

  @override
  void dispose() {
    _name.dispose();
    _grade.dispose();
    _section.dispose();
    _capacity.dispose();
    super.dispose();
  }

  void _syncTeacherState({
    required bool loaded,
    required bool hasActiveTeachers,
  }) {
    if (_teachersLoaded == loaded && _hasActiveTeachers == hasActiveTeachers) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _teachersLoaded = loaded;
        _hasActiveTeachers = hasActiveTeachers;
      });
    });
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_teachersLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        AdminFeedback.snack(
          AdminFeedbackType.warning,
          'Espera a que carguen los docentes',
        ),
      );
      return;
    }
    if (!_hasActiveTeachers && !_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        AdminFeedback.snack(AdminFeedbackType.error, 'Sin docentes activos'),
      );
      return;
    }
    if (_teacherUid == null || _teacherUid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AdminFeedback.snack(
          AdminFeedbackType.error,
          'Selecciona un tutor',
        ),
      );
      return;
    }
    if (_auxiliarUid != null && _auxiliarUid == _teacherUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        AdminFeedback.snack(
          AdminFeedbackType.error,
          'El auxiliar debe ser distinto al tutor',
        ),
      );
      return;
    }
    setState(() => _isLoading = true);

    final name = _name.text.trim();
    final grade = _grade.text.trim();
    final section = _section.text.trim().toUpperCase();
    final capacity = int.parse(_capacity.text.trim());

    // Validación 1 tutor = 1 aula activa.
    // Solo se consulta cuando el tutor cambió (o al crear). Al editar
    // un aula sin tocar el tutor se omite el round-trip y la validación.
    final tutorChanged =
        !_isEditing || widget.classroom!.teacherUid != _teacherUid;
    if (tutorChanged) {
      try {
        final conflict = await ClassroomService.findActiveClassroomByTutor(
          _teacherUid!,
          excludeClassroomId: widget.classroom?.id,
        );
        if (conflict != null) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          final conflictLabel = conflict.grade.isNotEmpty
              ? '${conflict.grade}° ${conflict.section} (${conflict.name})'
              : conflict.name;
          ScaffoldMessenger.of(context).showSnackBar(
            AdminFeedback.snack(
              AdminFeedbackType.error,
              'Este tutor ya está asignado al aula $conflictLabel. Un tutor solo puede tener una aula activa.',
            ),
          );
          return;
        }
      } catch (e) {
        // Si la validación falla por red/reglas, no bloqueamos la operación:
        // el guardado posterior reportará su propio error. Solo informamos.
        debugPrint('findActiveClassroomByTutor falló: $e');
      }
    }

    try {
      bool ok;
      String message;

      // Lista final: tutor solo, o [tutor, auxiliar] si hay auxiliar.
      // El service deriva isPolidocente de length>1, manteniendo compatibilidad
      // con el contrato anterior sin necesidad de migración.
      final allUids = _auxiliarUid == null
          ? <String>[_teacherUid!]
          : <String>[_teacherUid!, _auxiliarUid!];

      if (_isEditing) {
        ok = await ClassroomService.updateClassroom(
          classroomId: widget.classroom!.id!,
          name: name,
          grade: grade,
          section: section,
          capacity: capacity,
          description: widget.classroom!.description,
          teacherUid: _teacherUid,
          teacherName: _teacherName,
          teacherUids: allUids,
        );
        message = ok
            ? 'Aula actualizada correctamente'
            : 'Error al actualizar el aula';
      } else {
        final result = await ClassroomService.createClassroom(
          name: name,
          grade: grade,
          section: section,
          capacity: capacity,
          description: 'Aula creada por administrador',
          teacherUid: _teacherUid,
          teacherName: _teacherName,
          teacherUids: allUids,
        );
        ok = result['success'] == true;
        message =
            result['message'] ??
            (ok ? 'Aula creada correctamente' : 'Error al crear el aula');
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        AdminFeedback.snack(
          ok ? AdminFeedbackType.success : AdminFeedbackType.error,
          message,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(AdminFeedback.snack(AdminFeedbackType.error, 'Error: $e'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Editar aula' : 'Nueva aula';
    final btnLabel = _isEditing ? 'Guardar cambios' : 'Crear aula';
    final canSubmit =
        !_isLoading && _teachersLoaded && (_hasActiveTeachers || _isEditing);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppDesignSystem.borderRadiusLG,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
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
                          color: AppDesignSystem.primaryColor.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: AppDesignSystem.borderRadiusMD,
                        ),
                        child: const Icon(
                          Icons.class_rounded,
                          size: 20,
                          color: AppDesignSystem.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        color: AppDesignSystem.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Los campos marcados con * son obligatorios.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppDesignSystem.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(color: _kBorder, height: 1),
                  const SizedBox(height: 20),

                  // Nombre
                  _field(
                    label: 'Nombre del aula *',
                    controller: _name,
                    hint: 'Ej: Matemáticas, Comunicación…',
                    icon: Icons.drive_file_rename_outline_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'El nombre es requerido'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Grado + Sección
                  Row(
                    children: [
                      Expanded(
                        child: _dropdownField(
                          label: 'Grado *',
                          controller: _grade,
                          items: _grades,
                          hint: 'Ej: 1, 2, 3…',
                          icon: Icons.school_outlined,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Requerido'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dropdownField(
                          label: 'Sección *',
                          controller: _section,
                          items: _sections,
                          hint: 'Ej: A, B, C…',
                          icon: Icons.tag_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Requerido'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Capacidad
                  _field(
                    label: 'Capacidad máxima *',
                    controller: _capacity,
                    hint: 'Número de estudiantes (1–60)',
                    icon: Icons.groups_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0 || n > 60) {
                        return 'Ingresa un número entre 1 y 60';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Tutor (obligatorio) + auxiliar (opcional).
                  _buildTeacherDropdown(),
                  const SizedBox(height: 12),
                  _buildAuxiliarDropdown(),
                  if (_legacyDroppedUids.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Esta aula tenía ${_legacyDroppedUids.length + 1} docentes asignados; se conservan tutor y auxiliar. Los demás se omitirán al guardar.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppDesignSystem.warningColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.primaryColor.withValues(
                        alpha: 0.05,
                      ),
                      borderRadius: AppDesignSystem.borderRadiusMD,
                      border: Border.all(
                        color: AppDesignSystem.primaryColor.withValues(
                          alpha: 0.2,
                        ),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppDesignSystem.primaryColor,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'El horario se configura por separado desde la tabla.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppDesignSystem.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AdminButton.ghost(
                        label: 'Cancelar',
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      AdminButton.primary(
                        label: _isLoading ? 'Guardando' : btnLabel,
                        icon: Icons.check_rounded,
                        loading: _isLoading,
                        onPressed: canSubmit ? _submit : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: AdminInputs.decoration(
        label: label,
        hint: hint,
        prefixIcon: icon,
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required TextEditingController controller,
    required List<String> items,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(controller.text) ? controller.text : null,
      isExpanded: true,
      validator: validator,
      decoration: AdminInputs.decoration(label: label, prefixIcon: icon),
      hint: Text(hint, style: const TextStyle(fontSize: 13)),
      items: items
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: (v) {
        if (v != null) controller.text = v;
      },
    );
  }

  Widget _buildTeacherDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _teachersStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          _syncTeacherState(loaded: false, hasActiveTeachers: false);
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        if (snap.hasError) {
          _syncTeacherState(loaded: true, hasActiveTeachers: false);
          return _teacherNotice(
            icon: Icons.error_outline_rounded,
            color: AppDesignSystem.errorColor,
            message: 'No se pudieron cargar los docentes',
          );
        }
        final docs = snap.data?.docs ?? const [];
        _syncTeacherState(loaded: true, hasActiveTeachers: docs.isNotEmpty);
        if (docs.isEmpty) {
          return _teacherNotice(
            icon: Icons.warning_amber_rounded,
            color: AppDesignSystem.warningColor,
            message: 'Sin docentes activos',
          );
        }

        // Mapear uid → name y uid → isAuxiliar.
        final byUid = <String, String>{};
        final auxByUid = <String, bool>{};
        for (final d in docs) {
          final data = d.data() as Map<String, dynamic>;
          final uid = (data['uid'] as String?) ?? d.id;
          byUid[uid] = _displayName(data);
          auxByUid[uid] = (data['isAuxiliar'] as bool?) ?? false;
        }
        // Conservar entradas legacy (docente desactivado o inactivo) para no
        // perder el dato en edición.
        if (_teacherUid != null && !byUid.containsKey(_teacherUid)) {
          byUid[_teacherUid!] =
              '${_teacherName ?? '(docente inactivo)'} · inactivo';
          auxByUid[_teacherUid!] = false; // legacy: lo mostramos como tutor.
        }
        if (_auxiliarUid != null && !byUid.containsKey(_auxiliarUid)) {
          byUid[_auxiliarUid!] = '(auxiliar inactivo)';
          auxByUid[_auxiliarUid!] = true;
        }
        // Cache compartida para que la sección de auxiliar reuse sin
        // re-suscribirse al stream.
        _teacherNameByUid
          ..clear()
          ..addAll(byUid);
        _teacherIsAuxByUid
          ..clear()
          ..addAll(auxByUid);

        // Filtro de tutores: solo docentes NO marcados como auxiliar.
        final tutorEntries = byUid.entries
            .where((e) => auxByUid[e.key] != true)
            .toList()
          ..sort(
            (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
          );

        if (tutorEntries.isEmpty) {
          return _teacherNotice(
            icon: Icons.warning_amber_rounded,
            color: AppDesignSystem.warningColor,
            message: 'Sin tutores disponibles (todos están marcados como auxiliar)',
          );
        }

        return DropdownButtonFormField<String>(
          initialValue:
              tutorEntries.any((e) => e.key == _teacherUid) ? _teacherUid : null,
          isExpanded: true,
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Selecciona un tutor' : null,
          decoration: AdminInputs.decoration(
            label: 'Tutor *',
            prefixIcon: Icons.person_outline_rounded,
          ),
          items: tutorEntries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _teacherUid = v;
              _teacherName = byUid[v];
            });
          },
        );
      },
    );
  }

  /// Sección de docentes adicionales (polidocente).
  /// Lista compacta de chips removibles + botón para añadir desde menú.
  Widget _teacherNotice({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: AppDesignSystem.borderRadiusMD,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildAuxiliarDropdown() {
    // Candidatos: docentes marcados como auxiliar y distintos del tutor.
    // Si la lista aún no cargó (cache vacía), mostramos placeholder pasivo.
    final auxEntries = _teacherNameByUid.entries
        .where((e) =>
            _teacherIsAuxByUid[e.key] == true && e.key != _teacherUid)
        .toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('Sin auxiliar',
            style: TextStyle(
              fontSize: 13,
              color: AppDesignSystem.textSecondary,
            )),
      ),
      ...auxEntries.map(
        (e) => DropdownMenuItem<String?>(
          value: e.key,
          child: Text(e.value, overflow: TextOverflow.ellipsis),
        ),
      ),
    ];

    // Si el _auxiliarUid actual no está en la lista (auxiliar inactivo o
    // marca quitada), lo conservamos como entrada extra para no perder dato.
    if (_auxiliarUid != null &&
        !auxEntries.any((e) => e.key == _auxiliarUid)) {
      items.add(DropdownMenuItem<String?>(
        value: _auxiliarUid,
        child: Text(
          '${_teacherNameByUid[_auxiliarUid] ?? _shortUid(_auxiliarUid!)} · legacy',
          overflow: TextOverflow.ellipsis,
        ),
      ));
    }

    final hint = auxEntries.isEmpty && _auxiliarUid == null
        ? 'Sin auxiliares activos'
        : null;

    return DropdownButtonFormField<String?>(
      initialValue: _auxiliarUid,
      isExpanded: true,
      decoration: AdminInputs.decoration(
        label: 'Auxiliar (opcional)',
        hint: hint,
        prefixIcon: Icons.support_agent_rounded,
      ),
      items: items,
      onChanged: (v) => setState(() => _auxiliarUid = v),
    );
  }
}

/// Acorta un uid de Firebase para fallback visual cuando no hay nombre.
String _shortUid(String uid) {
  if (uid.length <= 8) return uid;
  return '${uid.substring(0, 4)}...${uid.substring(uid.length - 4)}';
}

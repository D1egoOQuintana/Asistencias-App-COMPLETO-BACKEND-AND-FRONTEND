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

  // Docente principal (obligatorio). En edición arranca con el actual.
  String? _teacherUid;
  String? _teacherName;
  // Docentes adicionales (polidocente). Excluye al principal.
  // Set para asegurar unicidad sin esfuerzo.
  final Set<String> _extraTeacherUids = <String>{};
  // Cache uid → nombre para chips, alimentada por el stream.
  final Map<String, String> _teacherNameByUid = <String, String>{};
  late final Stream<QuerySnapshot> _teachersStream;

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
    if (c != null) {
      for (final uid in c.effectiveTeacherUids) {
        if (uid != _teacherUid) _extraTeacherUids.add(uid);
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
          'Selecciona un docente principal',
        ),
      );
      return;
    }
    setState(() => _isLoading = true);

    final name = _name.text.trim();
    final grade = _grade.text.trim();
    final section = _section.text.trim().toUpperCase();
    final capacity = int.parse(_capacity.text.trim());

    try {
      bool ok;
      String message;

      // Construye la lista final: principal + extras, sin duplicados.
      // El service también deduplica, pero pasarla limpia evita ruido.
      final allUids = <String>{_teacherUid!, ..._extraTeacherUids}.toList();

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

                  // Docente principal (obligatorio) + docentes adicionales.
                  _buildTeacherDropdown(),
                  const SizedBox(height: 12),
                  _buildExtraTeachersSection(),
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

        // Mapear uid → name para mostrar y guardar.
        final byUid = <String, String>{};
        for (final d in docs) {
          final data = d.data() as Map<String, dynamic>;
          final uid = (data['uid'] as String?) ?? d.id;
          byUid[uid] = _displayName(data);
        }
        // Si el _teacherUid actual ya no está en la lista (docente desactivado),
        // lo conservamos como entrada extra para no perder el dato en edición.
        if (_teacherUid != null && !byUid.containsKey(_teacherUid)) {
          byUid[_teacherUid!] =
              '${_teacherName ?? '(docente inactivo)'} · inactivo';
        }
        // Cache global para que la sección de extras pueda mostrar nombres
        // sin re-suscribirse al stream.
        _teacherNameByUid
          ..clear()
          ..addAll(byUid);

        final entries = byUid.entries.toList()
          ..sort(
            (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
          );

        return DropdownButtonFormField<String>(
          initialValue: _teacherUid,
          isExpanded: true,
          validator: (v) => (v == null || v.isEmpty)
              ? 'Selecciona un docente principal'
              : null,
          decoration: AdminInputs.decoration(
            label: 'Docente principal *',
            prefixIcon: Icons.person_outline_rounded,
          ),
          items: entries
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
              // Si el nuevo principal estaba como extra, quitarlo para no
              // duplicar.
              _extraTeacherUids.remove(v);
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

  Widget _buildExtraTeachersSection() {
    // Candidatos disponibles: cualquier docente activo que no sea el principal
    // ni esté ya seleccionado como extra.
    final available =
        _teacherNameByUid.entries
            .where(
              (e) => e.key != _teacherUid && !_extraTeacherUids.contains(e.key),
            )
            .toList()
          ..sort(
            (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDesignSystem.borderRadiusMD,
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.group_add_outlined,
                size: 16,
                color: AppDesignSystem.textSecondary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Docentes adicionales',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppDesignSystem.textPrimary,
                  ),
                ),
              ),
              if (_extraTeacherUids.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${_extraTeacherUids.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppDesignSystem.primaryColor,
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: 'Añadir docente',
                enabled: available.isNotEmpty,
                position: PopupMenuPosition.under,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: AppDesignSystem.borderRadiusMD,
                  side: const BorderSide(color: _kBorder),
                ),
                onSelected: (uid) => setState(() {
                  _extraTeacherUids.add(uid);
                }),
                itemBuilder: (_) => available
                    .map(
                      (e) => PopupMenuItem<String>(
                        value: e.key,
                        child: Text(
                          e.value,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: available.isEmpty
                        ? _kBorder
                        : AppDesignSystem.primaryColor.withValues(alpha: 0.08),
                    borderRadius: AppDesignSystem.borderRadiusFull,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 14,
                        color: available.isEmpty
                            ? AppDesignSystem.textSecondary
                            : AppDesignSystem.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Añadir',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: available.isEmpty
                              ? AppDesignSystem.textSecondary
                              : AppDesignSystem.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_extraTeacherUids.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4, left: 24),
              child: Text(
                'Opcional. Si añades más de un docente, el aula queda como polidocente.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _extraTeacherUids
                    .map(
                      (uid) => _TeacherChip(
                        label: _teacherNameByUid[uid] ?? _shortUid(uid),
                        onRemove: () => setState(() {
                          _extraTeacherUids.remove(uid);
                        }),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Chip compacto para mostrar un docente adicional con botón de eliminar.
String _shortUid(String uid) {
  if (uid.length <= 8) return uid;
  return '${uid.substring(0, 4)}...${uid.substring(uid.length - 4)}';
}

class _TeacherChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _TeacherChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
      decoration: BoxDecoration(
        color: AppDesignSystem.primaryColor.withValues(alpha: 0.08),
        borderRadius: AppDesignSystem.borderRadiusFull,
        border: Border.all(
          color: AppDesignSystem.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppDesignSystem.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppDesignSystem.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

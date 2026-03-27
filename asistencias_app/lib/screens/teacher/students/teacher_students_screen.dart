import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import '../../../providers/auth_provider.dart';
import '../../../services/classroom_service.dart';
import '../../../services/student_service.dart';
import '../../../models/user_model.dart';
import '../../../models/classroom_model.dart';
import '../../../models/student_model.dart';
import '../../../theme/app_design_system.dart';
import 'teacher_create_student_screen.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

enum SortOrder { aToZ, zToA, newest, oldest }

enum StudentFilter { all, active, inactive }

/// Pantalla para que los docentes vean solo los estudiantes de sus aulas asignadas
class TeacherStudentsScreen extends StatefulWidget {
  final bool showAppBar;

  const TeacherStudentsScreen({super.key, this.showAppBar = false});

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen>
    with AutomaticKeepAliveClientMixin {
  static const Color _brandBlue = Color(0xFF1976D2);
  static const Color _outline = Color(0xFF5F6470);
  static const Color _outlineVariant = Color(0xFFC5C6D2);

  ClassroomModel? _selectedClassroom;
  bool _initializedFromArgs = false;
  bool _autoSelectionAttempted = false;

  // Variables para búsqueda y ordenamiento
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortOrder _sortOrder = SortOrder.aToZ;

  // Filtro de estado (todos, activos, inactivos)
  StudentFilter _statusFilter = StudentFilter.all;

  // Debounce y cache
  Timer? _debounceTimer;
  List<StudentModel>? _cachedStudents;
  List<ClassroomModel>? _cachedClassrooms;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Helper para comparar listas de estudiantes
  bool _areStudentListsEqual(
    List<StudentModel> list1,
    List<StudentModel> list2,
  ) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id ||
          list1[i].firstName != list2[i].firstName ||
          list1[i].lastName != list2[i].lastName ||
          list1[i].isActive != list2[i].isActive) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Inicializar desde argumentos de ruta (si vienen del Home)
    if (!_initializedFromArgs) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is ClassroomModel) {
        _selectedClassroom = args;
      }
      _initializedFromArgs = true;
    }
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.user;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final baseTheme = Theme.of(context);
    final manropeTheme = baseTheme.textTheme.apply(
      fontFamily: GoogleFonts.manrope().fontFamily,
    );

    return Theme(
      data: baseTheme.copyWith(textTheme: manropeTheme),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _selectedClassroom == null
                    ? Column(
                        children: [
                          _buildModernStudentsHeader(),
                          Expanded(
                            child: _buildClassroomsList(currentUser.uid),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildModernSelectedClassHeader(_selectedClassroom!),
                          Expanded(
                            child: _buildStudentsList(_selectedClassroom!),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernStudentsHeader() {
    final classroomsCount = _cachedClassrooms?.length ?? 0;
    final authUser = Provider.of<AuthProvider>(context, listen: false).user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopGlassBar(context, authUser, 'Centro de Alumnos'),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: AppDesignSystem.getSpaceMD(context)),
              _buildDashboardHeader(context, title: 'Centro de Alumnos'),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.dashboard_customize_outlined,
                        size: 18,
                        color: Color(0xFF1976D2),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          classroomsCount <= 2
                              ? 'Visualización directa de alumnos'
                              : 'Selecciona un aula para abrir el roster',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${classroomsCount.toString()} aula${classroomsCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: Color(0xFF1976D2),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernSelectedClassHeader(ClassroomModel classroom) {
    final classrooms = _cachedClassrooms ?? const <ClassroomModel>[];
    final authUser = Provider.of<AuthProvider>(context, listen: false).user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopGlassBar(context, authUser, 'Centro de Alumnos'),
        Container(
          padding: const EdgeInsets.only(bottom: 14),
          decoration: const BoxDecoration(
            color: Color(0xFFF8F6F6),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildDashboardHeader(context, title: 'Gestión de Alumnos'),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${classroom.name} • ${classroom.grade}° ${classroom.section}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      if (classrooms.length > 1) ...[
                        Expanded(
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: classroom.id,
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                ),
                                items: classrooms
                                    .where((c) => c.id != null)
                                    .map(
                                      (c) => DropdownMenuItem<String>(
                                        value: c.id,
                                        child: Text(
                                          '${c.grade}° ${c.section} · ${c.name}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (newClassroomId) {
                                  if (newClassroomId == null ||
                                      newClassroomId == classroom.id) {
                                    return;
                                  }
                                  final nextClassroom = classrooms.firstWhere(
                                    (c) => c.id == newClassroomId,
                                    orElse: () => classroom,
                                  );
                                  setState(() {
                                    _selectedClassroom = nextClassroom;
                                    _cachedStudents = null;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      ElevatedButton.icon(
                        onPressed: () => _showCreateStudentDialog(classroom),
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text('Registrar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopGlassBar(
    BuildContext context,
    UserModel? authUser,
    String subtitle,
  ) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppDesignSystem.getSpaceMD(context),
            vertical: AppDesignSystem.getSpaceSM(context),
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            border: Border(
              bottom: BorderSide(
                color: _outlineVariant.withValues(alpha: 0.55),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _brandBlue,
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: AppDesignSystem.getSpaceSM(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Asistencias',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        color: _brandBlue,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        color: _outline,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardHeader(BuildContext context, {required String title}) {
    return Padding(
      padding: AppDesignSystem.paddingSymmetric(
        context,
        horizontal: AppDesignSystem.spaceMD,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final titleSize = maxWidth < 360
                  ? 30.0
                  : maxWidth < 420
                  ? 34.0
                  : 40.0;

              return Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  color: _brandBlue,
                  fontSize: titleSize,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.9,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Construir lista de aulas asignadas al docente
  Widget _buildClassroomsList(String teacherUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: ClassroomService.getClassroomsByTeacherSimple(teacherUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _cachedClassrooms == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Error al cargar aulas: ${snapshot.error}'),
            ),
          );
        }

        if (snapshot.hasData) {
          _cachedClassrooms = snapshot.data!.docs
              .map((doc) => ClassroomModel.fromFirestore(doc))
              .toList();

          if (_cachedClassrooms!.length > 1 && _autoSelectionAttempted) {
            _autoSelectionAttempted = false;
          }
        }

        final classrooms = _cachedClassrooms ?? const <ClassroomModel>[];
        if (classrooms.isEmpty) {
          return const Center(
            child: Text(
              'No tienes aulas asignadas actualmente.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        if (classrooms.length <= 2 && _selectedClassroom == null) {
          if (!_autoSelectionAttempted) {
            _autoSelectionAttempted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _selectedClassroom = classrooms.first;
                _cachedStudents = null;
              });
            });
          }

          return const SizedBox.shrink();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Aulas disponibles',
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF000D33),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8E2FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${classrooms.length} aulas',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF2C4383),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...classrooms.map(_buildClassroomCard),
            ],
          ),
        );
      },
    );
  }

  /// Mostrar diálogo para editar estudiante
  void _handleEditStudent(StudentModel student) {
    // Ejecutar después del frame actual y usar el context del State
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showEditStudentDialog(context, student);
    });
  }

  void _handleDeleteStudent(StudentModel student) {
    // Ejecutar después del frame actual y usar el context del State
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showDeleteStudentDialog(context, student);
    });
  }

  Future<void> _showEditStudentDialog(
    BuildContext safeContext,
    StudentModel student,
  ) async {
    final nameCtrl = TextEditingController(text: student.firstName);
    final lastNameCtrl = TextEditingController(text: student.lastName);
    final dniCtrl = TextEditingController(text: student.dni);
    final parentPhoneCtrl = TextEditingController(
      text: student.parentPhone ?? '',
    );
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: safeContext,
      builder: (ctx) {
        final screenSize = MediaQuery.of(ctx).size;
        final isCompact = screenSize.width < 380;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: screenSize.height * 0.86,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E7FF),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFF1976D2).withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1976D2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Editar estudiante',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isCompact ? 16 : 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Actualiza la información académica',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isCompact ? 11 : 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFFE0E7FF),
                                  child: Text(
                                    student.firstName.isNotEmpty
                                        ? student.firstName[0].toUpperCase()
                                        : 'A',
                                    style: const TextStyle(
                                      color: Color(0xFF1976D2),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${student.firstName} ${student.lastName}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        'DNI actual: ${_displayDni(student.dni)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: nameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Nombre *',
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'El nombre es requerido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: lastNameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Apellido *',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'El apellido es requerido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: dniCtrl,
                            decoration: InputDecoration(
                              labelText: 'DNI',
                              helperText: 'Opcional',
                              prefixIcon: const Icon(Icons.credit_card_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null &&
                                  value.trim().isNotEmpty &&
                                  value.trim().length < 7) {
                                return 'DNI debe tener al menos 7 dígitos';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: parentPhoneCtrl,
                            decoration: InputDecoration(
                              labelText: 'Teléfono del apoderado',
                              helperText: 'Opcional',
                              prefixIcon: const Icon(Icons.call_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: isCompact
                      ? Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }

                                  final name = nameCtrl.text.trim();
                                  final lastName = lastNameCtrl.text.trim();
                                  final dni = dniCtrl.text.trim();
                                  final parentPhone = parentPhoneCtrl.text
                                      .trim();

                                  Navigator.of(ctx).pop();

                                  showDialog(
                                    context: safeContext,
                                    barrierDismissible: false,
                                    builder: (_) => Dialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.all(18),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.6,
                                              ),
                                            ),
                                            SizedBox(width: 14),
                                            Text('Actualizando estudiante...'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );

                                  final success =
                                      await StudentService.updateStudent(
                                        studentId: student.id!,
                                        firstName: name,
                                        lastName: lastName,
                                        dni: dni,
                                        classroomId: student.classroomId,
                                        parentEmail: null,
                                        parentPhone: parentPhone.isEmpty
                                            ? null
                                            : parentPhone,
                                      );

                                  if (mounted) {
                                    Navigator.of(safeContext).pop();
                                    ScaffoldMessenger.of(
                                      safeContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(
                                              success
                                                  ? Icons.check_circle
                                                  : Icons.error,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              success
                                                  ? 'Estudiante actualizado exitosamente'
                                                  : 'Error al actualizar estudiante',
                                            ),
                                          ],
                                        ),
                                        backgroundColor: success
                                            ? Colors.green
                                            : Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.save_rounded),
                                label: const Text('Guardar cambios'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1976D2),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(46),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Cancelar'),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }

                                  final name = nameCtrl.text.trim();
                                  final lastName = lastNameCtrl.text.trim();
                                  final dni = dniCtrl.text.trim();
                                  final parentPhone = parentPhoneCtrl.text
                                      .trim();

                                  Navigator.of(ctx).pop();

                                  showDialog(
                                    context: safeContext,
                                    barrierDismissible: false,
                                    builder: (_) => Dialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.all(18),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.6,
                                              ),
                                            ),
                                            SizedBox(width: 14),
                                            Text('Actualizando estudiante...'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );

                                  final success =
                                      await StudentService.updateStudent(
                                        studentId: student.id!,
                                        firstName: name,
                                        lastName: lastName,
                                        dni: dni,
                                        classroomId: student.classroomId,
                                        parentEmail: null,
                                        parentPhone: parentPhone.isEmpty
                                            ? null
                                            : parentPhone,
                                      );

                                  if (mounted) {
                                    Navigator.of(safeContext).pop();
                                    ScaffoldMessenger.of(
                                      safeContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(
                                              success
                                                  ? Icons.check_circle
                                                  : Icons.error,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              success
                                                  ? 'Estudiante actualizado exitosamente'
                                                  : 'Error al actualizar estudiante',
                                            ),
                                          ],
                                        ),
                                        backgroundColor: success
                                            ? Colors.green
                                            : Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.save_rounded),
                                label: const Text('Guardar cambios'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1976D2),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(46),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Mostrar diálogo de confirmación para eliminar estudiante
  Future<void> _showDeleteStudentDialog(
    BuildContext safeContext,
    StudentModel student,
  ) async {
    await showDialog(
      context: safeContext,
      builder: (ctx) {
        final screenSize = MediaQuery.of(ctx).size;
        final isCompact = screenSize.width < 380;
        final titleSize = isCompact ? 20.0 : 24.0;
        final subtitleSize = isCompact ? 13.0 : 15.0;

        Future<void> _confirmDelete() async {
          Navigator.of(ctx).pop();

          showDialog(
            context: safeContext,
            barrierDismissible: false,
            builder: (_) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.6),
                    ),
                    SizedBox(width: 14),
                    Text('Eliminando estudiante...'),
                  ],
                ),
              ),
            ),
          );

          final success = await StudentService.deactivateStudent(student.id!);

          if (mounted) {
            Navigator.of(safeContext).pop();
            ScaffoldMessenger.of(safeContext).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(
                      success ? Icons.check_circle : Icons.error,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      success
                          ? 'Estudiante eliminado exitosamente'
                          : 'Error al eliminar estudiante',
                    ),
                  ],
                ),
                backgroundColor: success ? Colors.green : Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: screenSize.height * 0.82,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFDAD6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFBA1A1A),
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Eliminar estudiante',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1976D2),
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '¿Deseas eliminar este estudiante del sistema?',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: subtitleSize,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF444650),
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F4F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFFDBE1FF),
                                child: Text(
                                  student.firstName.isNotEmpty
                                      ? student.firstName[0].toUpperCase()
                                      : 'A',
                                  style: const TextStyle(
                                    color: Color(0xFF1976D2),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${student.firstName} ${student.lastName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1976D2),
                                      ),
                                    ),
                                    Text(
                                      'ID: ${_displayDni(student.dni)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF444650),
                                      ),
                                    ),
                                    const Text(
                                      'Estado: activo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1976D2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFDBD1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFB59F)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: Color(0xFF77311C),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'La eliminación es permanente. Si solo deseas restringir acceso, usa la desactivación temporal.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF77311C),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: isCompact
                      ? Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _confirmDelete,
                                icon: const Icon(Icons.delete_forever_rounded),
                                label: const Text('Eliminar estudiante'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB91C1C),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Cancelar'),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.of(ctx).pop(),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _confirmDelete,
                                icon: const Icon(Icons.delete_forever_rounded),
                                label: const Text('Eliminar estudiante'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB91C1C),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Construir card de aula con diseño moderno
  Widget _buildClassroomCard(ClassroomModel classroom) {
    final enrolled = classroom.capacity > 1
        ? classroom.capacity - 1
        : classroom.capacity;
    final studentsLabel = '$enrolled estudiantes';

    return InkWell(
      onTap: () {
        if (classroom.id == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Esta aula no tiene un identificador valido.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        setState(() {
          _selectedClassroom = classroom;
          _cachedStudents = null;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE1E3E4)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000D33),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF1DA056),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFD4E4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.groups_rounded, color: Color(0xFF2C4383)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${classroom.grade}° ${classroom.section}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF000D33),
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    classroom.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF556474),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    studentsLabel,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF455B9D),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFC5C6D2)),
          ],
        ),
      ),
    );
  }

  /// Construir lista de estudiantes del aula seleccionada
  Widget _buildStudentsList(ClassroomModel classroom) {
    if (classroom.id == null) {
      return const Center(
        child: Text(
          'No se puede cargar alumnos de esta aula.',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBE1FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${classroom.grade}° ${classroom.section} - ${classroom.name}',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2C4383),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar estudiante...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFFFFFFF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF455B9D)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onChanged: (value) {
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(
                      const Duration(milliseconds: 300),
                      () {
                        if (!mounted) return;
                        setState(
                          () => _searchQuery = value.toLowerCase().trim(),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SortOrder>(
                    value: _sortOrder,
                    icon: const Icon(Icons.sort),
                    items: const [
                      DropdownMenuItem(
                        value: SortOrder.aToZ,
                        child: Text('A-Z'),
                      ),
                      DropdownMenuItem(
                        value: SortOrder.zToA,
                        child: Text('Z-A'),
                      ),
                      DropdownMenuItem(
                        value: SortOrder.newest,
                        child: Text('Nuevos'),
                      ),
                      DropdownMenuItem(
                        value: SortOrder.oldest,
                        child: Text('Antiguos'),
                      ),
                    ],
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() => _sortOrder = newValue);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: StudentService.getStudentsByClassroom(classroom.id!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _cachedStudents == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error al cargar estudiantes: ${snapshot.error}',
                    ),
                  );
                }

                if (snapshot.hasData) {
                  final incoming = snapshot.data!.docs
                      .map((doc) => StudentModel.fromFirestore(doc))
                      .toList();
                  if (_cachedStudents == null ||
                      _cachedStudents!.length != incoming.length ||
                      !_areStudentListsEqual(_cachedStudents!, incoming)) {
                    _cachedStudents = incoming;
                  }
                }

                var students = List<StudentModel>.from(
                  _cachedStudents ?? const [],
                );

                switch (_statusFilter) {
                  case StudentFilter.active:
                    students = students.where((s) => s.isActive).toList();
                    break;
                  case StudentFilter.inactive:
                    students = students.where((s) => !s.isActive).toList();
                    break;
                  case StudentFilter.all:
                    break;
                }

                if (_searchQuery.isNotEmpty) {
                  students = students.where((student) {
                    final fullName = '${student.firstName} ${student.lastName}'
                        .toLowerCase();
                    return fullName.contains(_searchQuery);
                  }).toList();
                }

                students.sort((a, b) {
                  switch (_sortOrder) {
                    case SortOrder.aToZ:
                      final lastNameCmp = a.lastName.compareTo(b.lastName);
                      if (lastNameCmp != 0) return lastNameCmp;
                      return a.firstName.compareTo(b.firstName);
                    case SortOrder.zToA:
                      final lastNameCmp = b.lastName.compareTo(a.lastName);
                      if (lastNameCmp != 0) return lastNameCmp;
                      return b.firstName.compareTo(a.firstName);
                    case SortOrder.newest:
                      return b.createdAt.compareTo(a.createdAt);
                    case SortOrder.oldest:
                      return a.createdAt.compareTo(b.createdAt);
                  }
                });

                if (students.isEmpty) {
                  return _buildAnimatedStudentResults(
                    const Center(
                      child: Text(
                        'No hay estudiantes para mostrar.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    keySeed:
                        'empty-${_sortOrder.name}-${_statusFilter.name}-${_searchQuery.length}',
                  );
                }

                return _buildAnimatedStudentResults(
                  ListView.separated(
                    key: ValueKey(
                      'list-${_sortOrder.name}-${_statusFilter.name}-${_searchQuery.length}-${students.length}',
                    ),
                    itemCount: students.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return _buildModernStudentCard(student);
                    },
                  ),
                  keySeed:
                      'list-${_sortOrder.name}-${_statusFilter.name}-${_searchQuery.length}-${students.length}',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedStudentResults(Widget child, {required String keySeed}) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (widget, animation) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final slide =
            Tween<Offset>(
              begin: const Offset(0.0, 0.04),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: widget),
        );
      },
      child: KeyedSubtree(key: ValueKey(keySeed), child: child),
    );
  }

  String _displayDni(String dni) {
    final normalized = dni.trim();
    return normalized.isEmpty ? 'Sin DNI' : normalized;
  }

  Widget _buildModernStudentCard(StudentModel student) {
    final fullName = '${student.firstName} ${student.lastName}'.trim();
    final studentIdLabel = student.dni.trim().isEmpty
        ? '#STU-SIN-DNI'
        : '#STU-${student.dni}';
    final statusColor = student.isActive
        ? const Color(0xFF1DA056)
        : const Color(0xFFBA1A1A);

    return InkWell(
      onTap: () => _showStudentDetailSheet(student),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE1E3E4), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000D33),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFD4E4F6),
              child: Text(
                student.firstName.isNotEmpty
                    ? student.firstName[0].toUpperCase()
                    : 'A',
                style: GoogleFonts.manrope(
                  color: const Color(0xFF2C4383),
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF000D33),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: $studentIdLabel',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF556474),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFC5C6D2)),
          ],
        ),
      ),
    );
  }

  Future<void> _showStudentDetailSheet(StudentModel student) async {
    final fullName = '${student.firstName} ${student.lastName}'.trim();
    final phone = (student.parentPhone?.trim().isNotEmpty ?? false)
        ? student.parentPhone!.trim()
        : 'Sin teléfono registrado';
    final classroom = _selectedClassroom;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC5C6D2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Text(
                          'Perfil del Estudiante',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF000D33),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 124,
                    height: 124,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE6EEFF), Color(0xFFD4E4F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000D33),
                          blurRadius: 26,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      student.firstName.isNotEmpty
                          ? student.firstName[0].toUpperCase()
                          : 'A',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF2C4383),
                        fontWeight: FontWeight.w800,
                        fontSize: 46,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    fullName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF000D33),
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (classroom != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1E1F4),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${classroom.grade}° ${classroom.section}',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0D1D2A),
                            ),
                          ),
                        ),
                      Text(
                        student.dni.trim().isEmpty
                            ? '#ALU-SIN-DNI'
                            : '#ALU-${student.dni}',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF556474),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailMetricCard(
                          label: 'Estado',
                          value: student.isActive ? 'Activo' : 'Inactivo',
                          accent: student.isActive
                              ? const Color(0xFF1DA056)
                              : const Color(0xFFBA1A1A),
                          icon: Icons.verified,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDetailMetricCard(
                          label: 'Apoderado',
                          value: phone == 'Sin teléfono registrado'
                              ? 'Sin número'
                              : 'Disponible',
                          accent: const Color(0xFF2C4383),
                          icon: Icons.contact_phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDetailActionButton(
                    icon: Icons.qr_code_2,
                    label: 'Ver código QR',
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF000D33),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _handleShowStudentQR(student);
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildDetailActionButton(
                    icon: Icons.contact_phone,
                    label: 'Contactar apoderado',
                    foregroundColor: const Color(0xFF0D1D2A),
                    backgroundColor: const Color(0xFFD1E1F4),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showContactParentDialog(student);
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildDetailActionButton(
                    icon: Icons.edit_note,
                    label: 'Editar estado académico',
                    foregroundColor: const Color(0xFF000D33),
                    backgroundColor: Colors.white,
                    borderColor: const Color(0xFFC5C6D2),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _handleEditStudent(student);
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildDetailActionButton(
                    icon: Icons.delete_forever_rounded,
                    label: 'Eliminar estudiante',
                    foregroundColor: const Color(0xFFBA1A1A),
                    backgroundColor: const Color(0xFFFFF1F2),
                    borderColor: const Color(0xFFFECACA),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _handleDeleteStudent(student);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailMetricCard({
    required String label,
    required String value,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E3E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF556474),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF000D33),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailActionButton({
    required IconData icon,
    required String label,
    required Color foregroundColor,
    required Color backgroundColor,
    Color? borderColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: borderColor == null
                ? BorderSide.none
                : BorderSide(color: borderColor),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: foregroundColor.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showContactParentDialog(StudentModel student) async {
    final parentPhone = (student.parentPhone?.trim().isNotEmpty ?? false)
        ? student.parentPhone!.trim()
        : '';
    final messageCtrl = TextEditingController(
      text:
          'Hola, le escribo desde Asistencias sobre ${student.firstName} ${student.lastName}.',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contactar apoderado',
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF000D33),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  parentPhone.isEmpty ? 'Sin teléfono registrado' : parentPhone,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF556474),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Mensaje',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: parentPhone.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: parentPhone),
                                );
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Número copiado al portapapeles',
                                    ),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar número'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: messageCtrl.text.trim()),
                          );
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mensaje copiado al portapapeles'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('Copiar mensaje'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF000D33),
                          foregroundColor: Colors.white,
                        ),
                      ),
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

  Future<void> _showCreateStudentDialog(ClassroomModel classroom) async {
    final created = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        settings: const RouteSettings(name: 'teacher-create-student'),
        transitionDuration: AppDesignSystem.durationFast,
        reverseTransitionDuration: AppDesignSystem.durationFast,
        pageBuilder: (context, animation, secondaryAnimation) {
          return TeacherCreateStudentScreen(classroom: classroom);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: AppDesignSystem.curveSnappy,
          );

          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.15, 0),
            end: Offset.zero,
          ).animate(curvedAnimation);

          final fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(curvedAnimation);

          return SlideTransition(
            position: slideAnimation,
            child: FadeTransition(opacity: fadeAnimation, child: child),
          );
        },
      ),
    );

    if (!mounted || created != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Estudiante creado exitosamente'),
          ],
        ),
        backgroundColor: const Color(0xFF1DA056),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // (Card de estudiante tipo ListTile removido; ahora usamos _StudentCard compacto en grilla)

  // Método de descarga QR obsoleto removido (se usa la acción dentro del modal de QR)

  void _showStudentQR(StudentModel student) {
    showDialog(
      context: context,
      builder: (context) => _StudentQRDialog(student: student),
    );
  }

  void _handleShowStudentQR(StudentModel student) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showStudentQR(student);
    });
  }
}

class _StudentQRDialog extends StatelessWidget {
  final StudentModel student;

  const _StudentQRDialog({required this.student});

  Future<void> _downloadQR(BuildContext context) async {
    try {
      final dniLabel = student.dni.trim().isEmpty ? 'Sin DNI' : student.dni;

      // Crear el PDF
      final pdf = pw.Document();

      // Datos del QR
      final qrData = {
        'type': 'student',
        'dni': student.dni,
        'name': '${student.firstName} ${student.lastName}',
        'classroomId': student.classroomId,
        'id': student.id,
      };

      // Generar el QR como imagen
      final qrPainter = QrPainter(
        data: jsonEncode(qrData),
        version: QrVersions.auto,
        gapless: false,
      );

      // Crear la imagen del QR
      final qrImage = await qrPainter.toImage(300);
      final qrByteData = await qrImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final qrBytes = qrByteData!.buffer.asUint8List();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  // Título
                  pw.Text(
                    'Código QR del Estudiante',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),

                  pw.SizedBox(height: 30),

                  // Información del estudiante
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          '${student.firstName} ${student.lastName}',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          'ID: $dniLabel',
                          style: const pw.TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 30),

                  // Código QR
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Image(
                      pw.MemoryImage(qrBytes),
                      width: 200,
                      height: 200,
                    ),
                  ),

                  pw.SizedBox(height: 20),

                  pw.Text(
                    'Escaneá este código para registrar asistencia',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Obtener directorio de documentos temporales
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'QR_${student.firstName}_${student.lastName}_${dniLabel.replaceAll(' ', '_')}.pdf';
      final file = File('${tempDir.path}/$fileName');

      // Guardar el PDF
      await file.writeAsBytes(await pdf.save());

      // Compartir el archivo
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Código QR de ${student.firstName} ${student.lastName}',
        subject: 'QR del estudiante $dniLabel',
      );

      // Mostrar mensaje de éxito
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'QR compartido correctamente para ${student.firstName} ${student.lastName}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Error comentado para producción
      // print('Error al generar QR: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al descargar el QR'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700 || screenSize.width < 400;
    final titleSize = isSmallScreen ? 15.0 : 18.0;
    final subtitleSize = isSmallScreen ? 11.0 : 12.0;

    final qrData = {
      'type': 'student',
      'dni': student.dni,
      'name': '${student.firstName} ${student.lastName}',
      'classroomId': student.classroomId,
      'id': student.id,
    };

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenSize.height * (isSmallScreen ? 0.9 : 0.84),
          maxWidth: 560,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                isSmallScreen ? 12 : 16,
                isSmallScreen ? 12 : 14,
                isSmallScreen ? 12 : 16,
                isSmallScreen ? 10 : 12,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFD8E2FF),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFF1976D2).withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: isSmallScreen ? 36 : 40,
                    height: isSmallScreen ? 36 : 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.qr_code_2_rounded,
                      color: Colors.white,
                      size: isSmallScreen ? 20 : 22,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Código QR del estudiante',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF1976D2),
                            fontWeight: FontWeight.w800,
                            fontSize: titleSize,
                          ),
                        ),
                        Text(
                          'Comparte o descarga el código',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF2C4383),
                            fontWeight: FontWeight.w600,
                            fontSize: subtitleSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFADC7FF)),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        size: isSmallScreen ? 18 : 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: isSmallScreen ? 20 : 22,
                                backgroundColor: const Color(0xFFDBE1FF),
                                child: Text(
                                  student.firstName.isNotEmpty
                                      ? student.firstName[0].toUpperCase()
                                      : 'A',
                                  style: TextStyle(
                                    color: const Color(0xFF1976D2),
                                    fontWeight: FontWeight.w800,
                                    fontSize: isSmallScreen ? 14 : 16,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF22C55E),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${student.firstName} ${student.lastName}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1976D2),
                                    fontSize: isSmallScreen ? 14 : 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE1E3E4),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: const Text(
                                        'DNI',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF444650),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        student.dni.trim().isEmpty
                                            ? 'Sin DNI'
                                            : student.dni,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: const Color(0xFF1976D2),
                                          fontWeight: FontWeight.w700,
                                          fontSize: isSmallScreen ? 12 : 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 12),
                    Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x120F172A),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: QrImageView(
                              data: jsonEncode(qrData),
                              version: QrVersions.auto,
                              size: isSmallScreen
                                  ? (screenSize.width * 0.42).clamp(
                                      140.0,
                                      185.0,
                                    )
                                  : (screenSize.width * 0.45).clamp(
                                      180.0,
                                      240.0,
                                    ),
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: _buildQrCornerMark(),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Transform.rotate(
                            angle: 1.57,
                            child: _buildQrCornerMark(),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: Transform.rotate(
                            angle: -1.57,
                            child: _buildQrCornerMark(),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Transform.rotate(
                            angle: 3.14,
                            child: _buildQrCornerMark(),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 12),
                    Text(
                      'Este código es personal e intransferible. Úsalo para registrar asistencia.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF444650),
                        fontSize: isSmallScreen ? 11 : 12,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F5),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
              ),
              child: isSmallScreen
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _downloadQR(context),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Descargar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Cerrar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1976D2),
                              side: const BorderSide(color: Color(0xFFC5C6D2)),
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Cerrar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1976D2),
                              side: const BorderSide(color: Color(0xFFC5C6D2)),
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _downloadQR(context),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Descargar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            SizedBox(
              height: 4,
              child: Row(
                children: const [
                  Expanded(
                    flex: 1,
                    child: ColoredBox(color: Color(0xFF1976D2)),
                  ),
                  Expanded(
                    flex: 2,
                    child: ColoredBox(color: Color(0xFF1976D2)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCornerMark() {
    return SizedBox(
      width: 22,
      height: 22,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: const Color(0xFF1976D2), width: 2.4),
            left: BorderSide(color: const Color(0xFF1976D2), width: 2.4),
          ),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(4)),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import '../../../providers/auth_provider.dart';
import '../../../services/classroom_service.dart';
import '../../../services/student_service.dart';
import '../../../models/classroom_model.dart';
import '../../../models/student_model.dart';
// imports cleaned: removed unused design/system widgets to avoid warnings
import '../../../widgets/student/student_card_new.dart';
import '../../../widgets/classroom/classroom_card.dart';
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
  const TeacherStudentsScreen({super.key});

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen>
    with AutomaticKeepAliveClientMixin {
  ClassroomModel? _selectedClassroom;
  bool _initializedFromArgs = false;

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
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header compacto responsivo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.school,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Gestión de Estudiantes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Mostrar aulas asignadas al docente
          Expanded(
            child: _selectedClassroom == null
                ? _buildClassroomsList(currentUser.uid)
                : _buildStudentsList(_selectedClassroom!),
          ),
        ],
      ),
    );
  }

  /// Construir lista de aulas asignadas al docente
  Widget _buildClassroomsList(String teacherUid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.class_, size: 24),
            const SizedBox(width: 8),
            Text(
              'Mis Aulas Asignadas',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: ClassroomService.getClassroomsByTeacherSimple(teacherUid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 64),
                      const SizedBox(height: 16),
                      Text('Error al cargar aulas: ${snapshot.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.class_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No tienes aulas asignadas',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Contacta al administrador para que te asigne aulas',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              // Actualizar cache de aulas
              final newClassrooms = snapshot.data!.docs
                  .map((doc) => ClassroomModel.fromFirestore(doc))
                  .toList();

              if (_cachedClassrooms == null ||
                  _cachedClassrooms!.length != newClassrooms.length) {
                _cachedClassrooms = newClassrooms;
              }

              final classrooms = _cachedClassrooms!;

              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  childAspectRatio: 1.3, // Menos altura, más compacto
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: classrooms.length,
                itemBuilder: (context, index) {
                  final classroom = classrooms[index];
                  return _buildClassroomCard(classroom);
                },
              );
            },
          ),
        ),
      ],
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
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.edit, color: Colors.blue.shade600, size: 28),
              const SizedBox(width: 12),
              const Text('Editar estudiante'),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(safeContext).size.width * 0.8,
              maxHeight: MediaQuery.of(safeContext).size.height * 0.65,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar del estudiante
                    Center(
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          student.firstName[0].toUpperCase(),
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Campos del formulario
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nombre *',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
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
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: lastNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Apellido *',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
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
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: dniCtrl,
                      decoration: InputDecoration(
                        labelText: 'DNI *',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El DNI es requerido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: parentPhoneCtrl,
                      decoration: InputDecoration(
                        labelText: 'Teléfono del apoderado',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        helperText: 'Opcional',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                final name = nameCtrl.text.trim();
                final lastName = lastNameCtrl.text.trim();
                final dni = dniCtrl.text.trim();
                final parentPhone = parentPhoneCtrl.text.trim();

                Navigator.of(ctx).pop();

                // Mostrar loader elegante
                showDialog(
                  context: safeContext,
                  barrierDismissible: false,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    content: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(width: 20),
                          const Text('Actualizando estudiante...'),
                        ],
                      ),
                    ),
                  ),
                );

                final success = await StudentService.updateStudent(
                  studentId: student.id!,
                  firstName: name,
                  lastName: lastName,
                  dni: dni,
                  classroomId: student.classroomId,
                  parentEmail: null,
                  parentPhone: parentPhone.isEmpty ? null : parentPhone,
                );

                if (mounted) {
                  Navigator.of(safeContext).pop(); // Cerrar loader

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
                                ? 'Estudiante actualizado exitosamente'
                                : 'Error al actualizar estudiante',
                          ),
                        ],
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Guardar cambios'),
            ),
          ],
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
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade600,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text('Eliminar estudiante'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Estás seguro de que deseas eliminar a:',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.purple.shade100,
                      child: Text(
                        student.firstName[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${student.firstName} ${student.lastName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'DNI: ${student.dni}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta acción desactivará al estudiante. No se eliminará permanentemente.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();

                // Mostrar loader elegante
                showDialog(
                  context: safeContext,
                  barrierDismissible: false,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    content: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(width: 20),
                          const Text('Eliminando estudiante...'),
                        ],
                      ),
                    ),
                  ),
                );

                final success = await StudentService.deactivateStudent(
                  student.id!,
                );

                if (mounted) {
                  Navigator.of(safeContext).pop(); // Cerrar loader

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
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  /// Construir card de aula con diseño moderno
  Widget _buildClassroomCard(ClassroomModel classroom) {
    return ClassroomCard(
      classroom: classroom,
      onTap: () {
        setState(() {
          _selectedClassroom = classroom;
          _cachedStudents = null; // Limpiar cache al cambiar aula
        });
      },
      compact: false,
      showScheduleInfo: false,
    );
  }

  /// Construir lista de estudiantes del aula seleccionada
  Widget _buildStudentsList(ClassroomModel classroom) {
    return CustomScrollView(
      slivers: [
        // Header compacto con botón de regreso - SliverToBoxAdapter
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedClassroom = null;
                    });
                  },
                  icon: const Icon(Icons.arrow_back, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${classroom.grade}° ${classroom.section}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (classroom.name.isNotEmpty)
                        Text(
                          classroom.name,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Botón más compacto para pantallas pequeñas
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmallScreen =
                        MediaQuery.of(context).size.width < 400;
                    return isSmallScreen
                        ? IconButton(
                            onPressed: () =>
                                _showCreateStudentDialog(classroom),
                            icon: const Icon(Icons.person_add),
                            tooltip: 'Registrar estudiante',
                          )
                        : ElevatedButton.icon(
                            onPressed: () =>
                                _showCreateStudentDialog(classroom),
                            icon: const Icon(Icons.person_add, size: 16),
                            label: const Text(
                              'Registrar',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                          );
                  },
                ),
              ],
            ),
          ),
        ),

        // Barra de búsqueda y controles de ordenamiento responsivos - SliverToBoxAdapter
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmallScreen = constraints.maxWidth < 600;

                if (isSmallScreen) {
                  return Column(
                    children: [
                      // Campo de búsqueda ocupa toda la fila
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar estudiante...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          // Cancelar el timer anterior si existe
                          _debounceTimer?.cancel();

                          // Crear nuevo timer de 300ms
                          _debounceTimer = Timer(
                            const Duration(milliseconds: 300),
                            () {
                              setState(() {
                                _searchQuery = value.toLowerCase().trim();
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      // Selector de ordenamiento en fila separada
                      Row(
                        children: [
                          const Icon(Icons.sort, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Ordenar:',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<SortOrder>(
                              value: _sortOrder,
                              isExpanded: true,
                              isDense: true,
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
                                  child: Text('Más recientes'),
                                ),
                                DropdownMenuItem(
                                  value: SortOrder.oldest,
                                  child: Text('Más antiguos'),
                                ),
                              ],
                              onChanged: (SortOrder? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _sortOrder = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  // Layout horizontal para pantallas grandes
                  return Row(
                    children: [
                      // Campo de búsqueda
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText:
                                'Buscar estudiante por nombre o apellido...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (value) {
                            // Cancelar el timer anterior si existe
                            _debounceTimer?.cancel();

                            // Crear nuevo timer de 300ms
                            _debounceTimer = Timer(
                              const Duration(milliseconds: 300),
                              () {
                                setState(() {
                                  _searchQuery = value.toLowerCase().trim();
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Selector de ordenamiento
                      DropdownButton<SortOrder>(
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
                            child: Text('Más recientes'),
                          ),
                          DropdownMenuItem(
                            value: SortOrder.oldest,
                            child: Text('Más antiguos'),
                          ),
                        ],
                        onChanged: (SortOrder? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _sortOrder = newValue;
                            });
                          }
                        },
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ),

        // Panel de estadísticas y filtros - SliverToBoxAdapter
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: StreamBuilder<QuerySnapshot>(
              stream: StudentService.getStudentsByClassroom(classroom.id!),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final allStudents = snapshot.data!.docs
                    .map((doc) => StudentModel.fromFirestore(doc))
                    .toList();

                final totalCount = allStudents.length;
                final activeCount = allStudents.where((s) => s.isActive).length;
                final inactiveCount = totalCount - activeCount;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Estadísticas
                      Row(
                        children: [
                          _buildStatChip(
                            icon: Icons.people,
                            label: 'Total',
                            count: totalCount,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          _buildStatChip(
                            icon: Icons.check_circle,
                            label: 'Activos',
                            count: activeCount,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          _buildStatChip(
                            icon: Icons.cancel,
                            label: 'Inactivos',
                            count: inactiveCount,
                            color: Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      // Filtros
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Todos'),
                            selected: _statusFilter == StudentFilter.all,
                            onSelected: (selected) {
                              setState(() {
                                _statusFilter = StudentFilter.all;
                              });
                            },
                          ),
                          FilterChip(
                            label: const Text('Activos'),
                            selected: _statusFilter == StudentFilter.active,
                            onSelected: (selected) {
                              setState(() {
                                _statusFilter = StudentFilter.active;
                              });
                            },
                            selectedColor: Colors.green[100],
                          ),
                          FilterChip(
                            label: const Text('Inactivos'),
                            selected: _statusFilter == StudentFilter.inactive,
                            onSelected: (selected) {
                              setState(() {
                                _statusFilter = StudentFilter.inactive;
                              });
                            },
                            selectedColor: Colors.red[100],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // Lista de estudiantes - SliverPadding con SliverGrid
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 16.0),
          sliver: StreamBuilder<QuerySnapshot>(
            stream: StudentService.getStudentsByClassroom(classroom.id!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 64),
                        const SizedBox(height: 16),
                        Text('Error al cargar estudiantes: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No hay estudiantes en esta aula',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Obtener estudiantes y actualizar cache solo si los datos cambiaron
              final newStudents = snapshot.data!.docs
                  .map((doc) => StudentModel.fromFirestore(doc))
                  .toList();

              // Actualizar cache solo si los datos son diferentes
              if (_cachedStudents == null ||
                  _cachedStudents!.length != newStudents.length ||
                  !_areStudentListsEqual(_cachedStudents!, newStudents)) {
                _cachedStudents = newStudents;
              }

              // Usar la cache para evitar rebuilds innecesarios
              List<StudentModel> students = List.from(_cachedStudents!);

              // Aplicar filtrado por estado
              switch (_statusFilter) {
                case StudentFilter.active:
                  students = students.where((s) => s.isActive).toList();
                  break;
                case StudentFilter.inactive:
                  students = students.where((s) => !s.isActive).toList();
                  break;
                case StudentFilter.all:
                  // No filtrar, mostrar todos
                  break;
              }

              // Aplicar filtrado por búsqueda
              if (_searchQuery.isNotEmpty) {
                students = students.where((student) {
                  final fullName = '${student.firstName} ${student.lastName}'
                      .toLowerCase();
                  return fullName.contains(_searchQuery);
                }).toList();
              }

              // Aplicar ordenamiento
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

              // Si no hay estudiantes después del filtrado, mostrar mensaje apropiado
              if (students.isEmpty && _searchQuery.isNotEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No se encontraron estudiantes\ncon "$_searchQuery"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          child: const Text('Limpiar búsqueda'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Usar SliverList con Wrap para que las tarjetas se ajusten a su contenido
              return SliverPadding(
                padding: EdgeInsets.zero,
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Agrupar estudiantes en filas según el crossAxisCount
                      final crossAxisCount = _getStudentCrossAxisCount(context);
                      final startIndex = index * crossAxisCount;
                      final endIndex = (startIndex + crossAxisCount).clamp(
                        0,
                        students.length,
                      );

                      if (startIndex >= students.length) return null;

                      final rowStudents = students.sublist(
                        startIndex,
                        endIndex,
                      );

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom:
                              index <
                                  (students.length / crossAxisCount).ceil() - 1
                              ? 12.0
                              : 0,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: rowStudents.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final student = entry.value;
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: idx < rowStudents.length - 1
                                      ? 12.0
                                      : 0,
                                ),
                                child: StudentCard(
                                  student: student,
                                  onTap: () => _handleShowStudentQR(student),
                                  onEdit: () => _handleEditStudent(student),
                                  onDelete: () => _handleDeleteStudent(student),
                                  onGenerateQR: () =>
                                      _handleShowStudentQR(student),
                                  compact: true,
                                  showActions: true,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                    childCount:
                        (students.length / _getStudentCrossAxisCount(context))
                            .ceil(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateStudentDialog(ClassroomModel classroom) async {
    final nameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final dniCtrl = TextEditingController();
    final parentPhoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.person_add, color: Colors.green.shade600, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nuevo estudiante'),
                    Text(
                      '${classroom.grade}° ${classroom.section}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar placeholder
                    Center(
                      child: CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.green.shade100,
                        child: Icon(
                          Icons.person_add,
                          size: 40,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Nombre
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nombre *',
                        hintText: 'Ingresa el nombre',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El nombre es requerido';
                        }
                        if (value.trim().length < 2) {
                          return 'Nombre muy corto';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Apellido
                    TextFormField(
                      controller: lastNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Apellido *',
                        hintText: 'Ingresa el apellido',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El apellido es requerido';
                        }
                        if (value.trim().length < 2) {
                          return 'Apellido muy corto';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // DNI
                    TextFormField(
                      controller: dniCtrl,
                      decoration: InputDecoration(
                        labelText: 'DNI *',
                        hintText: 'Ingresa el DNI',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El DNI es requerido';
                        }
                        if (value.trim().length < 7) {
                          return 'DNI debe tener al menos 7 dígitos';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Teléfono
                    TextFormField(
                      controller: parentPhoneCtrl,
                      decoration: InputDecoration(
                        labelText: 'Teléfono del apoderado',
                        hintText: 'Opcional',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        helperText: 'Campo opcional',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                // Validar formulario
                if (!formKey.currentState!.validate()) {
                  return;
                }

                final firstName = nameCtrl.text.trim();
                final lastName = lastNameCtrl.text.trim();
                final dni = dniCtrl.text.trim();

                Navigator.of(ctx).pop();

                // Mostrar loader
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    content: const Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 20),
                          Text('Creando estudiante...'),
                        ],
                      ),
                    ),
                  ),
                );

                final res = await StudentService.createStudent(
                  firstName: firstName,
                  lastName: lastName,
                  dni: dni,
                  classroomId: classroom.id!,
                  parentEmail: null,
                  parentPhone: parentPhoneCtrl.text.trim().isEmpty
                      ? null
                      : parentPhoneCtrl.text.trim(),
                );

                if (!mounted) return;
                Navigator.of(context).pop(); // Cerrar loader

                if (res['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Estudiante creado exitosamente'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              res['message'] ?? 'Error al crear estudiante',
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.save, size: 20),
              label: const Text('Crear estudiante'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // (Card de estudiante tipo ListTile removido; ahora usamos _StudentCard compacto en grilla)

  // Método de descarga QR obsoleto removido (se usa la acción dentro del modal de QR)

  /// Obtener número de columnas según el tamaño de pantalla
  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    if (width > 600) return 2;
    return 1; // Una columna para dispositivos muy pequeños
  }

  /// Obtener número de columnas para estudiantes según el tamaño de pantalla
  int _getStudentCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Optimizado para dispositivos pequeños como Motorola
    if (width > 1200) return 3;
    if (width > 800) return 2;
    if (width > 500) return 2; // Tablets pequeños: 2 columnas
    return 1; // Móviles: 1 columna para evitar overflow
  }

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

  /// Widget para mostrar un chip de estadística
  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentQRDialog extends StatelessWidget {
  final StudentModel student;

  const _StudentQRDialog({required this.student});

  Future<void> _downloadQR(BuildContext context) async {
    try {
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
                          'ID: ${student.dni}',
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
          'QR_${student.firstName}_${student.lastName}_${student.dni}.pdf';
      final file = File('${tempDir.path}/$fileName');

      // Guardar el PDF
      await file.writeAsBytes(await pdf.save());

      // Compartir el archivo
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Código QR de ${student.firstName} ${student.lastName}',
        subject: 'QR del estudiante ${student.dni}',
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

    final qrData = {
      'type': 'student',
      'dni': student.dni,
      'name': '${student.firstName} ${student.lastName}',
      'classroomId': student.classroomId,
      'id': student.id,
    };

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenSize.height * (isSmallScreen ? 0.85 : 0.8),
          maxWidth: screenSize.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header fijo
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(color: Colors.purple.shade200),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.qr_code,
                    color: Colors.purple.shade700,
                    size: isSmallScreen ? 20 : 24,
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Expanded(
                    child: Text(
                      'QR del Estudiante',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: isSmallScreen ? 18 : 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Contenido scrolleable
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nombre del estudiante responsivo
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${student.firstName} ${student.lastName}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade700,
                                  fontSize: isSmallScreen ? 14 : 16,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isSmallScreen ? 1 : 2),
                          Text(
                            'DNI: ${student.dni}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.grey.shade600,
                                  fontSize: isSmallScreen ? 11 : 12,
                                ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 8 : 12),

                    // QR Code responsivo
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(
                        child: QrImageView(
                          data: jsonEncode(qrData),
                          version: QrVersions.auto,
                          size: isSmallScreen
                              ? (screenSize.width * 0.35).clamp(120.0, 160.0)
                              : (screenSize.width * 0.4).clamp(160.0, 200.0),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 8 : 12),
                  ],
                ),
              ),
            ),

            // Botones fijos en la parte inferior
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _downloadQR(context),
                      icon: Icon(Icons.download, size: isSmallScreen ? 14 : 16),
                      label: Text(
                        'Descargar',
                        style: TextStyle(fontSize: isSmallScreen ? 11 : 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple.shade700,
                        side: BorderSide(color: Colors.purple.shade700),
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 6 : 8,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, size: isSmallScreen ? 14 : 16),
                      label: Text(
                        'Cerrar',
                        style: TextStyle(fontSize: isSmallScreen ? 11 : 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 6 : 8,
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
  }
}

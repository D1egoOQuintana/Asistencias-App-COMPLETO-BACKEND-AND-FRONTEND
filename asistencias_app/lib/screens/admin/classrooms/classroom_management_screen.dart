import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/classroom_model.dart';
import '../../../models/user_model.dart';
import '../../../services/classroom_service.dart';
import '../../../services/admin_service_new.dart';

class ClassroomManagementScreen extends StatefulWidget {
  const ClassroomManagementScreen({super.key});

  @override
  State<ClassroomManagementScreen> createState() =>
      _ClassroomManagementScreenState();
}

class _ClassroomManagementScreenState extends State<ClassroomManagementScreen> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController();
  final _sectionController = TextEditingController();
  final _capacityController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedTeacherId;
  String? _selectedTeacherName;
  bool _isSearching = false;
  List<ClassroomModel> _searchResults = [];
  ClassroomModel? _editingClassroom;
  bool _isFormVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _gradeController.dispose();
    _sectionController.dispose();
    _capacityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _searchClassrooms() async {
    if (_searchController.text.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults.clear();
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await ClassroomService.searchClassrooms(
        _searchController.text.trim(),
      );
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        _showSnackBar('Error al buscar salones: $e', isError: true);
      }
    }
  }

  void _showCreateForm() {
    _clearForm();
    setState(() {
      _editingClassroom = null;
      _isFormVisible = true;
    });
  }

  void _showEditForm(ClassroomModel classroom) {
    _fillForm(classroom);
    setState(() {
      _editingClassroom = classroom;
      _isFormVisible = true;
    });
  }

  void _clearForm() {
    _nameController.clear();
    _gradeController.clear();
    _sectionController.clear();
    _capacityController.clear();
    _descriptionController.clear();
    _selectedTeacherId = null;
    _selectedTeacherName = null;
  }

  void _fillForm(ClassroomModel classroom) {
    _nameController.text = classroom.name;
    _gradeController.text = classroom.grade;
    _sectionController.text = classroom.section;
    _capacityController.text = classroom.capacity.toString();
    _descriptionController.text = classroom.description ?? '';
    _selectedTeacherId = classroom.teacherUid;
    _selectedTeacherName = classroom.teacherName;
  }

  Future<void> _saveClassroom() async {
    if (!_validateForm()) return;

    try {
      bool success;
      if (_editingClassroom == null) {
        // Crear salón
        final result = await ClassroomService.createClassroom(
          name: _nameController.text.trim(),
          grade: _gradeController.text.trim(),
          section: _sectionController.text.trim(),
          capacity: int.parse(_capacityController.text.trim()),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          teacherUid: _selectedTeacherId,
          teacherName: _selectedTeacherName,
        );
        success = result['success'];
        _showSnackBar(result['message'], isError: !success);
      } else {
        // Actualizar salón
        success = await ClassroomService.updateClassroom(
          classroomId: _editingClassroom!.id!,
          name: _nameController.text.trim(),
          grade: _gradeController.text.trim(),
          section: _sectionController.text.trim(),
          capacity: int.parse(_capacityController.text.trim()),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          teacherUid: _selectedTeacherId,
          teacherName: _selectedTeacherName,
        );
        _showSnackBar(
          success
              ? 'Salón actualizado exitosamente'
              : 'Error al actualizar salón',
          isError: !success,
        );
      }

      if (success) {
        setState(() => _isFormVisible = false);
        _clearForm();
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  bool _validateForm() {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('El nombre del salón es requerido', isError: true);
      return false;
    }
    if (_gradeController.text.trim().isEmpty) {
      _showSnackBar('El grado es requerido', isError: true);
      return false;
    }
    if (_sectionController.text.trim().isEmpty) {
      _showSnackBar('La sección es requerida', isError: true);
      return false;
    }
    if (_capacityController.text.trim().isEmpty) {
      _showSnackBar('La capacidad es requerida', isError: true);
      return false;
    }

    final capacity = int.tryParse(_capacityController.text.trim());
    if (capacity == null || capacity <= 0) {
      _showSnackBar(
        'La capacidad debe ser un número válido mayor a 0',
        isError: true,
      );
      return false;
    }

    return true;
  }

  Future<void> _toggleClassroomStatus(ClassroomModel classroom) async {
    final success = classroom.isActive
        ? await ClassroomService.deactivateClassroom(classroom.id!)
        : await ClassroomService.reactivateClassroom(classroom.id!);

    _showSnackBar(
      success ? 'Estado del salón actualizado' : 'Error al actualizar estado',
      isError: !success,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Gestión de Salones'),
        backgroundColor: const Color(0xFF424242),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barra de búsqueda y botón crear
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, grado o sección...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (_) => _searchClassrooms(),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showCreateForm,
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF424242),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenido principal
          Expanded(
            child: _isFormVisible
                ? _buildClassroomForm()
                : _buildClassroomsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildClassroomForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _editingClassroom == null ? 'Crear Salón' : 'Editar Salón',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() => _isFormVisible = false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre del Salón *',
                                border: OutlineInputBorder(),
                              ),
                              textCapitalization: TextCapitalization.words,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _gradeController,
                              decoration: const InputDecoration(
                                labelText: 'Grado *',
                                border: OutlineInputBorder(),
                                hintText: 'Ej: 1°, 2°, 3°...',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _sectionController,
                              decoration: const InputDecoration(
                                labelText: 'Sección *',
                                border: OutlineInputBorder(),
                                hintText: 'Ej: A, B, C...',
                              ),
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _capacityController,
                              decoration: const InputDecoration(
                                labelText: 'Capacidad *',
                                border: OutlineInputBorder(),
                                hintText: 'Número de estudiantes',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: AdminService.getTeachersStream(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const CircularProgressIndicator();
                          }

                          final teachers = snapshot.data!.docs;
                          return DropdownButtonFormField<String>(
                            initialValue: _selectedTeacherId,
                            decoration: const InputDecoration(
                              labelText: 'Docente Asignado (Opcional)',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Sin asignar'),
                              ),
                              ...teachers.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final teacher = UserModel.fromFirestore(
                                  doc.id,
                                  data,
                                );
                                return DropdownMenuItem(
                                  value: doc.id,
                                  child: Text(teacher.fullName),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedTeacherId = value;
                                if (value != null) {
                                  final teacher = teachers.firstWhere(
                                    (doc) => doc.id == value,
                                  );
                                  final data =
                                      teacher.data() as Map<String, dynamic>;
                                  final teacherModel = UserModel.fromFirestore(
                                    teacher.id,
                                    data,
                                  );
                                  _selectedTeacherName = teacherModel.fullName;
                                } else {
                                  _selectedTeacherName = null;
                                }
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Descripción (Opcional)',
                          border: OutlineInputBorder(),
                          hintText: 'Información adicional sobre el salón',
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () =>
                                setState(() => _isFormVisible = false),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _saveClassroom,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF424242),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              _editingClassroom == null ? 'Crear' : 'Guardar',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassroomsList() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.trim().isNotEmpty) {
      // Mostrar resultados de búsqueda
      if (_searchResults.isEmpty) {
        return const Center(child: Text('No se encontraron salones'));
      }
      return _buildClassroomsGrid(_searchResults);
    }

    // Mostrar todos los salones
    return StreamBuilder<QuerySnapshot>(
      stream: ClassroomService.getAllClassrooms(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay salones registrados'));
        }

        final classrooms = snapshot.data!.docs
            .map((doc) => ClassroomModel.fromFirestore(doc))
            .toList();

        return _buildClassroomsGrid(classrooms);
      },
    );
  }

  Widget _buildClassroomsGrid(List<ClassroomModel> classrooms) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 3 : 1,
            childAspectRatio: isWide ? 1.0 : 2.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: classrooms.length,
          itemBuilder: (context, index) {
            final classroom = classrooms[index];
            return _buildClassroomCard(classroom);
          },
        );
      },
    );
  }

  Widget _buildClassroomCard(ClassroomModel classroom) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classroom.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Grado: ${classroom.grade} - Sección: ${classroom.section}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      Text(
                        'Capacidad: ${classroom.capacity} estudiantes',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: classroom.isActive ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    classroom.isActive ? 'Activo' : 'Inactivo',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (classroom.teacherName != null)
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Docente: ${classroom.teacherName}',
                      style: const TextStyle(color: Colors.blue, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            else
              const Row(
                children: [
                  Icon(Icons.person_off, size: 16, color: Colors.orange),
                  SizedBox(width: 4),
                  Text(
                    'Sin docente asignado',
                    style: TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ],
              ),
            if (classroom.description != null &&
                classroom.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                classroom.description!,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _showEditForm(classroom),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Editar'),
                ),
                TextButton.icon(
                  onPressed: () => _toggleClassroomStatus(classroom),
                  icon: Icon(
                    classroom.isActive ? Icons.block : Icons.check_circle,
                    size: 16,
                  ),
                  label: Text(classroom.isActive ? 'Desactivar' : 'Activar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

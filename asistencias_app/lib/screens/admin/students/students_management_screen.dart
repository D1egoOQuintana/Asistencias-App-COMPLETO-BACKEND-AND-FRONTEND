import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/student_model.dart';
import '../../../models/classroom_model.dart';
import '../../../services/student_service.dart';
import '../../../services/classroom_service.dart';

class StudentsManagementScreen extends StatefulWidget {
  const StudentsManagementScreen({super.key});

  @override
  State<StudentsManagementScreen> createState() =>
      _StudentsManagementScreenState();
}

class _StudentsManagementScreenState extends State<StudentsManagementScreen> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dniController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  String? _selectedClassroomId;
  bool _isSearching = false;
  List<StudentModel> _searchResults = [];
  StudentModel? _editingStudent;
  bool _isFormVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _lastNameController.dispose();
    _dniController.dispose();
    _parentNameController.dispose();
    _parentPhoneController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _searchStudents() async {
    if (_searchController.text.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults.clear();
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await StudentService.searchStudents(
        _searchController.text.trim(),
      );
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        _showSnackBar('Error al buscar estudiantes: $e', isError: true);
      }
    }
  }

  void _showCreateForm() {
    _clearForm();
    setState(() {
      _editingStudent = null;
      _isFormVisible = true;
    });
  }

  void _showEditForm(StudentModel student) {
    _fillForm(student);
    setState(() {
      _editingStudent = student;
      _isFormVisible = true;
    });
  }

  void _clearForm() {
    _nameController.clear();
    _lastNameController.clear();
    _dniController.clear();
    _parentNameController.clear();
    _parentPhoneController.clear();
    _emergencyContactController.clear();
    _emergencyPhoneController.clear();
    _selectedClassroomId = null;
  }

  void _fillForm(StudentModel student) {
    _nameController.text = student.firstName;
    _lastNameController.text = student.lastName;
    _dniController.text = student.dni;
    _parentNameController.text = student.parentEmail ?? '';
    _parentPhoneController.text = student.parentPhone ?? '';
    _emergencyContactController.text = '';
    _emergencyPhoneController.text = '';
    _selectedClassroomId = student.classroomId;
  }

  Future<void> _saveStudent() async {
    if (!_validateForm()) return;

    try {
      bool success;
      if (_editingStudent == null) {
        // Crear estudiante
        final result = await StudentService.createStudent(
          firstName: _nameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          dni: _dniController.text.trim(),
          classroomId: _selectedClassroomId!,
          parentEmail: _parentNameController.text.trim().isEmpty
              ? null
              : _parentNameController.text.trim(),
          parentPhone: _parentPhoneController.text.trim().isEmpty
              ? null
              : _parentPhoneController.text.trim(),
        );
        success = result['success'];
        _showSnackBar(result['message'], isError: !success);
      } else {
        // Actualizar estudiante
        success = await StudentService.updateStudent(
          studentId: _editingStudent!.id!,
          firstName: _nameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          dni: _dniController.text.trim(),
          classroomId: _selectedClassroomId!,
          parentEmail: _parentNameController.text.trim().isEmpty
              ? null
              : _parentNameController.text.trim(),
          parentPhone: _parentPhoneController.text.trim().isEmpty
              ? null
              : _parentPhoneController.text.trim(),
        );
        _showSnackBar(
          success
              ? 'Estudiante actualizado exitosamente'
              : 'Error al actualizar estudiante',
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
      _showSnackBar('El nombre es requerido', isError: true);
      return false;
    }
    if (_lastNameController.text.trim().isEmpty) {
      _showSnackBar('El apellido es requerido', isError: true);
      return false;
    }
    if (_dniController.text.trim().isEmpty) {
      _showSnackBar('El DNI es requerido', isError: true);
      return false;
    }
    if (_selectedClassroomId == null) {
      _showSnackBar('Debe seleccionar un salón', isError: true);
      return false;
    }
    return true;
  }

  Future<void> _toggleStudentStatus(StudentModel student) async {
    final success = student.isActive
        ? await StudentService.deactivateStudent(student.id!)
        : await StudentService.reactivateStudent(student.id!);

    _showSnackBar(
      success
          ? 'Estado del estudiante actualizado'
          : 'Error al actualizar estado',
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
        title: const Text('Gestión de Estudiantes'),
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
                      hintText: 'Buscar por nombre o DNI...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (_) => _searchStudents(),
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
            child: _isFormVisible ? _buildStudentForm() : _buildStudentsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentForm() {
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
                    _editingStudent == null
                        ? 'Crear Estudiante'
                        : 'Editar Estudiante',
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
                                labelText: 'Nombre *',
                                border: OutlineInputBorder(),
                              ),
                              textCapitalization: TextCapitalization.words,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _lastNameController,
                              decoration: const InputDecoration(
                                labelText: 'Apellido *',
                                border: OutlineInputBorder(),
                              ),
                              textCapitalization: TextCapitalization.words,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _dniController,
                              decoration: const InputDecoration(
                                labelText: 'DNI *',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: ClassroomService.getAllClassrooms(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const CircularProgressIndicator();
                                }

                                final classrooms = snapshot.data!.docs;
                                return DropdownButtonFormField<String>(
                                  initialValue: _selectedClassroomId,
                                  decoration: const InputDecoration(
                                    labelText: 'Salón *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: classrooms.map((doc) {
                                    final classroom =
                                        ClassroomModel.fromFirestore(doc);
                                    return DropdownMenuItem(
                                      value: doc.id,
                                      child: Text(
                                        '${classroom.grade} - ${classroom.section}',
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) => setState(
                                    () => _selectedClassroomId = value,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _parentNameController,
                              decoration: const InputDecoration(
                                labelText: 'Email del Padre/Madre',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _parentPhoneController,
                              decoration: const InputDecoration(
                                labelText: 'Teléfono del Padre/Madre',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
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
                            onPressed: _saveStudent,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF424242),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              _editingStudent == null ? 'Crear' : 'Guardar',
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

  Widget _buildStudentsList() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.trim().isNotEmpty) {
      // Mostrar resultados de búsqueda
      if (_searchResults.isEmpty) {
        return const Center(child: Text('No se encontraron estudiantes'));
      }
      return _buildStudentsGrid(_searchResults);
    }

    // Mostrar todos los estudiantes
    return StreamBuilder<QuerySnapshot>(
      stream: StudentService.getAllStudents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay estudiantes registrados'));
        }

        final students = snapshot.data!.docs
            .map((doc) => StudentModel.fromFirestore(doc))
            .toList();

        return _buildStudentsGrid(students);
      },
    );
  }

  Widget _buildStudentsGrid(List<StudentModel> students) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 3 : 1,
            childAspectRatio: isWide ? 1.2 : 3.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return _buildStudentCard(student);
          },
        );
      },
    );
  }

  Widget _buildStudentCard(StudentModel student) {
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
                        '${student.firstName} ${student.lastName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'DNI: ${student.dni}',
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
                    color: student.isActive ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    student.isActive ? 'Activo' : 'Inactivo',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _showEditForm(student),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Editar'),
                ),
                TextButton.icon(
                  onPressed: () => _toggleStudentStatus(student),
                  icon: Icon(
                    student.isActive ? Icons.block : Icons.check_circle,
                    size: 16,
                  ),
                  label: Text(student.isActive ? 'Desactivar' : 'Activar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

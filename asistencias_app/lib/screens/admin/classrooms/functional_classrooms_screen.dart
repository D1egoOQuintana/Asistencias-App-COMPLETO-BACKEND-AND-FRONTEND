import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/classroom_model.dart';
import '../../../services/classroom_service.dart';
import '../../../services/admin_service_final.dart';

class FunctionalClassroomsScreen extends StatefulWidget {
  const FunctionalClassroomsScreen({super.key});

  @override
  State<FunctionalClassroomsScreen> createState() =>
      _FunctionalClassroomsScreenState();
}

class _FunctionalClassroomsScreenState
    extends State<FunctionalClassroomsScreen> {
  // Controladores de formulario
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sectionController = TextEditingController();
  final _gradeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _capacityController = TextEditingController();

  // Variables de estado
  String? _selectedTeacherUid;
  String? _selectedTeacherName;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _sectionController.dispose();
    _gradeController.dispose();
    _descriptionController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _saveClassroom() async {
    print('DEBUG: _saveClassroom called');
    print('DEBUG: _selectedTeacherUid: $_selectedTeacherUid');
    print('DEBUG: _selectedTeacherName: $_selectedTeacherName');
    if (!_formKey.currentState!.validate()) {
      print('DEBUG: Form validation failed');
      return;
    }
    if (_selectedTeacherUid == null) {
      print('DEBUG: _selectedTeacherUid is null');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seleccione un profesor')));
      return;
    }
    print('DEBUG: Proceeding to create classroom');
    setState(() => _isLoading = true);

    try {
      final capacityParsed = int.tryParse(_capacityController.text.trim());
      final result = await ClassroomService.createClassroom(
        name: _nameController.text.trim(),
        section: _sectionController.text.trim(),
        grade: _gradeController.text.trim(),
        capacity: capacityParsed ?? 0,
        teacherUid: _selectedTeacherUid!,
        teacherName: _selectedTeacherName,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (result['success'] == true) {
        print('DEBUG: Classroom created successfully');
        // Limpiar formulario
        _nameController.clear();
        _sectionController.clear();
        _gradeController.clear();
        _descriptionController.clear();
        setState(() {
          _selectedTeacherUid = null;
          _selectedTeacherName = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aula creada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Error al crear aula'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('DEBUG: Error creating classroom: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Aulas'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Formulario para crear aula
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Crear Nueva Aula',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 24),

                      // Nombre del aula
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del aula',
                          hintText: 'Ej: Aula A, Matemáticas 5to',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.class_),
                        ),
                        validator: (value) {
                          print(
                            'DEBUG: Name field validator called with: "$value"',
                          );
                          if (value == null || value.trim().isEmpty) {
                            print('DEBUG: Name field validation FAILED');
                            return 'El nombre del aula es requerido';
                          }
                          print('DEBUG: Name field validation PASSED');
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Sección
                      TextFormField(
                        controller: _sectionController,
                        decoration: const InputDecoration(
                          labelText: 'Sección',
                          hintText: 'Ej: A, B, C',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        validator: (value) {
                          print(
                            'DEBUG: Section field validator called with: "$value"',
                          );
                          if (value == null || value.trim().isEmpty) {
                            print('DEBUG: Section field validation FAILED');
                            return 'La sección es requerida';
                          }
                          print('DEBUG: Section field validation PASSED');
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Grado
                      TextFormField(
                        controller: _gradeController,
                        decoration: const InputDecoration(
                          labelText: 'Grado',
                          hintText: 'Ej: 1ro, 2do, 3ro',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.school),
                        ),
                        validator: (value) {
                          print(
                            'DEBUG: Grade field validator called with: "$value"',
                          );
                          if (value == null || value.trim().isEmpty) {
                            print('DEBUG: Grade field validation FAILED');
                            return 'El grado es requerido';
                          }
                          print('DEBUG: Grade field validation PASSED');
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Selector de profesor
                      StreamBuilder<QuerySnapshot>(
                        stream: AdminService.getTeachersStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const LinearProgressIndicator();
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            print('DEBUG: No teachers data or empty');
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'No hay profesores activos disponibles',
                              ),
                            );
                          }

                          final teachers = snapshot.data!.docs;
                          print(
                            'DEBUG: Teachers docs count: ${teachers.length}',
                          );
                          for (var doc in teachers) {
                            print(
                              'DEBUG: Teacher doc: ${doc.id}, data: ${doc.data()}',
                            );
                          }

                          return DropdownButtonFormField<String>(
                            value: _selectedTeacherUid,
                            decoration: const InputDecoration(
                              labelText: 'Profesor asignado',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            items: teachers.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final fullName =
                                  (data['fullName'] as String?) ??
                                  '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
                                      .trim();
                              final uid = (data['uid'] as String?) ?? doc.id;
                              return DropdownMenuItem(
                                value: uid,
                                child: Text(fullName.isEmpty ? uid : fullName),
                              );
                            }).toList(),
                            onChanged: (value) {
                              print(
                                'DEBUG: Dropdown onChanged called with value: $value',
                              );
                              setState(() {
                                _selectedTeacherUid = value;
                                if (value != null) {
                                  try {
                                    final doc = teachers.firstWhere(
                                      (d) =>
                                          ((d.data()
                                                  as Map<
                                                    String,
                                                    dynamic
                                                  >)['uid'] ??
                                              d.id) ==
                                          value,
                                    );
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    _selectedTeacherName =
                                        (data['fullName'] as String?) ??
                                        '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
                                            .trim();
                                    print(
                                      'DEBUG: Set _selectedTeacherName: $_selectedTeacherName',
                                    );
                                  } catch (e) {
                                    print(
                                      'DEBUG: Error finding teacher doc: $e',
                                    );
                                    _selectedTeacherName =
                                        value; // fallback to uid
                                  }
                                } else {
                                  _selectedTeacherName = null;
                                }
                              });
                            },
                            validator: (value) {
                              print(
                                'DEBUG: Dropdown validator called with value: $value',
                              );
                              if (value == null) {
                                print(
                                  'DEBUG: Dropdown validator returning error',
                                );
                                return 'Seleccione un profesor';
                              }
                              print('DEBUG: Dropdown validator returning null');
                              return null;
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Capacidad
                      TextFormField(
                        controller: _capacityController,
                        decoration: const InputDecoration(
                          labelText: 'Capacidad (estudiantes) - opcional',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.groups),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          print(
                            'DEBUG: Capacity field validator called with: "$value"',
                          );
                          if (value != null && value.isNotEmpty) {
                            if (int.tryParse(value) == null) {
                              print(
                                'DEBUG: Capacity field validation FAILED - invalid number',
                              );
                              return 'Capacidad inválida';
                            }
                          }
                          print('DEBUG: Capacity field validation PASSED');
                          return null;
                        },
                      ),

                      // Descripción (opcional)
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Descripción (opcional)',
                          hintText: 'Información adicional sobre el aula',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),

                      // Botón guardar
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveClassroom,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Creando...'),
                                  ],
                                )
                              : const Text(
                                  'Crear Aula',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Lista de aulas en tiempo real
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aulas Creadas',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),

                    StreamBuilder<QuerySnapshot>(
                      stream: ClassroomService.getAllClassrooms(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(32),
                            child: const Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.class_,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No hay aulas creadas',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final classrooms = snapshot.data!.docs
                            .map((doc) => ClassroomModel.fromFirestore(doc))
                            .toList();

                        return Column(
                          children: [
                            Text(
                              'Total: ${classrooms.length} aulas',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 12),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: classrooms.length,
                              itemBuilder: (context, index) {
                                final classroom = classrooms[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ExpansionTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.green.shade100,
                                      child: Text(
                                        classroom.section.isNotEmpty
                                            ? classroom.section[0].toUpperCase()
                                            : 'A',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      classroom.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${classroom.grade} - Sección ${classroom.section}',
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.person,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Profesor: ${classroom.teacherName == null || classroom.teacherName!.isEmpty ? (classroom.teacherUid ?? '-') : classroom.teacherName}',
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.groups,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Capacidad: ${classroom.capacity} estudiantes',
                                                ),
                                              ],
                                            ),
                                            if (classroom.description !=
                                                null) ...[
                                              const SizedBox(height: 8),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(
                                                    Icons.description,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      classroom.description!,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  classroom.isActive
                                                      ? Icons.check_circle
                                                      : Icons.cancel,
                                                  size: 16,
                                                  color: classroom.isActive
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  classroom.isActive
                                                      ? 'Activa'
                                                      : 'Inactiva',
                                                  style: TextStyle(
                                                    color: classroom.isActive
                                                        ? Colors.green
                                                        : Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

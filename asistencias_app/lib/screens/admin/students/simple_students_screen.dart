import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/student_model.dart';
import '../../../models/classroom_model.dart';
import '../../../services/student_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/admin_service_final.dart';

class SimpleStudentsScreen extends StatefulWidget {
  const SimpleStudentsScreen({super.key});

  @override
  State<SimpleStudentsScreen> createState() => _SimpleStudentsScreenState();
}

class _SimpleStudentsScreenState extends State<SimpleStudentsScreen> {
  // Controladores de formulario
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dniController = TextEditingController();
  final _parentEmailController = TextEditingController();
  final _parentPhoneController = TextEditingController();

  // Variables de estado
  List<ClassroomModel> _classrooms = [];
  String? _selectedClassroomId;
  bool _isLoading = false;
  bool _isLoadingClassrooms = true;
  String? _currentRole; // 'admin' | 'docente'/'teacher' | otros
  String? _selectedTeacherFilterUid; // para admins

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dniController.dispose();
    _parentEmailController.dispose();
    _parentPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadClassrooms() async {
    setState(() => _isLoadingClassrooms = true);
    try {
      final auth = FirebaseAuth.instance;
      final current = auth.currentUser;

      List<ClassroomModel> classrooms = [];

      if (current != null) {
        // Detectar rol del usuario
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(current.uid)
            .get();
        final role = (userDoc.data() ?? const {})['role'] as String?;
        _currentRole = role;

        if (role == 'docente' || role == 'teacher') {
          // Solo aulas asignadas a este docente
          final qs = await FirebaseFirestore.instance
              .collection('classrooms')
              .where('teacherUid', isEqualTo: current.uid)
              .where('isActive', isEqualTo: true)
              .get();
          classrooms = qs.docs
              .map((d) => ClassroomModel.fromMap({...d.data(), 'id': d.id}))
              .toList();
        } else {
          // Admin: filtrar por profesor si se seleccionó
          if (_selectedTeacherFilterUid != null &&
              _selectedTeacherFilterUid!.isNotEmpty) {
            final qs = await FirebaseFirestore.instance
                .collection('classrooms')
                .where('teacherUid', isEqualTo: _selectedTeacherFilterUid)
                .where('isActive', isEqualTo: true)
                .get();
            classrooms = qs.docs
                .map((d) => ClassroomModel.fromMap({...d.data(), 'id': d.id}))
                .toList();
          } else {
            classrooms = await FirestoreService.getAllClassrooms();
          }
        }
      } else {
        classrooms = await FirestoreService.getAllClassrooms();
      }

      setState(() {
        _classrooms = classrooms;
        _isLoadingClassrooms = false;
      });
    } catch (e) {
      setState(() => _isLoadingClassrooms = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
      }
    }
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate() || _selectedClassroomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete todos los campos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('DEBUG: _saveStudent called');
      final result = await StudentService.createStudent(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        dni: _dniController.text.trim(),
        classroomId: _selectedClassroomId!,
        parentEmail: _parentEmailController.text.trim().isEmpty
            ? null
            : _parentEmailController.text.trim(),
        parentPhone: _parentPhoneController.text.trim().isEmpty
            ? null
            : _parentPhoneController.text.trim(),
      );

      if (result['success'] == true) {
        print(
          'DEBUG: Student created successfully, id: ${result['studentId']}',
        );
        // Limpiar formulario
        _firstNameController.clear();
        _lastNameController.clear();
        _dniController.clear();
        _parentEmailController.clear();
        _parentPhoneController.clear();
        setState(() => _selectedClassroomId = null);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Estudiante guardado exitosamente')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Error al guardar')),
          );
        }
      }
    } catch (e) {
      print('DEBUG: Error saving student: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteStudent(StudentModel student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Está seguro de eliminar a ${student.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && student.id != null) {
      try {
        final ok = await StudentService.deactivateStudent(student.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ok ? 'Estudiante eliminado' : 'No se pudo eliminar',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
        }
      }
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Estudiantes'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingClassrooms
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Formulario para agregar estudiante
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Agregar Nuevo Estudiante',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            if (!(_currentRole == 'docente' ||
                                _currentRole == 'teacher')) ...[
                              const SizedBox(height: 16),
                              StreamBuilder<QuerySnapshot>(
                                stream: AdminService.getTeachersStream(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const LinearProgressIndicator();
                                  }
                                  final docs = snapshot.data?.docs ?? [];
                                  if (docs.isEmpty) {
                                    return const Text(
                                      'No hay docentes activos',
                                    );
                                  }
                                  return DropdownButtonFormField<String>(
                                    value: _selectedTeacherFilterUid,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Filtrar aulas por profesor (opcional)',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.person_search),
                                    ),
                                    items: docs.map((doc) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final fullName =
                                          (data['fullName'] as String?) ??
                                          '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
                                              .trim();
                                      final uid =
                                          (data['uid'] as String?) ?? doc.id;
                                      return DropdownMenuItem(
                                        value: uid,
                                        child: Text(
                                          fullName.isEmpty ? uid : fullName,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) async {
                                      setState(() {
                                        _selectedTeacherFilterUid = val;
                                      });
                                      await _loadClassrooms();
                                    },
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _firstNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nombres',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Los nombres son requeridos';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _lastNameController,
                              decoration: const InputDecoration(
                                labelText: 'Apellidos',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Los apellidos son requeridos';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _dniController,
                              decoration: const InputDecoration(
                                labelText: 'DNI',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.badge),
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
                            DropdownButtonFormField<String>(
                              value: _selectedClassroomId,
                              decoration: const InputDecoration(
                                labelText: 'Aula',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.class_),
                              ),
                              items: _classrooms.map((classroom) {
                                return DropdownMenuItem(
                                  value: classroom.id,
                                  child: Text(
                                    '${classroom.name} - ${classroom.teacherName ?? 'Sin docente'}',
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedClassroomId = value);
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Seleccione un aula';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _parentEmailController,
                              decoration: const InputDecoration(
                                labelText: 'Email del apoderado (opcional)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _parentPhoneController,
                              decoration: const InputDecoration(
                                labelText: 'Teléfono del apoderado (opcional)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.phone),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _saveStudent,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : const Text('Guardar Estudiante'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Lista de estudiantes
                  Text(
                    'Estudiantes Registrados',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),

                  StreamBuilder<QuerySnapshot>(
                    stream: StudentService.getAllStudentsSimple(),
                    builder: (context, snapshot) {
                      print(
                        'DEBUG: Student StreamBuilder rebuild - connectionState: ${snapshot.connectionState}',
                      );
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        print('DEBUG: Students stream waiting');
                        return const Center(child: CircularProgressIndicator());
                      }
                      print(
                        'DEBUG: Students stream state: ${snapshot.connectionState}',
                      );
                      if (snapshot.hasError) {
                        print(
                          'DEBUG: Students stream error: ${snapshot.error}',
                        );
                        print(
                          'DEBUG: Students stream error stackTrace: ${snapshot.stackTrace}',
                        );
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.error,
                                  color: Colors.red,
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Error cargando estudiantes: ${snapshot.error}',
                                ),
                                const SizedBox(height: 8),
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
                        print(
                          'DEBUG: No students data or empty - hasData: ${snapshot.hasData}, docs count: ${snapshot.data?.docs.length ?? 0}',
                        );
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.school,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text('No hay estudiantes registrados'),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      final students = snapshot.data!.docs
                          .map((doc) => StudentModel.fromFirestore(doc))
                          .toList();
                      print('DEBUG: Students loaded: ${students.length}');
                      print(
                        'DEBUG: Raw docs count: ${snapshot.data!.docs.length}',
                      );
                      for (var doc in snapshot.data!.docs) {
                        print('DEBUG: Raw doc: ${doc.id} -> ${doc.data()}');
                      }
                      for (var student in students) {
                        print(
                          'DEBUG: Student: ${student.fullName}, classroomId: ${student.classroomId}, isActive: ${student.isActive}',
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total: ${students.length}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: students.length,
                            itemBuilder: (context, index) {
                              final student = students[index];
                              final classroom = _classrooms.firstWhere(
                                (c) => c.id == student.classroomId,
                                orElse: () => ClassroomModel(
                                  id: '',
                                  name: 'Desconocida',
                                  grade: '',
                                  section: '',
                                  capacity: 0,
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                ),
                              );

                              final fullName = student.fullName.trim();

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: Text(
                                      fullName.isNotEmpty
                                          ? fullName[0].toUpperCase()
                                          : 'E',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    fullName.isEmpty ? 'Sin nombre' : fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('DNI: ${student.dni}'),
                                      Text('Aula: ${classroom.name}'),
                                      Text(
                                        'Profesor: ${classroom.teacherName ?? '-'}',
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteStudent(student),
                                  ),
                                  isThreeLine: true,
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
    );
  }
}

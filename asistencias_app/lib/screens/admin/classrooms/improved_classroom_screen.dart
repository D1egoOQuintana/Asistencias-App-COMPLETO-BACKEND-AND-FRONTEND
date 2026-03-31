import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/classroom_model.dart';
import '../../../services/classroom_service.dart';
import '../../../services/teacher_service.dart';

class ImprovedClassroomScreen extends StatefulWidget {
  const ImprovedClassroomScreen({super.key});

  @override
  State<ImprovedClassroomScreen> createState() =>
      _ImprovedClassroomScreenState();
}

class _ImprovedClassroomScreenState extends State<ImprovedClassroomScreen>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sectionController = TextEditingController();
  final _gradeController = TextEditingController();
  final _capacityController = TextEditingController();

  String? _selectedTeacherUid;
  String? _selectedTeacherName;
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _nameController.dispose();
    _sectionController.dispose();
    _gradeController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _saveClassroom() async {
    if (!_formKey.currentState!.validate() || _selectedTeacherUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete todos los campos requeridos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ClassroomService.createClassroom(
        name: _nameController.text.trim(),
        section: _sectionController.text.trim(),
        grade: _gradeController.text.trim(),
        capacity: int.tryParse(_capacityController.text.trim()) ?? 30,
        teacherUid: _selectedTeacherUid!,
        teacherName: _selectedTeacherName,
        description: 'Aula creada por administrador',
      );

      if (result['success'] == true) {
        _clearForm();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aula creada y asignada exitosamente'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _sectionController.clear();
    _gradeController.clear();
    _capacityController.clear();
    setState(() {
      _selectedTeacherUid = null;
      _selectedTeacherName = null;
    });
  }

  Future<void> _toggleClassroomStatus(ClassroomModel classroom) async {
    final ok = classroom.isActive
        ? await ClassroomService.deactivateClassroom(classroom.id!)
        : await ClassroomService.reactivateClassroom(classroom.id!);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? classroom.isActive
                    ? 'Aula desactivada correctamente'
                    : 'Aula activada correctamente'
              : 'No se pudo actualizar el estado del aula',
        ),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _deleteClassroom(ClassroomModel classroom) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Eliminar aula'),
          content: Text(
            'El aula "${classroom.name}" se marcará como inactiva para conservar histórico. ¿Deseas continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final ok = await ClassroomService.deactivateClassroom(classroom.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Aula eliminada (inactiva) correctamente'
              : 'No se pudo eliminar el aula',
        ),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

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
                      Row(
                        children: [
                          Icon(
                            Icons.add_business,
                            color: Colors.green.shade700,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Crear Nueva Aula',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Nombre del aula
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del aula',
                          hintText: 'Ej: Matemáticas 5to A',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.class_),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El nombre del aula es requerido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          // Grado
                          Expanded(
                            child: TextFormField(
                              controller: _gradeController,
                              decoration: const InputDecoration(
                                labelText: 'Grado',
                                hintText: '1ro, 2do, 3ro...',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.school),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'El grado es requerido';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Sección
                          Expanded(
                            child: TextFormField(
                              controller: _sectionController,
                              decoration: const InputDecoration(
                                labelText: 'Sección',
                                hintText: 'A, B, C...',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'La sección es requerida';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Capacidad
                      TextFormField(
                        controller: _capacityController,
                        decoration: const InputDecoration(
                          labelText: 'Capacidad máxima de estudiantes',
                          hintText: '25, 30, 35...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.groups),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'La capacidad es requerida';
                          }
                          final capacity = int.tryParse(value.trim());
                          if (capacity == null ||
                              capacity <= 0 ||
                              capacity > 50) {
                            return 'Ingrese un número entre 1 y 50';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Selector de docente
                      StreamBuilder<QuerySnapshot>(
                        stream: TeacherService.getTeachersStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const LinearProgressIndicator();
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.orange),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.orange.shade50,
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.warning, color: Colors.orange),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'No hay docentes disponibles. Primero crea docentes en "Gestión de Docentes".',
                                      style: TextStyle(color: Colors.orange),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final teachers = snapshot.data!.docs;

                          // Construir items de forma segura y deducir selección válida
                          final items = teachers.map<DropdownMenuItem<String>>((
                            teacherDoc,
                          ) {
                            final teacher =
                                teacherDoc.data() as Map<String, dynamic>;
                            final value =
                                (teacher['uid'] as String?) ?? teacherDoc.id;
                            final firstName = (teacher['firstName'] ?? '')
                                .toString();
                            final lastName = (teacher['lastName'] ?? '')
                                .toString();
                            final fullName = (teacher['fullName'] ?? '')
                                .toString();
                            final email = (teacher['email'] ?? '').toString();
                            final displayName =
                                (('$firstName $lastName').trim().isNotEmpty)
                                ? ('$firstName $lastName').trim()
                                : (fullName.isNotEmpty ? fullName : email);
                            final subtitle = (teacher['subject'] ?? email)
                                .toString();
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            );
                          }).toList();

                          final availableValues = items
                              .map((e) => e.value)
                              .whereType<String>()
                              .toSet();
                          final effectiveSelected =
                              availableValues.contains(_selectedTeacherUid)
                              ? _selectedTeacherUid
                              : null;

                          // Si el valor en estado no es válido, sincronizar a null después del frame
                          if (_selectedTeacherUid != effectiveSelected) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              setState(() {
                                _selectedTeacherUid = effectiveSelected;
                              });
                            });
                          }

                          return DropdownButtonFormField<String>(
                            value: effectiveSelected,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Asignar Docente',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_add),
                            ),
                            hint: const Text('Selecciona un docente'),
                            selectedItemBuilder: (context) {
                              // Mostrar solo el nombre en el campo para evitar desbordes
                              return teachers.map((teacherDoc) {
                                final t =
                                    teacherDoc.data() as Map<String, dynamic>;
                                final firstName = (t['firstName'] ?? '')
                                    .toString();
                                final lastName = (t['lastName'] ?? '')
                                    .toString();
                                final fullName = (t['fullName'] ?? '')
                                    .toString();
                                final email = (t['email'] ?? '').toString();
                                final displayName =
                                    (('$firstName $lastName').trim().isNotEmpty)
                                    ? ('$firstName $lastName').trim()
                                    : (fullName.isNotEmpty ? fullName : email);
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList();
                            },
                            items: items,
                            onChanged: (value) {
                              if (value == null) {
                                setState(() {
                                  _selectedTeacherUid = null;
                                  _selectedTeacherName = null;
                                });
                              } else {
                                // Buscar el nombre para guardar también teacherName
                                QueryDocumentSnapshot<Object?>? foundDoc;
                                try {
                                  foundDoc = teachers.firstWhere((d) {
                                    final t = d.data() as Map<String, dynamic>;
                                    final v = (t['uid'] as String?) ?? d.id;
                                    return v == value;
                                  });
                                } catch (e) {
                                  print(
                                    'DEBUG: Teacher not found for value: $value',
                                  );
                                  foundDoc = teachers.isNotEmpty
                                      ? teachers.first
                                      : null;
                                }

                                if (foundDoc != null) {
                                  final t =
                                      foundDoc.data() as Map<String, dynamic>;
                                  final firstName = (t['firstName'] ?? '')
                                      .toString();
                                  final lastName = (t['lastName'] ?? '')
                                      .toString();
                                  final fullName = (t['fullName'] ?? '')
                                      .toString();
                                  final email = (t['email'] ?? '').toString();
                                  final displayName =
                                      (('$firstName $lastName')
                                          .trim()
                                          .isNotEmpty)
                                      ? ('$firstName $lastName').trim()
                                      : (fullName.isNotEmpty
                                            ? fullName
                                            : email);

                                  setState(() {
                                    _selectedTeacherUid = value;
                                    _selectedTeacherName = displayName;
                                  });
                                }
                              }
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Seleccione un docente';
                              }
                              return null;
                            },
                          );
                        },
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
                                    Text('Creando aula...'),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_business),
                                    SizedBox(width: 12),
                                    Text(
                                      'Crear Aula y Asignar Docente',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Lista de aulas creadas
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.list_alt, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Aulas Creadas',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
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
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Crea la primera aula usando el formulario de arriba',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final classrooms = snapshot.data!.docs
                            .map((doc) => ClassroomModel.fromFirestore(doc))
                            .toList();
                        // Ordenar cliente por grado y sección
                        classrooms.sort((a, b) {
                          final byGrade = a.grade.compareTo(b.grade);
                          if (byGrade != 0) return byGrade;
                          return a.section.compareTo(b.section);
                        });

                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Total: ${classrooms.length} aulas creadas',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: classrooms.length,
                              itemBuilder: (context, index) {
                                final classroom = classrooms[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.green.shade100,
                                      child: Text(
                                        classroom.section.toUpperCase(),
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
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${classroom.grade} - Sección ${classroom.section}',
                                        ),
                                        Text(
                                          '👨‍🏫 ${classroom.teacherName}',
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                        Text(
                                          '👥 Capacidad: ${classroom.capacity} estudiantes',
                                        ),
                                      ],
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      tooltip: 'Acciones del aula',
                                      onSelected: (value) async {
                                        if (value == 'toggle') {
                                          await _toggleClassroomStatus(classroom);
                                        } else if (value == 'delete') {
                                          await _deleteClassroom(classroom);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem<String>(
                                          value: 'toggle',
                                          child: Row(
                                            children: [
                                              Icon(
                                                classroom.isActive
                                                    ? Icons.block
                                                    : Icons.check_circle,
                                                size: 18,
                                                color: classroom.isActive
                                                    ? Colors.orange
                                                    : Colors.green,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                classroom.isActive
                                                    ? 'Desactivar'
                                                    : 'Activar',
                                              ),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color: Colors.red,
                                              ),
                                              SizedBox(width: 8),
                                              Text('Eliminar'),
                                            ],
                                          ),
                                        ),
                                      ],
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: classroom.isActive
                                              ? Colors.green
                                              : Colors.red,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              classroom.isActive
                                                  ? 'ACTIVA'
                                                  : 'INACTIVA',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.expand_more,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ),
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
            ),
          ],
        ),
      ),
    );
  }
}

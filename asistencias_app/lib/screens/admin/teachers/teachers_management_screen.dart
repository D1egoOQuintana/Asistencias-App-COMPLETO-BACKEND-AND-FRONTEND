import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart' as AppAuthProvider;
import '../../../themes/app_themes.dart';
import '../../../services/admin_service_final.dart';
import '../../../widgets/common/app_feedback_dialog.dart';

/// Pantalla para gestión de docentes (solo admin)
class TeachersManagementScreen extends StatefulWidget {
  const TeachersManagementScreen({super.key});

  @override
  State<TeachersManagementScreen> createState() =>
      _TeachersManagementScreenState();
}

class _TeachersManagementScreenState extends State<TeachersManagementScreen>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final authProvider = Provider.of<AppAuthProvider.AuthProvider>(context);
    final user = authProvider.user!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 24),
        _buildSearchBar(),
        const SizedBox(height: 24),
        Expanded(child: _buildTeachersList(user.role)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestión de Docentes',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Administra los docentes del sistema',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _showAddTeacherDialog(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Agregar', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppThemes.getThemeForRole(
              UserRole.admin,
            ).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: const InputDecoration(
          hintText: 'Buscar docentes por nombre o email...',
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildTeachersList(UserRole userRole) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          // Mostrar docentes con rol 'docente' o 'teacher' por compatibilidad
          .where('role', whereIn: ['docente', 'teacher'])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar docentes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('${snapshot.error}'),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final teachers = snapshot.data?.docs ?? [];

        // Filtrar por búsqueda
        final filteredTeachers = teachers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final email = (data['email'] ?? '').toString().toLowerCase();
          final fullName = (data['fullName'] ?? '').toString().toLowerCase();
          return email.contains(_searchQuery) ||
              fullName.contains(_searchQuery);
        }).toList();

        if (filteredTeachers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'No hay docentes registrados'
                      : 'No se encontraron docentes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_searchQuery.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Agrega el primer docente al sistema',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredTeachers.length,
          itemBuilder: (context, index) {
            final teacherDoc = filteredTeachers[index];
            final teacher = UserModel.fromMap({
              'uid': teacherDoc.id,
              ...teacherDoc.data() as Map<String, dynamic>,
            });

            return _buildTeacherCard(teacher);
          },
        );
      },
    );
  }

  Widget _buildTeacherCard(UserModel teacher) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppThemes.getThemeForRole(
                UserRole.docente,
              ).primaryColor,
              child: Text(
                teacher.email.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teacher.fullName.isNotEmpty
                        ? teacher.fullName
                        : teacher.email.split('@')[0],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    teacher.email,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: teacher.isActive
                              ? Colors.green[100]
                              : Colors.red[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          teacher.isActive ? 'Activo' : 'Inactivo',
                          style: TextStyle(
                            color: teacher.isActive
                                ? Colors.green[700]
                                : Colors.red[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) => _handleTeacherAction(value, teacher),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: teacher.isActive ? 'deactivate' : 'activate',
                  child: Row(
                    children: [
                      Icon(
                        teacher.isActive ? Icons.block : Icons.check_circle,
                        size: 20,
                        color: teacher.isActive ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(teacher.isActive ? 'Desactivar' : 'Activar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleTeacherAction(String action, UserModel teacher) {
    switch (action) {
      case 'edit':
        _showEditTeacherDialog(context, teacher);
        break;
      case 'activate':
      case 'deactivate':
        _toggleTeacherStatus(teacher);
        break;
      case 'delete':
        _showDeleteConfirmDialog(context, teacher);
        break;
    }
  }

  void _showAddTeacherDialog(BuildContext context) {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Nuevo Docente'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre Completo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña Temporal',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (emailController.text.isNotEmpty &&
                  nameController.text.isNotEmpty &&
                  passwordController.text.isNotEmpty) {
                _createTeacher(
                  emailController.text,
                  nameController.text,
                  passwordController.text,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Crear Docente'),
          ),
        ],
      ),
    );
  }

  void _showEditTeacherDialog(BuildContext context, UserModel teacher) {
    final nameController = TextEditingController(text: teacher.fullName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Docente'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre Completo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email),
                  hintText: teacher.email,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                _updateTeacher(teacher, nameController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, UserModel teacher) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Docente'),
        content: Text(
          '¿Estás seguro que deseas eliminar al docente ${teacher.fullName}?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteTeacher(teacher);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createTeacher(
    String email,
    String fullName,
    String password,
  ) async {
    try {
      // Usar AdminService para crear con app secundaria y rol 'docente'
      final result = await AdminService.createTeacher(
        email: email,
        fullName: fullName,
        temporaryPassword: password,
      );

      if (mounted) {
        if (result['success'] == true) {
          AppFeedbackDialog.success(
            context,
            title: 'Docente creado',
            message: result['message'] ?? 'Docente creado correctamente',
          );
        } else {
          AppFeedbackDialog.error(
            context,
            title: 'No se pudo crear',
            message: result['message'] ?? 'Ocurrió un error al crear docente',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppFeedbackDialog.error(
          context,
          title: 'Error al crear docente',
          message: '$e',
        );
      }
    }
  }

  Future<void> _updateTeacher(UserModel teacher, String newName) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(teacher.uid)
          .update({'fullName': newName});

      AppFeedbackDialog.success(
        context,
        title: 'Actualizado',
        message: 'Docente actualizado correctamente',
      );
    } catch (e) {
      AppFeedbackDialog.error(
        context,
        title: 'Error al actualizar',
        message: '$e',
      );
    }
  }

  Future<void> _toggleTeacherStatus(UserModel teacher) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(teacher.uid)
          .update({'isActive': !teacher.isActive});

      AppFeedbackDialog.success(
        context,
        title: 'Estado actualizado',
        message:
            'Docente ${!teacher.isActive ? 'activado' : 'desactivado'} correctamente',
      );
    } catch (e) {
      AppFeedbackDialog.error(context, title: 'Error de estado', message: '$e');
    }
  }

  Future<void> _deleteTeacher(UserModel teacher) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(teacher.uid)
          .delete();

      AppFeedbackDialog.success(
        context,
        title: 'Eliminado',
        message: 'Docente eliminado correctamente',
      );
    } catch (e) {
      AppFeedbackDialog.error(
        context,
        title: 'Error al eliminar',
        message: '$e',
      );
    }
  }
}

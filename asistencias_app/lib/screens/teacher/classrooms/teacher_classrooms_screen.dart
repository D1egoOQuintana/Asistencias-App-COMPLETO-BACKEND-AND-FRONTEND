import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/classroom_model.dart';
import '../../../services/teacher_service.dart';
import '../../../theme/app_design_system.dart';
import '../../../widgets/classroom/classroom_card.dart';
import '../../../widgets/common/state_widgets.dart';
import 'classroom_detail_screen.dart';

enum ClassroomFilter { all, active, inactive }

enum ViewMode { grid, list }

class TeacherClassroomsScreen extends StatefulWidget {
  const TeacherClassroomsScreen({super.key});

  @override
  State<TeacherClassroomsScreen> createState() =>
      _TeacherClassroomsScreenState();
}

class _TeacherClassroomsScreenState extends State<TeacherClassroomsScreen>
    with AutomaticKeepAliveClientMixin {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();

  ClassroomFilter _currentFilter = ClassroomFilter.all;
  ViewMode _viewMode = ViewMode.grid;
  String _searchQuery = '';

  // Debounce timer para el buscador
  Timer? _debounceTimer;

  // Cache de datos para evitar recargas
  List<ClassroomModel>? _cachedClassrooms;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _openClassroomDetail(ClassroomModel classroom) {
    Navigator.of(context).push(
      PageRouteBuilder(
        settings: const RouteSettings(name: 'classroom-detail'),
        transitionDuration: AppDesignSystem.durationFast,
        reverseTransitionDuration: AppDesignSystem.durationFast,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ClassroomDetailScreen(classroom: classroom);
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
  }

  List<ClassroomModel> _filterClassrooms(List<ClassroomModel> classrooms) {
    var filtered = classrooms;

    // Aplicar filtro de estado
    switch (_currentFilter) {
      case ClassroomFilter.active:
        filtered = filtered.where((c) => c.isActive).toList();
        break;
      case ClassroomFilter.inactive:
        filtered = filtered.where((c) => !c.isActive).toList();
        break;
      case ClassroomFilter.all:
        break;
    }

    // Aplicar búsqueda
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((classroom) {
        return classroom.name.toLowerCase().contains(query) ||
            classroom.grade.toLowerCase().contains(query) ||
            classroom.section.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_currentUser == null) {
      return Scaffold(
        body: ErrorStateWidget(
          message:
              'Usuario no autenticado. Por favor inicia sesión nuevamente.',
          icon: Icons.person_off,
          onRetry: () => Navigator.of(context).pushReplacementNamed('/login'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundLight,
      body: SafeArea(child: _buildClassroomsList(context)),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            context,
            label: 'Todas',
            filter: ClassroomFilter.all,
            icon: Icons.all_inclusive,
          ),
          SizedBox(width: AppDesignSystem.getSpaceSM(context)),
          _buildFilterChip(
            context,
            label: 'Activas',
            filter: ClassroomFilter.active,
            icon: Icons.check_circle,
          ),
          SizedBox(width: AppDesignSystem.getSpaceSM(context)),
          _buildFilterChip(
            context,
            label: 'Inactivas',
            filter: ClassroomFilter.inactive,
            icon: Icons.cancel,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required ClassroomFilter filter,
    required IconData icon,
  }) {
    final isSelected = _currentFilter == filter;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppDesignSystem.spacing(context, 16),
            color: isSelected
                ? AppDesignSystem.textOnPrimary
                : AppDesignSystem.textSecondary,
          ),
          SizedBox(width: AppDesignSystem.getSpaceXS(context)),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _currentFilter = filter;
        });
      },
      backgroundColor: AppDesignSystem.backgroundLight,
      selectedColor: AppDesignSystem.primaryColor,
      checkmarkColor: AppDesignSystem.textOnPrimary,
      labelStyle: AppDesignSystem.labelMedium(context).copyWith(
        color: isSelected
            ? AppDesignSystem.textOnPrimary
            : AppDesignSystem.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AppDesignSystem.borderRadiusFull,
        side: BorderSide(
          color: isSelected
              ? AppDesignSystem.primaryColor
              : AppDesignSystem.borderColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      padding: AppDesignSystem.paddingSymmetric(
        context,
        horizontal: AppDesignSystem.spaceSM,
        vertical: AppDesignSystem.spaceXS,
      ),
    );
  }

  Widget _buildViewToggle(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppDesignSystem.backgroundLight,
        borderRadius: AppDesignSystem.borderRadiusMD,
        border: Border.all(color: AppDesignSystem.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewButton(context, icon: Icons.grid_view, mode: ViewMode.grid),
          Container(
            width: 1,
            height: AppDesignSystem.spacing(context, 24),
            color: AppDesignSystem.borderColor,
          ),
          _buildViewButton(context, icon: Icons.view_list, mode: ViewMode.list),
        ],
      ),
    );
  }

  Widget _buildViewButton(
    BuildContext context, {
    required IconData icon,
    required ViewMode mode,
  }) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _viewMode = mode;
        });
      },
      borderRadius: AppDesignSystem.borderRadiusSM,
      child: Container(
        padding: AppDesignSystem.paddingAll(context, AppDesignSystem.spaceSM),
        child: Icon(
          icon,
          color: isSelected
              ? AppDesignSystem.primaryColor
              : AppDesignSystem.textSecondary,
          size: AppDesignSystem.spacing(context, 20),
        ),
      ),
    );
  }

  Widget _buildClassroomsList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: TeacherService.getClassroomsByTeacher(_currentUser!.uid),
      builder: (context, snapshot) {
        // Mostrar loading solo en la primera carga
        if (snapshot.connectionState == ConnectionState.waiting &&
            _cachedClassrooms == null) {
          return const LoadingStateWidget(message: 'Cargando aulas...');
        }

        if (snapshot.hasError) {
          return ErrorStateWidget(
            message: 'Error al cargar las aulas: ${snapshot.error}',
            onRetry: () => setState(() {
              _cachedClassrooms = null;
            }),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.class_,
            title: 'No tienes aulas asignadas',
            message:
                'Contacta al administrador para que te asigne aulas para este periodo.',
            color: AppDesignSystem.infoColor,
          );
        }

        // Actualizar cache solo cuando hay nuevos datos
        if (snapshot.hasData) {
          _cachedClassrooms = snapshot.data!.docs
              .map((doc) => ClassroomModel.fromFirestore(doc))
              .toList();
        }

        final allClassrooms = _cachedClassrooms ?? [];
        final filteredClassrooms = _filterClassrooms(allClassrooms);

        // Si no hay resultados después del filtro
        if (filteredClassrooms.isEmpty) {
          return CustomScrollView(
            slivers: [
              _buildSliverSearchBar(context),
              _buildSliverFiltersAndView(context),
              SliverFillRemaining(
                child: EmptyStateWidget(
                  icon: Icons.search_off,
                  title: 'No se encontraron resultados',
                  message: _searchQuery.isNotEmpty
                      ? 'No hay aulas que coincidan con "$_searchQuery"'
                      : 'No hay aulas ${_currentFilter == ClassroomFilter.active ? "activas" : "inactivas"} en este momento.',
                  color: AppDesignSystem.textSecondary,
                ),
              ),
            ],
          );
        }

        // Vista con resultados
        return CustomScrollView(
          slivers: [
            _buildSliverSearchBar(context),
            _buildSliverFiltersAndView(context),
            _buildSliverStatistics(context, allClassrooms, filteredClassrooms),
            _viewMode == ViewMode.grid
                ? _buildSliverGridView(context, filteredClassrooms)
                : _buildSliverListView(context, filteredClassrooms),
          ],
        );
      },
    );
  }

  Widget _buildSliverSearchBar(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        padding: AppDesignSystem.paddingAll(context, AppDesignSystem.spaceMD),
        color: AppDesignSystem.surfaceColor,
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            // Cancelar el timer anterior si existe
            _debounceTimer?.cancel();

            // Crear nuevo timer de 300ms
            _debounceTimer = Timer(const Duration(milliseconds: 300), () {
              setState(() {
                _searchQuery = value;
              });
            });
          },
          decoration: InputDecoration(
            hintText: 'Buscar por nombre, grado o sección...',
            hintStyle: AppDesignSystem.bodyMedium(
              context,
            ).copyWith(color: AppDesignSystem.textDisabled),
            prefixIcon: Icon(
              Icons.search,
              color: AppDesignSystem.textSecondary,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _debounceTimer?.cancel();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    color: AppDesignSystem.textSecondary,
                  )
                : null,
            filled: true,
            fillColor: AppDesignSystem.backgroundLight,
            border: OutlineInputBorder(
              borderRadius: AppDesignSystem.borderRadiusMD,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppDesignSystem.borderRadiusMD,
              borderSide: BorderSide(
                color: AppDesignSystem.borderColor,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppDesignSystem.borderRadiusMD,
              borderSide: BorderSide(
                color: AppDesignSystem.primaryColor,
                width: 2,
              ),
            ),
            contentPadding: AppDesignSystem.paddingSymmetric(
              context,
              horizontal: AppDesignSystem.spaceMD,
              vertical: AppDesignSystem.spaceSM,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverFiltersAndView(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        padding: AppDesignSystem.paddingSymmetric(
          context,
          horizontal: AppDesignSystem.spaceMD,
          vertical: AppDesignSystem.spaceSM,
        ),
        color: AppDesignSystem.surfaceColor,
        child: Row(
          children: [
            Expanded(child: _buildFilterChips(context)),
            SizedBox(width: AppDesignSystem.getSpaceSM(context)),
            _buildViewToggle(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverStatistics(
    BuildContext context,
    List<ClassroomModel> allClassrooms,
    List<ClassroomModel> filteredClassrooms,
  ) {
    final activeCount = allClassrooms.where((c) => c.isActive).length;
    final inactiveCount = allClassrooms.length - activeCount;
    final totalCapacity = allClassrooms.fold<int>(
      0,
      (sum, classroom) => sum + classroom.capacity,
    );

    return SliverToBoxAdapter(
      child: Container(
        margin: AppDesignSystem.paddingAll(context, AppDesignSystem.spaceMD),
        padding: AppDesignSystem.paddingAll(context, AppDesignSystem.spaceMD),
        decoration: BoxDecoration(
          color: AppDesignSystem.surfaceColor,
          borderRadius: AppDesignSystem.borderRadiusMD,
          boxShadow: [AppDesignSystem.getShadowSM()],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart,
                  color: AppDesignSystem.primaryColor,
                  size: AppDesignSystem.spacing(context, 20),
                ),
                SizedBox(width: AppDesignSystem.getSpaceSM(context)),
                Text(
                  'Estadísticas',
                  style: AppDesignSystem.titleMedium(context),
                ),
              ],
            ),
            SizedBox(height: AppDesignSystem.getSpaceMD(context)),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.class_,
                    label: 'Total',
                    value: '${allClassrooms.length}',
                    color: AppDesignSystem.primaryColor,
                  ),
                ),
                SizedBox(width: AppDesignSystem.getSpaceSM(context)),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.check_circle,
                    label: 'Activas',
                    value: '$activeCount',
                    color: AppDesignSystem.successColor,
                  ),
                ),
                SizedBox(width: AppDesignSystem.getSpaceSM(context)),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.cancel,
                    label: 'Inactivas',
                    value: '$inactiveCount',
                    color: AppDesignSystem.errorColor,
                  ),
                ),
                SizedBox(width: AppDesignSystem.getSpaceSM(context)),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.groups,
                    label: 'Capacidad',
                    value: '$totalCapacity',
                    color: AppDesignSystem.infoColor,
                  ),
                ),
              ],
            ),
            if (filteredClassrooms.length != allClassrooms.length) ...[
              SizedBox(height: AppDesignSystem.getSpaceSM(context)),
              Container(
                padding: AppDesignSystem.paddingSymmetric(
                  context,
                  horizontal: AppDesignSystem.spaceSM,
                  vertical: AppDesignSystem.spaceXS,
                ),
                decoration: BoxDecoration(
                  color: AppDesignSystem.infoColor.withValues(alpha: 0.1),
                  borderRadius: AppDesignSystem.borderRadiusSM,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.filter_alt,
                      size: AppDesignSystem.spacing(context, 14),
                      color: AppDesignSystem.infoColor,
                    ),
                    SizedBox(width: AppDesignSystem.getSpaceXS(context)),
                    Text(
                      'Mostrando ${filteredClassrooms.length} de ${allClassrooms.length} aulas',
                      style: AppDesignSystem.labelMedium(
                        context,
                      ).copyWith(color: AppDesignSystem.infoColor),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: AppDesignSystem.paddingAll(context, AppDesignSystem.spaceSM),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppDesignSystem.borderRadiusSM,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: AppDesignSystem.spacing(context, 20)),
          SizedBox(height: AppDesignSystem.getSpaceXS(context)),
          Text(
            value,
            style: AppDesignSystem.headlineMedium(
              context,
            ).copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: AppDesignSystem.labelMedium(context).copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSliverGridView(
    BuildContext context,
    List<ClassroomModel> classrooms,
  ) {
    final crossAxisCount = AppDesignSystem.getCrossAxisCount(context);

    return SliverPadding(
      padding: AppDesignSystem.paddingAll(context, AppDesignSystem.spaceMD),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: AppDesignSystem.getChildAspectRatio(context),
          crossAxisSpacing: AppDesignSystem.getSpaceMD(context),
          mainAxisSpacing: AppDesignSystem.getSpaceMD(context),
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final classroom = classrooms[index];
          return ClassroomCard(
            classroom: classroom,
            onTap: () => _openClassroomDetail(classroom),
            compact: false,
            showScheduleInfo: true,
          );
        }, childCount: classrooms.length),
      ),
    );
  }

  Widget _buildSliverListView(
    BuildContext context,
    List<ClassroomModel> classrooms,
  ) {
    return SliverPadding(
      padding: AppDesignSystem.paddingAll(context, AppDesignSystem.spaceMD),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final classroom = classrooms[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < classrooms.length - 1
                  ? AppDesignSystem.getSpaceSM(context)
                  : 0,
            ),
            child: ClassroomCard(
              classroom: classroom,
              onTap: () => _openClassroomDetail(classroom),
              compact: true,
              showScheduleInfo: false,
            ),
          );
        }, childCount: classrooms.length),
      ),
    );
  }
}

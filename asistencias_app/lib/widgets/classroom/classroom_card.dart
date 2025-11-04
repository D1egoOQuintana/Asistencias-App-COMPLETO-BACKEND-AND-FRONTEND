import 'package:flutter/material.dart';
import '../../models/classroom_model.dart';
import '../../theme/app_design_system.dart';

/// Card de aula reutilizable con variantes compacta y completa
class ClassroomCard extends StatelessWidget {
  final ClassroomModel classroom;
  final VoidCallback onTap;
  final bool compact;
  final bool showScheduleInfo;

  const ClassroomCard({
    super.key,
    required this.classroom,
    required this.onTap,
    this.compact = false,
    this.showScheduleInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppDesignSystem.elevationSM,
      shadowColor: AppDesignSystem.primaryColor.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: AppDesignSystem.borderRadiusMD,
        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDesignSystem.borderRadiusMD,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppDesignSystem.borderRadiusMD,
            gradient: AppDesignSystem.getCardGradient(
              AppDesignSystem.primaryColor,
            ),
          ),
          padding: compact
              ? AppDesignSystem.paddingAll(context, AppDesignSystem.spaceSM)
              : AppDesignSystem.paddingAll(context, AppDesignSystem.spaceMD),
          child: compact
              ? _buildCompactContent(context)
              : _buildFullContent(context),
        ),
      ),
    );
  }

  Widget _buildCompactContent(BuildContext context) {
    return Row(
      children: [
        _buildSectionBadge(context),
        SizedBox(width: AppDesignSystem.getSpaceMD(context)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                classroom.name,
                style: AppDesignSystem.titleMedium(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: AppDesignSystem.getSpaceXS(context)),
              Text(
                '${classroom.grade} - Sección ${classroom.section}',
                style: AppDesignSystem.bodySmall(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Icon(
          Icons.arrow_forward_ios,
          color: AppDesignSystem.textDisabled,
          size: AppDesignSystem.spacing(context, 16),
        ),
      ],
    );
  }

  Widget _buildFullContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con badge y título
        Row(
          children: [
            _buildSectionBadge(context),
            SizedBox(width: AppDesignSystem.getSpaceMD(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classroom.name,
                    style: AppDesignSystem.titleLarge(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: AppDesignSystem.getSpaceXS(context)),
                  Text(
                    '${classroom.grade} - Sección ${classroom.section}',
                    style: AppDesignSystem.bodySmall(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _buildStatusBadge(context),
          ],
        ),

        SizedBox(height: AppDesignSystem.getSpaceMD(context)),

        // Info chips
        Row(
          children: [
            Expanded(
              child: _buildInfoChip(
                context,
                icon: Icons.groups,
                label: 'Capacidad',
                value: '${classroom.capacity}',
                color: AppDesignSystem.infoColor,
              ),
            ),
            SizedBox(width: AppDesignSystem.getSpaceSM(context)),
            Expanded(
              child: _buildInfoChip(
                context,
                icon: Icons.person,
                label: 'Inscritos',
                value: '0', // Se puede pasar como parámetro opcional
                color: AppDesignSystem.successColor,
              ),
            ),
          ],
        ),

        // Información de horario
        if (showScheduleInfo) ...[
          SizedBox(height: AppDesignSystem.getSpaceSM(context)),
          _buildScheduleInfo(context),
        ],
      ],
    );
  }

  Widget _buildSectionBadge(BuildContext context) {
    return Container(
      width: AppDesignSystem.spacing(context, 48),
      height: AppDesignSystem.spacing(context, 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppDesignSystem.primaryColor, AppDesignSystem.primaryLight],
        ),
        borderRadius: AppDesignSystem.borderRadiusMD,
        boxShadow: [
          AppDesignSystem.getShadowSM(color: AppDesignSystem.primaryColor),
        ],
      ),
      child: Center(
        child: Text(
          classroom.section.toUpperCase(),
          style: AppDesignSystem.titleLarge(context).copyWith(
            color: AppDesignSystem.textOnPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final isActive = classroom.isActive;
    return Container(
      padding: AppDesignSystem.paddingSymmetric(
        context,
        horizontal: AppDesignSystem.spaceSM,
        vertical: AppDesignSystem.spaceXS,
      ),
      decoration: BoxDecoration(
        color: AppDesignSystem.getStatusColor(
          isActive,
          light: true,
        ).withValues(alpha: 0.2),
        borderRadius: AppDesignSystem.borderRadiusFull,
        border: Border.all(
          color: AppDesignSystem.getStatusColor(isActive),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.cancel,
            color: AppDesignSystem.getStatusColor(isActive),
            size: AppDesignSystem.spacing(context, 14),
          ),
          SizedBox(width: AppDesignSystem.getSpaceXS(context)),
          Text(
            isActive ? 'Activa' : 'Inactiva',
            style: AppDesignSystem.labelMedium(context).copyWith(
              color: AppDesignSystem.getStatusColor(isActive),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: AppDesignSystem.spacing(context, 18)),
          SizedBox(width: AppDesignSystem.getSpaceXS(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppDesignSystem.labelMedium(
                    context,
                  ).copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: AppDesignSystem.titleMedium(
                    context,
                  ).copyWith(color: color, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleInfo(BuildContext context) {
    final hasSchedule = classroom.hasSchedule;
    return Container(
      padding: AppDesignSystem.paddingAll(context, AppDesignSystem.spaceSM),
      decoration: BoxDecoration(
        color: hasSchedule
            ? AppDesignSystem.successColor.withValues(alpha: 0.1)
            : AppDesignSystem.warningColor.withValues(alpha: 0.1),
        borderRadius: AppDesignSystem.borderRadiusSM,
        border: Border.all(
          color: hasSchedule
              ? AppDesignSystem.successColor.withValues(alpha: 0.3)
              : AppDesignSystem.warningColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasSchedule ? Icons.schedule : Icons.warning_amber,
            color: hasSchedule
                ? AppDesignSystem.successColor
                : AppDesignSystem.warningColor,
            size: AppDesignSystem.spacing(context, 18),
          ),
          SizedBox(width: AppDesignSystem.getSpaceSM(context)),
          Expanded(
            child: Text(
              hasSchedule ? 'Horarios configurados' : 'Configurar horarios',
              style: AppDesignSystem.labelMedium(context).copyWith(
                color: hasSchedule
                    ? AppDesignSystem.successColor
                    : AppDesignSystem.warningColor,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

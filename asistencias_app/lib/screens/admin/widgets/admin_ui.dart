import 'package:flutter/material.dart';

import '../../../theme/app_design_system.dart';

class AdminUi {
  static const canvas = Color(0xFFF4F6FA);
  static const surface = Colors.white;
  static const border = Color(0xFFE6EAF0);
  static const primary = Color(0xFF1976D2);
  static const navy = Color(0xFF0D1B2A);
  static const rowHover = Color(0xFFF9FAFC);
  static const neutralAction = Color(0xFF5A6B7B);

  static const pagePaddingDesktop = 24.0;
  static const pagePaddingTablet = 20.0;
  static const pagePaddingMobile = 16.0;

  static double pagePadding(double width) {
    if (width >= AppDesignSystem.breakpointDesktop) {
      return pagePaddingDesktop;
    }
    if (width >= AppDesignSystem.breakpointMobile) {
      return pagePaddingTablet;
    }
    return pagePaddingMobile;
  }

  static BoxDecoration cardDecoration({bool elevated = true}) {
    return BoxDecoration(
      color: surface,
      borderRadius: AppDesignSystem.borderRadiusLG,
      border: Border.all(color: border),
      boxShadow: elevated ? [AppDesignSystem.getShadowSM()] : null,
    );
  }

  static const tableHeaderTextStyle = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: AppDesignSystem.textSecondary,
    letterSpacing: 0.7,
  );

  static BoxDecoration tableHeaderDecoration() {
    return const BoxDecoration(
      color: canvas,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDesignSystem.radiusLG),
      ),
      border: Border(bottom: BorderSide(color: border)),
    );
  }

  static BoxDecoration rowDecoration({
    required bool hovered,
    required bool isLast,
  }) {
    return BoxDecoration(
      color: hovered ? rowHover : surface,
      border: isLast ? null : const Border(bottom: BorderSide(color: border)),
    );
  }

  static Color softBg(Color color) => color.withValues(alpha: 0.09);
}

class AdminCompactHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const AdminCompactHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppDesignSystem.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 16),
          action!,
        ],
      ],
    );
  }
}

class AdminFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;
  final IconData? icon;

  const AdminFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AdminUi.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: AppDesignSystem.borderRadiusFull,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDesignSystem.durationFast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AdminUi.softBg(color) : AdminUi.surface,
            borderRadius: AppDesignSystem.borderRadiusFull,
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.45) : AdminUi.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: selected ? color : AppDesignSystem.textSecondary,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? color : AppDesignSystem.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminStatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const AdminStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AdminUi.softBg(color),
        borderRadius: AppDesignSystem.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon == null)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          else
            Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool destructive;
  final Color? color;

  const AdminActionIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.destructive = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fg = destructive
        ? AppDesignSystem.errorColor
        : (color ?? AdminUi.neutralAction);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: AppDesignSystem.borderRadiusSM,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 17, color: fg),
        ),
      ),
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final bool error;

  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = error
        ? AppDesignSystem.errorColor
        : AppDesignSystem.textSecondary.withValues(alpha: 0.75);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppDesignSystem.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

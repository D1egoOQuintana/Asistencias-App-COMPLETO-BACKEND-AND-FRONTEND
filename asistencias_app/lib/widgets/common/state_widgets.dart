import 'package:flutter/material.dart';
import '../../theme/app_design_system.dart';

/// Widget de estado vacío reutilizable
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppDesignSystem.textSecondary;

    return Center(
      child: SingleChildScrollView(
        padding: AppDesignSystem.paddingAll(context, AppDesignSystem.spaceXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: AppDesignSystem.paddingAll(
                context,
                AppDesignSystem.spaceLG,
              ),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppDesignSystem.spacing(context, 64),
                color: iconColor,
              ),
            ),
            SizedBox(height: AppDesignSystem.getSpaceLG(context)),
            Text(
              title,
              style: AppDesignSystem.headlineMedium(context),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppDesignSystem.getSpaceSM(context)),
            Text(
              message,
              style: AppDesignSystem.bodyMedium(
                context,
              ).copyWith(color: AppDesignSystem.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: AppDesignSystem.getSpaceLG(context)),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: color ?? AppDesignSystem.primaryColor,
                  padding: AppDesignSystem.paddingSymmetric(
                    context,
                    horizontal: AppDesignSystem.spaceLG,
                    vertical: AppDesignSystem.spaceMD,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget de carga reutilizable
class LoadingStateWidget extends StatelessWidget {
  final String? message;

  const LoadingStateWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            color: AppDesignSystem.primaryColor,
          ),
          if (message != null) ...[
            SizedBox(height: AppDesignSystem.getSpaceMD(context)),
            Text(
              message!,
              style: AppDesignSystem.bodyMedium(
                context,
              ).copyWith(color: AppDesignSystem.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Widget de error reutilizable
class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: AppDesignSystem.paddingAll(context, AppDesignSystem.spaceLG),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: AppDesignSystem.paddingAll(
                context,
                AppDesignSystem.spaceLG,
              ),
              decoration: BoxDecoration(
                color: AppDesignSystem.errorColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppDesignSystem.spacing(context, 56),
                color: AppDesignSystem.errorColor,
              ),
            ),
            SizedBox(height: AppDesignSystem.getSpaceLG(context)),
            Text(
              'Error',
              style: AppDesignSystem.headlineMedium(
                context,
              ).copyWith(color: AppDesignSystem.errorColor),
            ),
            SizedBox(height: AppDesignSystem.getSpaceSM(context)),
            Text(
              message,
              style: AppDesignSystem.bodyMedium(
                context,
              ).copyWith(color: AppDesignSystem.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              SizedBox(height: AppDesignSystem.getSpaceLG(context)),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppDesignSystem.errorColor,
                  padding: AppDesignSystem.paddingSymmetric(
                    context,
                    horizontal: AppDesignSystem.spaceLG,
                    vertical: AppDesignSystem.spaceMD,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../theme/app_design_system.dart';

class AdminPlaceholderScreen extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color? accentColor;

  /// "Qué podrás hacer aquí" — máx 3 bullets recomendados.
  final List<String> bullets;

  const AdminPlaceholderScreen({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.accentColor,
    this.bullets = const [],
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppDesignSystem.primaryColor;

    return Container(
      color: const Color(0xFFF4F6FA),
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                  child: Icon(icon, size: 46, color: color),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: AppDesignSystem.borderRadiusFull,
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 14, color: color),
                      const SizedBox(width: 6),
                      Text(
                        'Pronto',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppDesignSystem.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (bullets.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _buildBulletsCard(color),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.engineering_outlined,
                      size: 15,
                      color: AppDesignSystem.textDisabled,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Módulo en desarrollo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppDesignSystem.textDisabled,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulletsCard(Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppDesignSystem.surfaceColor,
        borderRadius: AppDesignSystem.borderRadiusLG,
        border: Border.all(color: const Color(0xFFE6EAF0)),
        boxShadow: [AppDesignSystem.getShadowSM()],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUÉ PODRÁS HACER AQUÍ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppDesignSystem.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: color.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: AppDesignSystem.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

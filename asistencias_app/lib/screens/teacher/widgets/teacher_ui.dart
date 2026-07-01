import 'package:flutter/material.dart';

import '../../../theme/app_design_system.dart';

/// UI kit del portal DOCENTE (Fase 0 — lenguaje de diseño).
///
/// Reglas que estos componentes hacen cumplir:
/// - El azul (`primaryColor`) es acento: acción primaria, selección, estado.
///   NUNCA fondo emocional ni color de todos los números.
/// - Superficies planas: borde 1px + sombra sutil. Cero gradientes.
/// - Color por SIGNIFICADO: verde/ámbar/rojo para presente/tardanza/ausente.
/// - Un solo estilo de "número grande" (`AppDesignSystem.metricLarge`).
///
/// Las 7 pantallas docente reusan estos 3 primitivos para verse coherentes.
class TeacherUi {
  TeacherUi._();

  /// Borde neutro estándar de tarjetas y divisores.
  static const Color border = Color(0xFFE6EAF0);

  /// Lienzo neutro de fondo de pantalla (gris muy claro).
  static const Color canvas = AppDesignSystem.backgroundLight;

  /// Decoración estándar de tarjeta plana (sin gradiente).
  static BoxDecoration cardDecoration({bool elevated = false}) => BoxDecoration(
        color: AppDesignSystem.surfaceColor,
        borderRadius: AppDesignSystem.borderRadiusLG,
        border: Border.all(color: border),
        boxShadow: elevated
            ? [AppDesignSystem.getShadowSM()]
            : const <BoxShadow>[],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. CARD — contenedor plano estándar
// ─────────────────────────────────────────────────────────────────────────────

/// Tarjeta plana estándar del portal docente.
/// Reemplaza a las cards artesanales con gradiente/sombra pesada.
class TeacherCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool elevated;
  final VoidCallback? onTap;

  const TeacherCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.elevated = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    final decorated = DecoratedBox(
      decoration: TeacherUi.cardDecoration(elevated: elevated),
      child: content,
    );
    if (onTap == null) return decorated;
    return Material(
      color: Colors.transparent,
      borderRadius: AppDesignSystem.borderRadiusLG,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: TeacherUi.cardDecoration(elevated: elevated),
          child: content,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. METRIC — KPI estándar (número grande + label)
// ─────────────────────────────────────────────────────────────────────────────

/// Tile de métrica/KPI. Un número grande casi-negro (o de color SOLO si el
/// valor representa un estado), un label corto y un icono sólido pequeño.
/// Sin marcas de agua fantasma, sin gradientes.
class TeacherMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  /// Color de acento del icono. Por defecto azul primario. Para métricas que
  /// SON un estado (ej. % de ausentes), pasar el color semántico.
  final Color accent;

  /// Texto secundario opcional bajo el número (ej. "+0.1% vs inicio").
  final String? sublabel;

  /// Color del sublabel (ej. verde para variación positiva).
  final Color? sublabelColor;

  const TeacherMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = AppDesignSystem.primaryColor,
    this.sublabel,
    this.sublabelColor,
  });

  @override
  Widget build(BuildContext context) {
    return TeacherCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: AppDesignSystem.borderRadiusSM,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppDesignSystem.labelMedium(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: AppDesignSystem.metricLarge(context)),
          if (sublabel != null) ...[
            const SizedBox(height: 4),
            Text(
              sublabel!,
              style: AppDesignSystem.bodySmall(context).copyWith(
                color: sublabelColor ?? AppDesignSystem.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. STATUS PILL — etiqueta de estado por color semántico
// ─────────────────────────────────────────────────────────────────────────────

/// Pill de estado. Genérico (label + color), con factories para los casos
/// comunes: asistencia (presente/tardanza/ausente) y estado de aula.
class TeacherStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const TeacherStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  /// Presente = verde, tardanza = ámbar, ausente = rojo.
  factory TeacherStatusPill.present() => const TeacherStatusPill(
        label: 'Presente',
        color: AppDesignSystem.attendancePresent,
        icon: Icons.check_circle_rounded,
      );

  factory TeacherStatusPill.late() => const TeacherStatusPill(
        label: 'Tardanza',
        color: AppDesignSystem.attendanceLate,
        icon: Icons.watch_later_rounded,
      );

  factory TeacherStatusPill.absent() => const TeacherStatusPill(
        label: 'Ausente',
        color: AppDesignSystem.attendanceAbsent,
        icon: Icons.cancel_rounded,
      );

  factory TeacherStatusPill.active(bool isActive) => TeacherStatusPill(
        label: isActive ? 'Activa' : 'Inactiva',
        color: isActive
            ? AppDesignSystem.successColor
            : AppDesignSystem.textSecondary,
        icon: isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppDesignSystem.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ] else ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

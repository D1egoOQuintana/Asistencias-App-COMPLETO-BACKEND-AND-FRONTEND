import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_design_system.dart';

/// Sistema visual central del Admin Web Panel.
/// Tokens + componentes compartidos. Ver ADMIN_DESIGN_GUIDE.md.
/// Regla: el admin nunca debe verse como app móvil estirada.
class AdminUi {
  // ── Superficies / lienzo ──────────────────────────────────────────────────
  static const canvas = Color(0xFFF4F6FA);
  static const surface = Colors.white;
  static const border = Color(0xFFE6EAF0);
  static const rowHover = Color(0xFFF9FAFC);

  // ── Marca / ancla ─────────────────────────────────────────────────────────
  static const primary = Color(0xFF1976D2);
  static const primaryLight = Color(0xFF42A5F5);
  static const navy = Color(0xFF0D1B2A);
  static const navyText = Color(0xFFB0BEC5);
  static const navySection = Color(0xFF6B7A8D);

  // ── Texto sobre superficies claras ────────────────────────────────────────
  static const textPrimary = AppDesignSystem.textPrimary;
  static const textSecondary = AppDesignSystem.textSecondary;
  static const textHint = Color(0xFF9AA7B4);
  static const neutralAction = Color(0xFF5A6B7B);

  // ── Semánticos (acento) + contenedores (fill suave) ───────────────────────
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFF57C00);
  static const error = Color(0xFFC62828);
  static const info = Color(0xFF1565C0);
  static const successBg = Color(0xFFE6F4EA);
  static const warningBg = Color(0xFFFFF3E0);
  static const errorBg = Color(0xFFFDECEA);
  static const infoBg = Color(0xFFE3F0FC);

  // ── Niveles de superficie (profundidad tonal, no drop-shadow pesado) ───────
  static const surface0 = Color(0xFFF7F9FD); // canvas / workspace
  static const surface1 = Colors.white; // cards / contenedores
  static const surface2 = Color(0xFFF2F4F8); // fills sutiles (header tabla, chips)

  /// Sombra suave casi imperceptible — define el borde, no "flota".
  static const List<BoxShadow> shadowSoft = [
    BoxShadow(color: Color(0x080D1B2A), blurRadius: 3, offset: Offset(0, 1)),
  ];

  // ── Paleta KPI institucional (baja saturación, sin "arcoíris") ─────────────
  // No-semánticos → familia azul/slate. Semánticos reales → success/warning.
  static const kpiPrimary = Color(0xFF1976D2);
  static const kpiInfo = Color(0xFF1565C0);
  static const kpiNeutral = Color(0xFF475569); // slate
  static const slate = Color(0xFF475569);
  static const slateSoft = Color(0xFF64748B);

  // ── Espaciado (múltiplos de 8) ────────────────────────────────────────────
  static const gapKpi = 16.0;
  static const gapSection = 16.0;
  static const fieldHeight = 44.0;

  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;

  // ── Radius ─────────────────────────────────────────────────────────────────
  static const rSm = 8.0;
  static const rMd = 12.0;
  static const rLg = 16.0;
  static const rXl = 20.0;

  static const pagePaddingDesktop = 24.0;
  static const pagePaddingTablet = 20.0;
  static const pagePaddingMobile = 16.0;

  // ── Tipografía base del admin (Inter, vía google_fonts ya instalado) ───────
  /// Estilo base (solo fontFamily Inter) para envolver un subárbol con
  /// `DefaultTextStyle.merge`, de modo que el texto herede Inter sin tocar
  /// login ni docente. Ver [AdminType] para la escala completa.
  static TextStyle get fontBase => GoogleFonts.inter();

  /// TextTheme Inter para tematizar un subárbol admin (Material widgets).
  static TextTheme interTextTheme(BuildContext context) =>
      GoogleFonts.interTextTheme(Theme.of(context).textTheme);

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

// ─────────────────────────────────────────────────────────────────────────────
// COLUMN HEADER (tablas) — overline 10.5 w700 secondary uppercase
// ─────────────────────────────────────────────────────────────────────────────

class AdminColHeader extends StatelessWidget {
  final String text;
  const AdminColHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AdminUi.tableHeaderTextStyle);
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGINACIÓN — barra reutilizable (10 por página, Anterior / Siguiente)
// ─────────────────────────────────────────────────────────────────────────────

/// Barra de paginación institucional. `page` es 0-based y ya viene acotado.
/// Si `onPrev`/`onNext` es null, el botón se muestra deshabilitado.
class AdminPaginationBar extends StatelessWidget {
  /// Filas por página usado en las tablas admin.
  static const int perPage = 10;

  final int page;
  final int pageCount;
  final int totalItems;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const AdminPaginationBar({
    super.key,
    required this.page,
    required this.pageCount,
    required this.totalItems,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AdminUi.surface,
        border: Border(top: BorderSide(color: AdminUi.border)),
      ),
      // Responsivo: en anchos estrechos los botones muestran solo el ícono y el
      // texto central se compacta a "X / Y", evitando overflow horizontal.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          final label = compact
              ? '${page + 1} / $pageCount'
              : 'Página ${page + 1} de $pageCount · $totalItems registros';
          return Row(
            children: [
              _PagerButton(
                icon: Icons.chevron_left_rounded,
                label: 'Anterior',
                onTap: onPrev,
                compact: compact,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    label,
                    style: AdminType.caption,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              _PagerButton(
                icon: Icons.chevron_right_rounded,
                label: 'Siguiente',
                trailingIcon: true,
                onTap: onNext,
                compact: compact,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool trailingIcon;
  final VoidCallback? onTap;
  /// Si `true`, muestra solo el ícono (sin label) para ahorrar ancho.
  final bool compact;

  const _PagerButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingIcon = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = enabled ? AdminUi.textPrimary : AppDesignSystem.textDisabled;
    final iconWidget = Icon(icon, size: 18, color: fg);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: AdminUi.surface,
        borderRadius: AppDesignSystem.borderRadiusMD,
        child: InkWell(
          borderRadius: AppDesignSystem.borderRadiusMD,
          onTap: onTap,
          child: Container(
            height: 34,
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
            decoration: BoxDecoration(
              borderRadius: AppDesignSystem.borderRadiusMD,
              border: Border.all(color: AdminUi.border),
            ),
            child: compact
                ? Tooltip(message: label, child: iconWidget)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!trailingIcon) ...[
                        iconWidget,
                        const SizedBox(width: 4),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                      if (trailingIcon) ...[
                        const SizedBox(width: 4),
                        iconWidget,
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SISTEMA DE COLUMNAS DE TABLA (header + filas comparten la MISMA spec)
// ─────────────────────────────────────────────────────────────────────────────

/// Definición declarativa de una columna de tabla admin. La MISMA lista de
/// columnas alimenta el header y cada fila, garantizando alineación perfecta.
///
/// - `AdminColumn.flex(n)` → columna fluida (Expanded flex n). Por defecto el
///   contenido se alinea a la izquierda (texto/celdas compuestas).
/// - `AdminColumn.fixed(w)` → columna de ancho fijo (chips, acciones). Por
///   defecto centrada; usa `align` para alinear (p. ej. acciones a la derecha).
class AdminColumn {
  final int flex;
  final double? width;
  final AlignmentGeometry align;
  final String? header; // etiqueta overline; null = sin título (acciones)
  /// Indent horizontal (en px) que se aplica SOLO al header. Útil para
  /// columnas compuestas (p. ej. avatar + nombre): permite que el título
  /// quede visualmente alineado con el texto principal de la celda, no con
  /// el avatar de la izquierda.
  final double headerIndent;

  const AdminColumn.flex(
    this.flex, {
    this.align = Alignment.centerLeft,
    this.header,
    this.headerIndent = 0,
  }) : width = null;

  const AdminColumn.fixed(
    this.width, {
    this.align = Alignment.center,
    this.header,
    this.headerIndent = 0,
  }) : flex = 0;

  bool get isFixed => width != null;
}

/// Helpers de layout de tabla institucional. Header y filas se construyen con
/// `headerRow(columns)` y `dataRow(columns, cells)` usando la misma `columns`.
class AdminTable {
  AdminTable._();

  /// Ancho estándar de la columna de acciones (Editar + menú "⋯").
  static const double actionColWidth = 84;

  /// Alto estándar de fila de datos.
  static const double rowHeight = 60;

  /// Padding horizontal estándar de header y filas (deben coincidir).
  static const EdgeInsets rowPadding = EdgeInsets.symmetric(horizontal: 16);

  static const EdgeInsets _headerPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 11);

  /// Aplica la spec de una columna a un widget (celda de header o de datos).
  /// - Fijas: SizedBox(width) + Align(align).
  /// - Fluidas: Expanded(flex). En header se alinea la etiqueta; en datos el
  ///   contenido fluye (las celdas compuestas manejan su propio interior).
  static Widget _wrap(AdminColumn c, Widget child, {required bool isHeader}) {
    // Aplicar indent SOLO en el header, cuando la columna lo define.
    final Widget visual = (isHeader && c.headerIndent > 0)
        ? Padding(
            padding: EdgeInsetsDirectional.only(start: c.headerIndent),
            child: child,
          )
        : child;
    if (c.isFixed) {
      return SizedBox(
        width: c.width,
        child: Align(alignment: c.align, child: visual),
      );
    }
    return Expanded(
      flex: c.flex,
      child: isHeader ? Align(alignment: c.align, child: visual) : visual,
    );
  }

  /// Header institucional (overline) a partir de las columnas.
  ///
  /// - `decorated` (def. true): fondo canvas con esquinas superiores redondeadas
  ///   (cuando el header es el tope de la card). Usa `false` cuando el header va
  ///   embebido bajo un título de sección (sin redondeo superior).
  /// - `padding`: anula el padding por defecto para alinear con filas que usan
  ///   un padding horizontal distinto (p. ej. 20px).
  static Widget headerRow(
    List<AdminColumn> columns, {
    bool decorated = true,
    EdgeInsets? padding,
  }) {
    return Container(
      decoration: decorated
          ? AdminUi.tableHeaderDecoration()
          : const BoxDecoration(
              color: AdminUi.canvas,
              border: Border(bottom: BorderSide(color: AdminUi.border)),
            ),
      padding: padding ?? _headerPadding,
      child: Row(
        children: [
          for (final c in columns)
            _wrap(
              c,
              c.header == null
                  ? const SizedBox.shrink()
                  : AdminColHeader(c.header!),
              isHeader: true,
            ),
        ],
      ),
    );
  }

  /// Fila de datos: las celdas se posicionan con la MISMA spec del header.
  static Widget dataRow(List<AdminColumn> columns, List<Widget> cells) {
    assert(columns.length == cells.length,
        'columns (${columns.length}) y cells (${cells.length}) deben coincidir');
    return Row(
      children: [
        for (var i = 0; i < columns.length; i++)
          _wrap(columns[i], cells[i], isHeader: false),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INPUTS — decoración consistente para búsqueda y formularios admin
// ─────────────────────────────────────────────────────────────────────────────

class AdminInputs {
  /// Decoración estándar de campo de formulario / búsqueda (web, 40–44 px).
  static InputDecoration decoration({
    String? label,
    String? hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
    Color fill = AdminUi.surface,
  }) {
    OutlineInputBorder side(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: AppDesignSystem.borderRadiusMD,
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: AdminUi.textSecondary),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, size: 18, color: AdminUi.textSecondary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fill,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: side(AdminUi.border),
      enabledBorder: side(AdminUi.border),
      focusedBorder: side(AdminUi.primary, 1.5),
      errorBorder: side(AppDesignSystem.errorColor),
      focusedErrorBorder: side(AppDesignSystem.errorColor, 1.5),
    );
  }
}

/// Caja de búsqueda compacta y consistente (44 px, radius MD).
class AdminSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasValue;
  final double height;

  const AdminSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
    required this.hasValue,
    this.height = AdminUi.fieldHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13.5, color: AdminUi.textPrimary),
        decoration: AdminInputs.decoration(
          hint: hint,
          prefixIcon: Icons.search_rounded,
          suffixIcon: hasValue
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  splashRadius: 18,
                  color: AdminUi.textSecondary,
                  onPressed: onClear,
                )
              : null,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTONES — jerarquía: primary · secondary · ghost · danger
// ─────────────────────────────────────────────────────────────────────────────

enum AdminButtonVariant { primary, secondary, ghost, danger }

class AdminButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AdminButtonVariant variant;
  final bool loading;
  final bool expand;

  const AdminButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.variant = AdminButtonVariant.primary,
    this.loading = false,
    this.expand = false,
  });

  const AdminButton.primary({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
    this.expand = false,
  }) : variant = AdminButtonVariant.primary;

  const AdminButton.secondary({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
    this.expand = false,
  }) : variant = AdminButtonVariant.secondary;

  const AdminButton.ghost({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
    this.expand = false,
  }) : variant = AdminButtonVariant.ghost;

  const AdminButton.danger({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
    this.expand = false,
  }) : variant = AdminButtonVariant.danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    late final Color bg;
    late final Color fg;
    Border? side;

    switch (variant) {
      case AdminButtonVariant.primary:
        bg = AdminUi.primary;
        fg = Colors.white;
      case AdminButtonVariant.danger:
        bg = AppDesignSystem.errorColor;
        fg = Colors.white;
      case AdminButtonVariant.secondary:
        bg = AdminUi.surface;
        fg = AdminUi.textPrimary;
        side = Border.all(color: AdminUi.border);
      case AdminButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AdminUi.primary;
    }

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: 18, color: fg),
        if ((loading || icon != null)) const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: bg,
        borderRadius: AppDesignSystem.borderRadiusMD,
        child: InkWell(
          borderRadius: AppDesignSystem.borderRadiusMD,
          onTap: enabled ? onPressed : null,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: AppDesignSystem.borderRadiusMD,
              border: side,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON — bloque base reutilizable para estados de carga
// ─────────────────────────────────────────────────────────────────────────────

class AdminSkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? radius;

  const AdminSkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF1),
        borderRadius: radius ?? AppDesignSystem.borderRadiusSM,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEEDBACK — sistema central de mensajes (success · warning · error · info)
// ─────────────────────────────────────────────────────────────────────────────

enum AdminFeedbackType { success, warning, error, info }

/// Mensajes institucionales (toasts) coherentes para todo el admin.
/// Superficie blanca + ícono y borde de acento semántico (no el SnackBar
/// plano de color sólido). Usa `AdminFeedback.success(context, '...')`, etc.
class AdminFeedback {
  AdminFeedback._();

  static ({Color accent, IconData icon}) _spec(AdminFeedbackType t) {
    switch (t) {
      case AdminFeedbackType.success:
        return (accent: AdminUi.success, icon: Icons.check_circle_rounded);
      case AdminFeedbackType.warning:
        return (accent: AdminUi.warning, icon: Icons.warning_amber_rounded);
      case AdminFeedbackType.error:
        return (accent: AdminUi.error, icon: Icons.error_outline_rounded);
      case AdminFeedbackType.info:
        return (accent: AdminUi.info, icon: Icons.info_outline_rounded);
    }
  }

  /// Construye el SnackBar temático (para usar con un `ScaffoldMessengerState`
  /// ya capturado, p. ej. tras un `await`).
  static SnackBar snack(AdminFeedbackType type, String message) {
    final s = _spec(type);
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.white,
      elevation: 6,
      duration: Duration(seconds: type == AdminFeedbackType.error ? 5 : 3),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: AppDesignSystem.borderRadiusMD,
        side: BorderSide(color: s.accent.withValues(alpha: 0.35)),
      ),
      content: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.accent.withValues(alpha: 0.12),
              borderRadius: AppDesignSystem.borderRadiusSM,
            ),
            child: Icon(s.icon, size: 18, color: s.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AdminUi.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void show(BuildContext context, AdminFeedbackType type, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snack(type, message));
  }

  static void success(BuildContext context, String message) =>
      show(context, AdminFeedbackType.success, message);
  static void warning(BuildContext context, String message) =>
      show(context, AdminFeedbackType.warning, message);
  static void error(BuildContext context, String message) =>
      show(context, AdminFeedbackType.error, message);
  static void info(BuildContext context, String message) =>
      show(context, AdminFeedbackType.info, message);
}

// ─────────────────────────────────────────────────────────────────────────────
// TIPOGRAFÍA — escala Inter del admin (institutional · jerarquía con saltos)
// ─────────────────────────────────────────────────────────────────────────────

/// Escala tipográfica del Admin Web Panel sobre **Inter**. Saltos de tamaño y
/// peso con contraste (≥1.25) para jerarquía clara y "premium sobrio".
/// No afecta login ni docente: estos estilos solo se usan dentro del admin.
class AdminType {
  static TextStyle _i(
    double size,
    FontWeight weight, {
    Color color = AdminUi.textPrimary,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// Saludo / título de pantalla grande.
  static TextStyle get display =>
      _i(32, FontWeight.w700, color: AdminUi.textPrimary, letterSpacing: -0.6, height: 1.1);
  static TextStyle get displaySm =>
      _i(24, FontWeight.w700, letterSpacing: -0.4, height: 1.15);

  /// Título de sección dentro de una card.
  static TextStyle get sectionTitle =>
      _i(16, FontWeight.w700, letterSpacing: -0.2);
  static TextStyle get titleSm => _i(14, FontWeight.w700);

  /// Número grande de KPI.
  static TextStyle get kpiValue =>
      _i(26, FontWeight.w800, letterSpacing: -1, height: 1.0);

  /// Cuerpo y variantes.
  static TextStyle get body => _i(14, FontWeight.w400);
  static TextStyle get bodyStrong => _i(14, FontWeight.w600);
  static TextStyle get bodySm => _i(13, FontWeight.w400);
  static TextStyle get label =>
      _i(12, FontWeight.w600, color: AdminUi.textSecondary);
  static TextStyle get caption =>
      _i(11.5, FontWeight.w500, color: AdminUi.textSecondary);

  /// Overline de tablas / encabezados de columna.
  static TextStyle get overline => _i(
        10.5,
        FontWeight.w700,
        color: AdminUi.textSecondary,
        letterSpacing: 0.7,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI CARD — métrica compacta enterprise (presentacional, sin queries)
// ─────────────────────────────────────────────────────────────────────────────

/// Card de métrica admin reutilizable. No hace queries: recibe el valor ya
/// resuelto y banderas [loading] / [error]; la lógica de streams vive en cada
/// pantalla. Ícono sobrio en fill de baja saturación, valor, etiqueta y
/// contexto opcional.
///
/// - [live]   muestra un punto sutil de "datos en vivo" (Dashboard).
/// - [alert]  resalta con borde de acento suave + punto (p. ej. sesiones
///            abandonadas), sin saturar el color.
/// - [width]  fija el ancho para tiras horizontales; omítelo para que llene
///            la celda de un grid ([expand] = true).
class AdminKpiCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? subtitle;
  final bool loading;
  final bool error;
  final bool live;
  final bool alert;
  final bool expand;
  final double? width;

  const AdminKpiCard({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.subtitle,
    this.loading = false,
    this.error = false,
    this.live = false,
    this.alert = false,
    this.expand = false,
    this.width,
  });

  Widget _statusDot(Color c) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: c.withValues(alpha: 0.25), width: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = error ? AppDesignSystem.textDisabled : color;

    Widget trailing = const SizedBox.shrink();
    if (live) {
      trailing = Tooltip(
        message: 'Datos en vivo',
        child: _statusDot(
          error ? AppDesignSystem.textDisabled : AppDesignSystem.successColor,
        ),
      );
    } else if (alert) {
      trailing = _statusDot(color);
    }

    final valueBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          const AdminSkeletonBox(width: 52, height: 26)
        else
          Text(
            error ? 'N/D' : value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AdminUi.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AdminUi.textSecondary,
            ),
          ),
        ],
      ],
    );

    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminUi.surface,
        borderRadius: AppDesignSystem.borderRadiusLG,
        border: Border.all(
          color: alert ? color.withValues(alpha: 0.45) : AdminUi.border,
          width: alert ? 1.5 : 1,
        ),
        boxShadow: [AppDesignSystem.getShadowSM()],
      ),
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment:
            expand ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: AppDesignSystem.borderRadiusSM,
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              trailing,
            ],
          ),
          if (!expand) const SizedBox(height: 12),
          valueBlock,
        ],
      ),
    );
  }
}

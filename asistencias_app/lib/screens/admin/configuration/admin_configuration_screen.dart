import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/academic_period_service.dart';
import '../../../theme/app_design_system.dart';
import '../admin_shell.dart' show AdminRoutes;
import '../widgets/admin_ui.dart';

/// Configuración del Admin Web Panel.
///
/// Pantalla HONESTA: muestra parámetros reales (período académico activo,
/// reglas de seguridad por rol, estado del sistema) y marca como
/// "Informativo"/"Próximamente" lo que aún no tiene persistencia segura.
/// No crea colecciones, no escribe configuración, no toca tokens/Cloud
/// Functions ni acciones destructivas (p. ej. cerrar año/archivar aulas).
class AdminConfigurationScreen extends StatefulWidget {
  const AdminConfigurationScreen({super.key});

  @override
  State<AdminConfigurationScreen> createState() =>
      _AdminConfigurationScreenState();
}

class _AdminConfigurationScreenState extends State<AdminConfigurationScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final Future<Map<String, dynamic>?> _periodFuture;

  @override
  void initState() {
    super.initState();
    // Lectura segura (no destructiva) del período académico activo.
    _periodFuture = AcademicPeriodService.getActivePeriod();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    final pad = AdminUi.pagePadding(width);
    final twoCols = width >= 1000;

    final left = <Widget>[
      _institucionCard(),
      _asistenciaCard(),
      _sistemaCard(),
    ];
    final right = <Widget>[
      _notificacionesCard(),
      _seguridadCard(),
    ];

    return DefaultTextStyle.merge(
      style: AdminUi.fontBase,
      child: Container(
        color: AdminUi.surface0,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pad, pad, pad, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 16),
              _infoBanner(),
              const SizedBox(height: 20),
              if (twoCols)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _colStack(left)),
                    const SizedBox(width: 20),
                    Expanded(child: _colStack(right)),
                  ],
                )
              else
                _colStack([...left, ...right]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colStack(List<Widget> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          cards[i],
        ],
      ],
    );
  }

  Widget _header() {
    // Row > Expanded fuerza ancho completo, idéntico al patrón del resto de
    // pantallas admin. Sin esto, Column toma el ancho mínimo de su contenido
    // y en pantallas anchas el texto aparece visualmente centrado.
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configuración', style: AdminType.display),
              const SizedBox(height: 4),
              Text(
                'Parámetros generales del panel administrativo',
                style: AdminType.bodySm
                    .copyWith(color: AdminUi.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AdminUi.infoBg,
        borderRadius: AppDesignSystem.borderRadiusMD,
        border: Border.all(color: AdminUi.info.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AdminUi.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Algunos parámetros son informativos. La edición de configuración '
              'institucional global estará disponible en una próxima versión.',
              style: AdminType.bodySm.copyWith(color: AdminUi.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Institución ─────────────────────────────────────────────────────────

  Widget _institucionCard() {
    return _SettingsSection(
      icon: Icons.account_balance_rounded,
      title: 'Institución',
      children: [
        const _InfoRow(
          label: 'Nombre de la institución',
          value: 'Por definir',
          state: _State.soon,
        ),
        const _InfoRow(
          label: 'UGEL / jurisdicción',
          value: 'Por definir',
          state: _State.soon,
        ),
        FutureBuilder<Map<String, dynamic>?>(
          future: _periodFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _InfoRow(
                label: 'Año lectivo',
                value: 'Cargando…',
                state: _State.info,
              );
            }
            final p = snap.data;
            if (p == null) {
              return const _InfoRow(
                label: 'Año lectivo',
                value: 'Sin período activo',
                state: _State.soon,
              );
            }
            final year = (p['year'] ?? p['name'] ?? '').toString();
            return _InfoRow(
              label: 'Año lectivo',
              value: year.isEmpty ? 'Activo' : year,
              state: _State.configured,
            );
          },
        ),
        const _InfoRow(
          label: 'Zona horaria',
          value: 'America/Lima',
          state: _State.info,
        ),
      ],
    );
  }

  // ── Asistencia ──────────────────────────────────────────────────────────

  Widget _asistenciaCard() {
    return _SettingsSection(
      icon: Icons.fact_check_rounded,
      title: 'Asistencia',
      footnote:
          'La tolerancia de tardanza y los días hábiles se definen en el horario '
          'de cada aula.',
      action: _SectionAction(
        label: 'Ir a Aulas',
        onTap: () => Get.toNamed(AdminRoutes.aulas),
      ),
      children: const [
        _InfoRow(
          label: 'Tolerancia de tardanza',
          value: 'Según horario por aula',
          state: _State.byClassroom,
        ),
        _InfoRow(
          label: 'Días hábiles',
          value: 'Según horario por aula',
          state: _State.byClassroom,
        ),
        _InfoRow(
          label: 'Política de cierre de sesión',
          value: 'Manual del docente · alerta a las 4 h',
          state: _State.info,
        ),
        _InfoRow(
          label: 'Recordatorio de sesiones activas',
          value: 'Visible en Sesiones e Incidencias',
          state: _State.active,
        ),
      ],
    );
  }

  // ── Notificaciones ────────────────────────────────────────────────────────

  Widget _notificacionesCard() {
    return _SettingsSection(
      icon: Icons.notifications_active_outlined,
      title: 'Notificaciones',
      footnote:
          'No se gestionan tokens ni secretos desde aquí. La activación se hace '
          'por estudiante.',
      action: _SectionAction(
        label: 'Ir a Estudiantes',
        onTap: () => Get.toNamed(AdminRoutes.estudiantes),
      ),
      children: const [
        _InfoRow(
          label: 'Telegram (apoderados)',
          value: 'Enlace de activación desde Estudiantes',
          state: _State.active,
        ),
        _InfoRow(
          label: 'WhatsApp (enlace de activación)',
          value: 'Disponible desde Estudiantes',
          state: _State.active,
        ),
      ],
    );
  }

  // ── Seguridad ─────────────────────────────────────────────────────────────

  Widget _seguridadCard() {
    return _SettingsSection(
      icon: Icons.shield_outlined,
      title: 'Seguridad',
      children: const [
        _InfoRow(
          label: 'Acceso web',
          value: 'Reservado a administradores',
          state: _State.active,
        ),
        _InfoRow(
          label: 'Acceso móvil',
          value: 'Reservado a docentes',
          state: _State.active,
        ),
        _InfoRow(
          label: 'Bloqueo por rol',
          value: 'Validado desde Firestore (users/{uid}.role)',
          state: _State.active,
        ),
      ],
    );
  }

  // ── Sistema ───────────────────────────────────────────────────────────────

  Widget _sistemaCard() {
    return _SettingsSection(
      icon: Icons.dns_outlined,
      title: 'Sistema',
      children: const [
        _InfoRow(label: 'Versión', value: 'Beta', state: _State.info),
        _InfoRow(label: 'Entorno', value: 'Web Admin', state: _State.info),
        _InfoRow(
          label: 'Rutas web',
          value: '8 secciones activas',
          state: _State.active,
        ),
        _InfoRow(label: 'Plataforma', value: 'Flutter Web', state: _State.info),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado visual de cada parámetro
// ─────────────────────────────────────────────────────────────────────────────

enum _State { configured, active, byClassroom, info, soon }

extension _StateData on _State {
  String get label {
    switch (this) {
      case _State.configured:
        return 'Configurado';
      case _State.active:
        return 'Activo';
      case _State.byClassroom:
        return 'Por aula';
      case _State.info:
        return 'Informativo';
      case _State.soon:
        return 'Próximamente';
    }
  }

  Color get color {
    switch (this) {
      case _State.configured:
      case _State.active:
        return AdminUi.success;
      case _State.byClassroom:
        return AdminUi.info;
      case _State.info:
        return AdminUi.slate;
      case _State.soon:
        return AdminUi.warning;
    }
  }
}

class _StateChip extends StatelessWidget {
  final _State state;
  const _StateChip(this.state);

  @override
  Widget build(BuildContext context) {
    final c = state.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: AppDesignSystem.borderRadiusFull,
      ),
      child: Text(
        state.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fila de parámetro (label · valor · estado)
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final _State state;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AdminType.bodySm.copyWith(
                    color: AdminUi.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AdminType.bodyStrong,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _StateChip(state),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de sección
// ─────────────────────────────────────────────────────────────────────────────

class _SectionAction {
  final String label;
  final VoidCallback onTap;
  const _SectionAction({required this.label, required this.onTap});
}

class _SettingsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  final String? footnote;
  final _SectionAction? action;

  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.children,
    this.footnote,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminUi.surface,
        borderRadius: AppDesignSystem.borderRadiusLG,
        border: Border.all(color: AdminUi.border),
        boxShadow: AdminUi.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AdminUi.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: AdminUi.primary),
              ),
              const SizedBox(width: 12),
              Text(title, style: AdminType.sectionTitle),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: AdminUi.border),
            children[i],
          ],
          if (footnote != null) ...[
            const SizedBox(height: 12),
            Text(
              footnote!,
              style: AdminType.caption,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: AdminButton.secondary(
                label: action!.label,
                icon: Icons.arrow_forward_rounded,
                onPressed: action!.onTap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

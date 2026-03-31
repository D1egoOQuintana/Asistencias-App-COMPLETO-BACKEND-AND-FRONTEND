import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _brandBlue = Color(0xFF1976D2);
  static const Color _surface = Color(0xFFF8FAFB);
  static const Color _surfaceLow = Color(0xFFF2F4F5);
  static const Color _outline = Color(0xFF5F6470);
  static const Color _darkText = Color(0xFF0B1F3B);

  UserRole? _selectedRole;

  bool get _showRoleSelector => _selectedRole == null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _brandBlue.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: _brandBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Asistencias App',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _darkText,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 360),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.02, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: _showRoleSelector
                          ? _buildIdentitySelector(context)
                          : _buildRoleFormView(context),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentitySelector(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final titleSize = width < 360
        ? 34.0
        : width < 420
        ? 40.0
        : width < 900
        ? 48.0
        : 56.0;

    return Column(
      key: const ValueKey('selector'),
      children: [
        const SizedBox(height: 12),
        Text(
          'Bienvenido a',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            height: 1.0,
            letterSpacing: -1,
            color: _darkText,
          ),
        ),
        Text(
          'Asistencias App',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
            height: 1.0,
            letterSpacing: -1,
            color: _brandBlue,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Selecciona tu portal para continuar.',
            textAlign: TextAlign.center,
            style: GoogleFonts.workSans(
              color: _outline,
              fontSize: width < 420 ? 16 : 19,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 26),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 860;
            if (compact) {
              return Column(
                children: [
                  _IdentityCard(
                    title: 'Docente',
                    subtitle:
                        'Gestiona asistencias, estudiantes y progreso académico.',
                    icon: Icons.school_rounded,
                    isPrimary: false,
                    onTap: () => _goToForm(UserRole.docente),
                  ),
                  const SizedBox(height: 14),
                  _IdentityCard(
                    title: 'Administrador',
                    subtitle:
                        'Supervisa la operación institucional y reportes globales.',
                    icon: Icons.admin_panel_settings_rounded,
                    isPrimary: true,
                    onTap: () => _goToForm(UserRole.admin),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: _IdentityCard(
                    title: 'Docente',
                    subtitle:
                        'Gestiona asistencias, estudiantes y progreso académico.',
                    icon: Icons.school_rounded,
                    isPrimary: false,
                    onTap: () => _goToForm(UserRole.docente),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _IdentityCard(
                    title: 'Administrador',
                    subtitle:
                        'Supervisa la operación institucional y reportes globales.',
                    icon: Icons.admin_panel_settings_rounded,
                    isPrimary: true,
                    onTap: () => _goToForm(UserRole.admin),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Column(
          children: [
            Container(
              width: 1,
              height: 52,
              color: _brandBlue.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 8),
            Text(
              'Gestión educativa con precisión',
              style: GoogleFonts.workSans(
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: _darkText,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleFormView(BuildContext context) {
    final role = _selectedRole!;
    final title = role == UserRole.docente
        ? 'Ingreso de Docente'
        : 'Ingreso de Administrador';
    final subtitle = role == UserRole.docente
        ? 'Accede a tu panel profesional para gestionar tus aulas.'
        : 'Accede al panel institucional para administración global.';

    return Column(
      key: ValueKey('form-${role.value}'),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _backToSelector,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Volver a selección'),
            style: TextButton.styleFrom(
              foregroundColor: _brandBlue,
              textStyle: GoogleFonts.workSans(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _brandBlue.withValues(alpha: 0.16)),
          ),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: _brandBlue,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  role == UserRole.docente
                      ? Icons.menu_book_rounded
                      : Icons.verified_user_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: MediaQuery.of(context).size.width < 380 ? 30 : 38,
                  color: _darkText,
                  height: 1,
                  letterSpacing: -0.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.workSans(
                    color: _outline,
                    fontWeight: FontWeight.w500,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _ModernLoginForm(
                key: ValueKey('role-form-${role.value}'),
                role: role,
                brandBlue: _brandBlue,
                darkText: _darkText,
                surfaceLow: _surfaceLow,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _goToForm(UserRole role) {
    Provider.of<AuthProvider>(context, listen: false).clearError();
    setState(() {
      _selectedRole = role;
    });
  }

  void _backToSelector() {
    Provider.of<AuthProvider>(context, listen: false).clearError();
    setState(() {
      _selectedRole = null;
    });
  }
}

class _IdentityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _IdentityCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const brandBlue = Color(0xFF1976D2);
    const darkText = Color(0xFF0B1F3B);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isPrimary ? brandBlue : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isPrimary ? Colors.transparent : brandBlue.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? Colors.white.withValues(alpha: 0.16)
                      : const Color(0xFFE9F2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 42,
                  color: isPrimary ? Colors.white : brandBlue,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 32,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: isPrimary ? Colors.white : darkText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: GoogleFonts.workSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: isPrimary ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF5F6470),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isPrimary ? 'Ingreso seguro' : 'Acceder al portal',
                    style: GoogleFonts.workSans(
                      fontSize: 12,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: isPrimary ? Colors.white : brandBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: isPrimary ? Colors.white : brandBlue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formulario de login moderno y responsivo.
class _ModernLoginForm extends StatefulWidget {
  final UserRole role;
  final Color brandBlue;
  final Color darkText;
  final Color surfaceLow;

  const _ModernLoginForm({
    super.key,
    required this.role,
    required this.brandBlue,
    required this.darkText,
    required this.surfaceLow,
  });

  @override
  State<_ModernLoginForm> createState() => _ModernLoginFormState();
}

class _ModernLoginFormState extends State<_ModernLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      expectedRole: widget.role,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInputLabel('Correo electrónico'),
                const SizedBox(height: 8),
                _buildEmailField(),
                const SizedBox(height: 18),
                _buildInputLabel('Contraseña'),
                const SizedBox(height: 8),
                _buildPasswordField(),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Esta función estará disponible pronto.'),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: widget.brandBlue,
                    textStyle: GoogleFonts.workSans(fontWeight: FontWeight.w600),
                  ),
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 58,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: widget.brandBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: widget.brandBlue.withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Iniciar sesión',
                                style: GoogleFonts.manrope(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded),
                            ],
                          ),
                  ),
                ),
                if (authProvider.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  _buildErrorMessage(authProvider.errorMessage!),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: GoogleFonts.workSans(
          fontSize: 16,
          color: widget.darkText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocusNode),
      style: GoogleFonts.workSans(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: _baseDecoration(
        hint: 'nombre@institucion.edu',
        icon: Icons.mail_outline_rounded,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Ingresa tu correo electrónico.';
        }
        if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
          return 'Ingresa un correo válido.';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      focusNode: _passwordFocusNode,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleLogin(),
      style: GoogleFonts.workSans(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: _baseDecoration(
        hint: '••••••••••',
        icon: Icons.lock_outline_rounded,
        suffix: IconButton(
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: const Color(0xFF5F6470),
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Ingresa tu contraseña.';
        }
        if (value.length < 6) {
          return 'La contraseña debe tener al menos 6 caracteres.';
        }
        return null;
      },
    );
  }

  InputDecoration _baseDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.workSans(color: const Color(0xFF8B92A0)),
      filled: true,
      fillColor: widget.surfaceLow,
      prefixIcon: Icon(icon, color: widget.brandBlue),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: widget.brandBlue.withValues(alpha: 0.12), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: widget.brandBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1.6),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 2),
      ),
      errorStyle: GoogleFonts.workSans(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFBA1A1A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.workSans(
                color: const Color(0xFF8E1A1A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_themes.dart';
import '../../widgets/animated_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  int _selectedSegment = 0; // 0 = Docente, 1 = Admin
  UserRole get _currentRole =>
      _selectedSegment == 0 ? UserRole.docente : UserRole.admin;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();

    // Animación suave para el formulario
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    // (no heavy per-frame animation needed here)

    _scaleController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final themeForRole = AppThemes.getThemeForRole(_currentRole);

    return Theme(
      data: themeForRole,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        // OPTIMIZACIÓN: Usar animatedSize en lugar de reconstruir todo
        body: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Stack(
            children: [
              // Fondo animado con burbujas. Pausar animaciones cuando el
              // teclado esté visible para evitar jank al enfocarse en campos.
              AnimatedBackground(
                isDocenteMode: _selectedSegment == 0,
                pauseAnimations: MediaQuery.of(context).viewInsets.bottom > 0,
              ),

              // Contenido del login
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 20.0 : 32.0,
                      vertical: 24.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo/Icono
                        _buildLogo(isSmallScreen),

                        SizedBox(height: isSmallScreen ? 32 : 48),

                        // iOS 13 Segment Control
                        _buildIOS13SegmentControl(),

                        SizedBox(height: isSmallScreen ? 24 : 32),

                        // Formulario de login con animación
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (widget, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position:
                                    Tween<Offset>(
                                      begin: const Offset(0.1, 0),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOut,
                                      ),
                                    ),
                                child: widget,
                              ),
                            );
                          },
                          child: _ModernLoginForm(
                            key: ValueKey(_selectedSegment),
                            role: _currentRole,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isSmallScreen) {
    return Hero(
      tag: 'app_logo',
      child: Container(
        width: isSmallScreen ? 80 : 100,
        height: isSmallScreen ? 80 : 100,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Icon(
          Icons.school,
          size: isSmallScreen ? 40 : 50,
          color: AppThemes.getThemeForRole(_currentRole).primaryColor,
        ),
      ),
    );
  }

  Widget _buildIOS13SegmentControl() {
    final options = ['Docente', 'Admin'];
    final icons = [Icons.person, Icons.admin_panel_settings];

    return Container(
      height: 44,
      width: 320,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E2E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Paddle animado (fondo blanco que se mueve)
          AnimatedAlign(
            alignment: _selectedSegment == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Botones de selección (MEJORADO: cubre toda el área)
          Row(
            children: List.generate(options.length, (index) {
              final isSelected = index == _selectedSegment;
              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _selectedSegment = index),
                    borderRadius: BorderRadius.circular(10),
                    splashColor: Colors.white.withValues(alpha: 0.2),
                    highlightColor: Colors.white.withValues(alpha: 0.1),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: isSelected ? 15 : 14,
                          color: isSelected
                              ? AppThemes.getThemeForRole(
                                  _currentRole,
                                ).primaryColor
                              : Colors.black54,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icons[index],
                              size: isSelected ? 18 : 16,
                              color: isSelected
                                  ? AppThemes.getThemeForRole(
                                      _currentRole,
                                    ).primaryColor
                                  : Colors.black54,
                            ),
                            const SizedBox(width: 6),
                            Text(options[index]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Formulario de login moderno y responsivo optimizado
class _ModernLoginForm extends StatefulWidget {
  final UserRole role;

  const _ModernLoginForm({super.key, required this.role});

  @override
  State<_ModernLoginForm> createState() => _ModernLoginFormState();
}

class _ModernLoginFormState extends State<_ModernLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // No añadimos listeners que hagan setState en focus para evitar
    // reconstrucciones costosas cuando el teclado aparece.
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
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
      builder: (context, authProvider, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 400;
            final cardPadding = isSmallScreen ? 20.0 : 32.0;
            final verticalSpacing = isSmallScreen ? 16.0 : 20.0;

            return Container(
              constraints: BoxConstraints(
                maxWidth: isSmallScreen ? constraints.maxWidth : 420,
              ),
              child: Card(
                elevation: 12,
                shadowColor: Colors.black.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: EdgeInsets.all(cardPadding),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Título elegante con gradiente
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: AppThemes.getGradientForRole(widget.role),
                          ).createShader(bounds),
                          child: Text(
                            'Bienvenido',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 26 : 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Inicia sesión en tu cuenta',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.grey[600],
                                fontSize: isSmallScreen ? 14 : 15,
                              ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: isSmallScreen ? 28 : 36),

                        // Campo Email moderno
                        _buildEmailField(isSmallScreen),

                        SizedBox(height: verticalSpacing),

                        // Campo Contraseña moderno
                        _buildPasswordField(isSmallScreen),

                        SizedBox(height: isSmallScreen ? 28 : 36),

                        // Botón de login moderno
                        _buildLoginButton(authProvider, isSmallScreen),

                        // Mensaje de error elegante
                        if (authProvider.errorMessage != null) ...[
                          SizedBox(height: verticalSpacing),
                          _buildErrorMessage(authProvider.errorMessage!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmailField(bool isSmallScreen) {
    return TextFormField(
      controller: _emailController,
      focusNode: _emailFocusNode,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: const TextStyle(fontSize: 15),
      onFieldSubmitted: (_) {
        FocusScope.of(context).requestFocus(_passwordFocusNode);
      },
      decoration: InputDecoration(
        labelText: 'Correo electrónico',
        hintText: 'ejemplo@escuela.com',
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppThemes.getThemeForRole(
              widget.role,
            ).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.email_outlined,
            color: AppThemes.getThemeForRole(widget.role).primaryColor,
            size: 20,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppThemes.getThemeForRole(widget.role).primaryColor,
            width: 2.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16 : 20,
          vertical: isSmallScreen ? 16 : 18,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor ingresa tu correo';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Ingresa un correo válido';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(bool isSmallScreen) {
    return TextFormField(
      controller: _passwordController,
      focusNode: _passwordFocusNode,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      style: const TextStyle(fontSize: 15),
      onFieldSubmitted: (_) => _handleLogin(),
      decoration: InputDecoration(
        labelText: 'Contraseña',
        hintText: '••••••••',
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppThemes.getThemeForRole(
              widget.role,
            ).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.lock_outline,
            color: AppThemes.getThemeForRole(widget.role).primaryColor,
            size: 20,
          ),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: Colors.grey[600],
            size: 22,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppThemes.getThemeForRole(widget.role).primaryColor,
            width: 2.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16 : 20,
          vertical: isSmallScreen ? 16 : 18,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor ingresa tu contraseña';
        }
        if (value.length < 6) {
          return 'La contraseña debe tener al menos 6 caracteres';
        }
        return null;
      },
    );
  }

  Widget _buildLoginButton(AuthProvider authProvider, bool isSmallScreen) {
    return Container(
      height: isSmallScreen ? 52 : 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: authProvider.isLoading
              ? [Colors.grey[400]!, Colors.grey[400]!]
              : AppThemes.getGradientForRole(widget.role),
        ),
        boxShadow: authProvider.isLoading
            ? null
            : [
                BoxShadow(
                  color: AppThemes.getThemeForRole(
                    widget.role,
                  ).primaryColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: authProvider.isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: authProvider.isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Iniciar Sesión',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade600,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

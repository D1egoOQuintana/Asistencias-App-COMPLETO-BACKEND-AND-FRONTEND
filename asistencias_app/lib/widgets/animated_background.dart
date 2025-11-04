import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;

/// Fondo animado con burbujas flotantes y efecto blur
/// Soporta animaciones Rive (.riv) o Flutter nativo como fallback
/// Compatible con modos claro (docente) y oscuro (admin)
class AnimatedBackground extends StatefulWidget {
  final bool isDocenteMode;

  /// When true, animations are paused and a static gradient is shown.
  /// Useful when the keyboard is open to avoid jank.
  final bool pauseAnimations;

  const AnimatedBackground({
    super.key,
    required this.isDocenteMode,
    this.pauseAnimations = false,
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> {
  bool _useRive = false;

  @override
  void initState() {
    super.initState();
    // Intentar cargar Rive en segundo plano (sin bloquear) sólo si
    // no pedimos pausar las animaciones (por ejemplo cuando el teclado está abierto)
    if (!widget.pauseAnimations) {
      _checkRiveAvailability();
    }
  }

  Future<void> _checkRiveAvailability() async {
    try {
      // Intenta cargar el archivo Rive en segundo plano
      final assetPath = widget.isDocenteMode
          ? 'assets/animations/bubbles_cool.riv'
          : 'assets/animations/bubbles_warm.riv';

      await rootBundle.load(assetPath);
      if (mounted) {
        setState(() {
          _useRive = true;
        });
      }
    } catch (e) {
      // Si no existe, mantiene Flutter nativo (ya configurado)
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si pedimos pausar animaciones (ej. teclado abierto), devolver sólo
    // el gradiente estático para minimizar trabajo de render.
    if (widget.pauseAnimations) {
      return _buildGradientBackground();
    }

    // Normalmente construye la animación de fondo (Rive o Flutter nativo)
    return _useRive ? _buildRiveBackground() : _buildFlutterNativeBackground();
  }

  Widget _buildRiveBackground() {
    final assetPath = widget.isDocenteMode
        ? 'assets/animations/bubbles_cool.riv'
        : 'assets/animations/bubbles_warm.riv';

    return Stack(
      children: [
        // Gradiente de fondo
        _buildGradientBackground(),

        // Animación Rive
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          child: rive.RiveAnimation.asset(
            assetPath,
            key: ValueKey(widget.isDocenteMode),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),

        // Overlay sutil
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.05),
                Colors.black.withValues(alpha: 0.15),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlutterNativeBackground() {
    return _FlutterNativeBubbles(isDocenteMode: widget.isDocenteMode);
  }

  Widget _buildGradientBackground() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isDocenteMode
              ? [
                  const Color(0xFFF5F7FA), // Blanco grisáceo claro
                  const Color(0xFFFFFFFF), // Blanco puro
                  const Color(0xFFF0F4F8), // Blanco azulado muy suave
                ]
              : [
                  const Color(0xFF37474F), // Gris azulado oscuro
                  const Color(0xFF455A64), // Gris medio
                  const Color(0xFF546E7A), // Gris plomo
                ],
        ),
      ),
    );
  }
}

/// Implementación nativa con Flutter (sin dependencias de Rive)
class _FlutterNativeBubbles extends StatefulWidget {
  final bool isDocenteMode;

  const _FlutterNativeBubbles({required this.isDocenteMode});

  @override
  State<_FlutterNativeBubbles> createState() => _FlutterNativeBubblesState();
}

class _FlutterNativeBubblesState extends State<_FlutterNativeBubbles>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<BubbleData> _bubbles;

  @override
  void initState() {
    super.initState();
    _initializeBubbles();
  }

  void _initializeBubbles() {
    final random = Random();
    // Solo 3 burbujas grandes para máxima performance
    _bubbles = List.generate(3, (index) {
      return BubbleData(
        initialX: random.nextDouble(),
        initialY: random.nextDouble(),
        size: 100 + random.nextDouble() * 120, // 100-220 (muy grandes)
        speed: 0.5 + random.nextDouble() * 0.3, // 0.5-0.8
        directionX: random.nextBool() ? 1 : -1,
        directionY: random.nextBool() ? 1 : -1,
        colorIndex: index % 3,
      );
    });

    _controllers = List.generate(3, (index) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds:
              (12000 + random.nextInt(4000)), // 12-16 segundos (muy lentas)
        ),
      );
      controller.repeat(reverse: true);
      return controller;
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isDocenteMode
              ? [
                  const Color(0xFFF5F7FA), // Blanco grisáceo claro
                  const Color(0xFFFFFFFF), // Blanco puro
                  const Color(0xFFF0F4F8), // Blanco azulado muy suave
                ]
              : [
                  const Color(0xFF37474F), // Gris azulado oscuro
                  const Color(0xFF455A64), // Gris medio
                  const Color(0xFF546E7A), // Gris plomo
                ],
        ),
      ),
      child: Stack(
        children: [
          // Burbujas animadas con optimización
          ...List.generate(_bubbles.length, (index) {
            return AnimatedBuilder(
              animation: _controllers[index],
              builder: (context, child) {
                final progress = _controllers[index].value;
                final bubble = _bubbles[index];

                // Movimiento oscilante con rebote suave
                final x =
                    bubble.initialX +
                    (sin(progress * 2 * pi) * 0.3 * bubble.directionX);
                final y =
                    bubble.initialY +
                    (cos(progress * 2 * pi) * 0.2 * bubble.directionY);

                // Variación de tamaño (pulso sutil)
                final scaleFactor = 0.85 + (sin(progress * pi) * 0.15);

                return Positioned(
                  left: x * size.width - bubble.size / 2,
                  top: y * size.height - bubble.size / 2,
                  child: RepaintBoundary(
                    child: _buildBubble(
                      bubble.size * scaleFactor,
                      bubble.colorIndex,
                    ),
                  ),
                );
              },
            );
          }),

          // Overlay blur sutil
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: widget.isDocenteMode
                    ? [
                        Colors.white.withValues(alpha: 0.3),
                        Colors.white.withValues(alpha: 0.1),
                      ]
                    : [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.2),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(double size, int colorIndex) {
    final colors = widget.isDocenteMode
        ? [
            [
              const Color(0xFFE3F2FD),
              const Color(0xFFBBDEFB),
            ], // Azul muy claro
            [
              const Color(0xFFF3E5F5),
              const Color(0xFFE1BEE7),
            ], // Violeta muy claro
            [
              const Color(0xFFE0F7FA),
              const Color(0xFFB2EBF2),
            ], // Celeste muy claro
            [
              const Color(0xFFFCE4EC),
              const Color(0xFFF8BBD0),
            ], // Rosado muy claro
          ]
        : [
            [const Color(0xFF607D8B), const Color(0xFF78909C)], // Gris azulado
            [const Color(0xFF546E7A), const Color(0xFF78909C)], // Gris medio
            [const Color(0xFF455A64), const Color(0xFF607D8B)], // Gris oscuro
            [const Color(0xFF37474F), const Color(0xFF546E7A)], // Gris profundo
          ];

    final gradientColors = colors[colorIndex % colors.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            gradientColors[0].withValues(
              alpha: widget.isDocenteMode ? 0.6 : 0.4,
            ),
            gradientColors[1].withValues(
              alpha: widget.isDocenteMode ? 0.3 : 0.1,
            ),
            gradientColors[1].withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(
              alpha: widget.isDocenteMode ? 0.4 : 0.3,
            ),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}

class BubbleData {
  final double initialX;
  final double initialY;
  final double size;
  final double speed;
  final int directionX;
  final int directionY;
  final int colorIndex;

  BubbleData({
    required this.initialX,
    required this.initialY,
    required this.size,
    required this.speed,
    required this.directionX,
    required this.directionY,
    required this.colorIndex,
  });
}

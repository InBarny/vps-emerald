// lib/ui/widgets/animated_connect_button.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Анимированная кнопка подключения VPN в стиле Heavy Emerald
/// Большая круглая кнопка с градиентом и glow-эффектом
class AnimatedConnectButton extends StatefulWidget {
  const AnimatedConnectButton({
    super.key,
    required this.isConnected,
    required this.isConnecting,
    required this.onPressed,
    this.size = 160,
  });

  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onPressed;
  final double size;

  @override
  State<AnimatedConnectButton> createState() => _AnimatedConnectButtonState();
}

class _AnimatedConnectButtonState extends State<AnimatedConnectButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(AnimatedConnectButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isConnecting && !oldWidget.isConnecting) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isConnecting && oldWidget.isConnecting) {
      _pulseController.stop();
      _pulseController.reset();
    }
    if (widget.isConnected && !oldWidget.isConnected) {
      _rippleController.repeat();
    } else if (!widget.isConnected && oldWidget.isConnected) {
      _rippleController.stop();
      _rippleController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _rippleController]),
      builder: (context, child) {
        final scale = widget.isConnecting ? _pulseAnimation.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: widget.onPressed,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ripple ring
                  if (widget.isConnected)
                    Container(
                      width: widget.size + 8,
                      height: widget.size + 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.emerald.withOpacity(
                            0.3 * (1 - _rippleController.value),
                          ),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emerald.withOpacity(
                              0.1 * (1 - _rippleController.value),
                            ),
                            blurRadius: 20,
                            spreadRadius: 4 * _rippleController.value,
                          ),
                        ],
                      ),
                    ),
                  // Main button
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.emerald,
                          AppColors.emeraldDim,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emerald.withOpacity(0.3),
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: AppColors.emerald.withOpacity(0.1),
                          blurRadius: 80,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.isConnecting
                          ? SizedBox(
                              width: widget.size * 0.35,
                              height: widget.size * 0.35,
                              child: const CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.bg,
                                ),
                              ),
                            )
                          : _PlayPauseIcon(
                              isConnected: widget.isConnected,
                              size: widget.size * 0.35,
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

/// Иконка play (треугольник) или pause (две полоски)
class _PlayPauseIcon extends StatelessWidget {
  const _PlayPauseIcon({required this.isConnected, required this.size});

  final bool isConnected;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (isConnected) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size * 0.25,
            height: size * 0.8,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: size * 0.15),
          Container(
            width: size * 0.25,
            height: size * 0.8,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      );
    }
    return CustomPaint(
      size: Size(size * 0.9, size * 0.9),
      painter: _TrianglePainter(color: AppColors.bg),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.15)
      ..lineTo(size.width * 0.9, size.height * 0.5)
      ..lineTo(size.width * 0.2, size.height * 0.85)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Пульсирующий индикатор статуса
class PulsingStatusIndicator extends StatefulWidget {
  const PulsingStatusIndicator({
    super.key,
    required this.color,
    this.size = 10,
  });

  final Color color;
  final double size;

  @override
  State<PulsingStatusIndicator> createState() => _PulsingStatusIndicatorState();
}

class _PulsingStatusIndicatorState extends State<PulsingStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(0.5 + _controller.value * 0.5),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.4),
                blurRadius: 8 + _controller.value * 4,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Индикатор с иконкой и текстом статуса
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulsingStatusIndicator(color: color, size: 10),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

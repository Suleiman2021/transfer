import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

class AppShellBackground extends StatelessWidget {
  const AppShellBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppTheme.shellGradient),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _GridPatternPainter()),
          ),
        ),
        Positioned(
          top: -140,
          left: -100,
          child: _GlowBlob(
            size: 320,
            color: AppTheme.brandGold.withValues(alpha: 0.18),
          ),
        ),
        Positioned(
          right: -80,
          top: 80,
          child: _GlowBlob(
            size: 240,
            color: AppTheme.brandTeal.withValues(alpha: 0.16),
          ),
        ),
        Positioned(
          bottom: -110,
          right: -60,
          child: _GlowBlob(
            size: 260,
            color: AppTheme.brandCoral.withValues(alpha: 0.14),
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.brandInk.withValues(alpha: 0.045)
      ..strokeWidth = 1;

    const spacing = 34.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.22),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _MeshPatternPainter()),
          ),
        ),
        Positioned(
          top: -120,
          left: -80,
          child: _GlowBlob(
            size: 300,
            color: AppTheme.brandTeal.withValues(alpha: 0.20),
          ),
        ),
        Positioned(
          right: -70,
          top: 60,
          child: _GlowBlob(
            size: 250,
            color: AppTheme.brandGold.withValues(alpha: 0.20),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -50,
          child: _GlowBlob(
            size: 230,
            color: AppTheme.brandCoral.withValues(alpha: 0.17),
          ),
        ),
        Positioned(
          bottom: -90,
          left: -40,
          child: _GlowBlob(
            size: 210,
            color: AppTheme.brandSky.withValues(alpha: 0.28),
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
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
            radius: 0.78,
          ),
        ),
      ),
    );
  }
}

class _MeshPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final verticalPaint = Paint()
      ..color = AppTheme.brandInk.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    final diagonalPaint = Paint()
      ..color = AppTheme.brandTeal.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    final dotPaint = Paint()..color = AppTheme.brandTeal.withValues(alpha: 0.09);

    const spacing = 38.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), verticalPaint);
    }

    const diagonalSpacing = 90.0;
    for (double y = -size.height; y <= size.height; y += diagonalSpacing) {
      canvas.drawLine(
        Offset(0, y + size.height),
        Offset(size.width, y),
        diagonalPaint,
      );
    }

    for (double x = spacing; x <= size.width; x += spacing * 2) {
      for (double y = spacing; y <= size.height; y += spacing * 2) {
        canvas.drawCircle(Offset(x, y), 1.35, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

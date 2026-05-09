import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppTheme.shellGradient),
      child: Stack(
        children: [
          const PositionedDirectional(
            top: -80,
            end: -64,
            child: _SoftCircle(size: 220, color: Color(0xFFFFC266)),
          ),
          const PositionedDirectional(
            bottom: -90,
            start: -70,
            child: _SoftCircle(size: 240, color: Color(0xFFFFD8B8)),
          ),
          child,
        ],
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.color});

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
          color: color.withValues(alpha: 0.34),
        ),
      ),
    );
  }
}

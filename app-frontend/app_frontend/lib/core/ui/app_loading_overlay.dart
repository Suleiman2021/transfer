import 'app_activity_bus.dart';
import '../theme/app_theme.dart';
import 'dart:ui';
import 'package:flutter/material.dart';

class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppActivityBus.pending,
      builder: (context, count, _) {
        final visible = count > 0;

        return Stack(
          children: [
            child,
            IgnorePointer(
              ignoring: !visible,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: visible ? 1 : 0,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 1.8, sigmaY: 1.8),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.brandTeal.withValues(alpha: 0.10),
                          AppTheme.brandInk.withValues(alpha: 0.12),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

import 'app_activity_bus.dart';
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
                child: Container(
                  color: Colors.black.withValues(alpha: 0.14),
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
          ],
        );
      },
    );
  }
}

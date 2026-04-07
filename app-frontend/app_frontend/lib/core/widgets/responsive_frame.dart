import 'package:flutter/material.dart';

class ResponsiveFrame extends StatelessWidget {
  const ResponsiveFrame({super.key, required this.child, this.maxWidth = 1120});

  final Widget child;
  final double maxWidth;

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) return const EdgeInsets.all(20);
    if (width >= 900) return const EdgeInsets.all(18);
    if (width >= 600) return const EdgeInsets.all(16);
    return const EdgeInsets.all(12);
  }

  static double sectionGap(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) return 14;
    if (width >= 900) return 12;
    return 10;
  }

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 980;

  @override
  Widget build(BuildContext context) {
    final padding = pagePadding(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

import '../theme/app_theme.dart';
import 'app_shell_background.dart';
import 'responsive_frame.dart';
import 'reveal_on_mount.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DashboardSectionEntry extends StatelessWidget {
  const DashboardSectionEntry({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.brandInk.withValues(alpha: 0.08)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, AppTheme.panel.withValues(alpha: 0.65)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.brandSky.withValues(alpha: 0.56),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: AppTheme.brandInk),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.brandCoral.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios_rounded, size: 13),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardSectionScreen extends StatelessWidget {
  const DashboardSectionScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.revisionListenable,
    required this.childBuilder,
    this.subtitle,
    this.onRefresh,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final ValueListenable<int> revisionListenable;
  final WidgetBuilder childBuilder;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final body = ValueListenableBuilder<int>(
      valueListenable: revisionListenable,
      builder: (context, value, child) {
        return ListView(
          children: [
            ResponsiveFrame(
              child: Column(
                children: [
                  RevealOnMount(
                    delay: const Duration(milliseconds: 50),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'رجوع',
                        ),
                        const SizedBox(width: 2),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.brandSky.withValues(alpha: 0.58),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, size: 19),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  RevealOnMount(
                    delay: const Duration(milliseconds: 110),
                    child: childBuilder(context),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

    return Scaffold(
      body: AppShellBackground(
        child: SafeArea(
          child: onRefresh == null
              ? body
              : RefreshIndicator(onRefresh: onRefresh!, child: body),
        ),
      ),
    );
  }
}

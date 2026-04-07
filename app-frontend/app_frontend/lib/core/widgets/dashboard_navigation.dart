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
      borderRadius: AppTheme.tileRadius,
      onTap: onTap,
      child: Ink(
        decoration: AppTheme.tileDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.brandSky.withValues(alpha: 0.96),
                      AppTheme.brandGold.withValues(alpha: 0.32),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: AppTheme.brandTeal.withValues(alpha: 0.16),
                  ),
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
                        fontSize: 11.8,
                        color: AppTheme.textMuted,
                        height: 1.32,
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
                    color: AppTheme.brandCoral.withValues(alpha: 0.16),
                    border: Border.all(
                      color: AppTheme.brandCoral.withValues(alpha: 0.28),
                    ),
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
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: AppTheme.brandTeal.withValues(alpha: 0.9),
              ),
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
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.brandSky.withValues(alpha: 0.96),
                                AppTheme.brandGold.withValues(alpha: 0.30),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.brandTeal.withValues(alpha: 0.16),
                            ),
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
                                    color: AppTheme.textMuted,
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

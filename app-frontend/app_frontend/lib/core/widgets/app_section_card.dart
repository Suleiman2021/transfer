import '../theme/app_theme.dart';
import '../theme/app_theme_tokens.dart';
import 'package:flutter/material.dart';

class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppThemeTokens.space4),
      decoration: AppTheme.sectionCardDecoration(radius: AppThemeTokens.radiusLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.brandTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppThemeTokens.radiusMd),
                  ),
                  child: Icon(icon, color: AppTheme.brandTeal, size: 20),
                ),
                const SizedBox(width: AppThemeTokens.space3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppThemeTokens.space4),
          child,
        ],
      ),
    );
  }
}

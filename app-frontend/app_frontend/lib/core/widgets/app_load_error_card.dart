import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

enum AppLoadErrorKind { network, timeout, unauthorized, server, unknown }

class AppLoadErrorMeta {
  const AppLoadErrorMeta({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final AppLoadErrorKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

AppLoadErrorMeta detectLoadErrorMeta(String message) {
  final text = message.toLowerCase();

  if (text.contains('401') ||
      text.contains('403') ||
      text.contains('صلاحيات') ||
      text.contains('غير مصرح')) {
    return const AppLoadErrorMeta(
      kind: AppLoadErrorKind.unauthorized,
      title: 'مشكلة صلاحيات',
      subtitle: 'بيانات الدخول أو الصلاحيات الحالية لا تسمح بتحميل البيانات.',
      icon: Icons.lock_outline_rounded,
      color: Color(0xFF7C3AED),
    );
  }

  if (text.contains('timeout') ||
      text.contains('مهلة') ||
      text.contains('timed out')) {
    return const AppLoadErrorMeta(
      kind: AppLoadErrorKind.timeout,
      title: 'انتهت مهلة الاتصال',
      subtitle: 'الخادم لم يستجب في الوقت المطلوب، أعد المحاولة.',
      icon: Icons.timer_off_rounded,
      color: AppTheme.noticeWarning,
    );
  }

  if (text.contains('failed host lookup') ||
      text.contains('socket') ||
      text.contains('connection') ||
      text.contains('تعذر الوصول') ||
      text.contains('شبكة') ||
      text.contains('internet')) {
    return const AppLoadErrorMeta(
      kind: AppLoadErrorKind.network,
      title: 'انقطاع في الشبكة',
      subtitle: 'تعذر الوصول إلى الخادم. تحقق من اتصال الإنترنت.',
      icon: Icons.wifi_off_rounded,
      color: AppTheme.noticeError,
    );
  }

  if (text.contains('500') ||
      text.contains('502') ||
      text.contains('503') ||
      text.contains('504') ||
      text.contains('server')) {
    return const AppLoadErrorMeta(
      kind: AppLoadErrorKind.server,
      title: 'مشكلة في الخادم',
      subtitle: 'الخادم يواجه مشكلة مؤقتة، حاول بعد قليل.',
      icon: Icons.dns_rounded,
      color: Color(0xFFB45309),
    );
  }

  return const AppLoadErrorMeta(
    kind: AppLoadErrorKind.unknown,
    title: 'تعذر تحميل البيانات',
    subtitle: 'حدث خطأ غير متوقع أثناء التحميل.',
    icon: Icons.error_outline_rounded,
    color: AppTheme.noticeError,
  );
}

class AppLoadErrorCard extends StatelessWidget {
  const AppLoadErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
    this.title,
    this.subtitle,
  });

  final String? title;
  final String? subtitle;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final meta = detectLoadErrorMeta(message);
    final resolvedTitle = title ?? meta.title;
    final resolvedSubtitle = subtitle ?? meta.subtitle;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(meta.icon, size: 18, color: meta.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resolvedTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        resolvedSubtitle,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.brandSky.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: meta.color.withValues(alpha: 0.28)),
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: meta.color.withValues(alpha: 0.92),
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

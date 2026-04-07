import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum AppNoticeType { success, error, info, warning }

class AppNotifier {
  AppNotifier._();
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void success(BuildContext context, String message) {
    show(context, message, type: AppNoticeType.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message, type: AppNoticeType.error);
  }

  static void info(BuildContext context, String message) {
    show(context, message, type: AppNoticeType.info);
  }

  static void warning(BuildContext context, String message) {
    show(context, message, type: AppNoticeType.warning);
  }

  static void show(
    BuildContext context,
    String message, {
    AppNoticeType type = AppNoticeType.info,
  }) {
    final messenger =
        messengerKey.currentState ?? ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final (icon, color) = switch (type) {
      AppNoticeType.success => (
        Icons.check_circle_rounded,
        AppTheme.noticeSuccess,
      ),
      AppNoticeType.error => (Icons.error_rounded, AppTheme.noticeError),
      AppNoticeType.warning => (
        Icons.warning_amber_rounded,
        AppTheme.noticeWarning,
      ),
      AppNoticeType.info => (Icons.info_rounded, AppTheme.brandTeal),
    };
    final duration = switch (type) {
      AppNoticeType.success => const Duration(milliseconds: 2500),
      AppNoticeType.error => const Duration(milliseconds: 4200),
      AppNoticeType.warning => const Duration(milliseconds: 3400),
      AppNoticeType.info => const Duration(milliseconds: 3000),
    };
    final media = MediaQuery.maybeOf(context);
    final keyboardInset = media?.viewInsets.bottom ?? 0;
    final safeBottom = media?.padding.bottom ?? 0;
    final marginBottom = keyboardInset > 0
        ? keyboardInset + 10
        : safeBottom + 10;
    final snackTheme = Theme.of(context).snackBarTheme;
    final behavior = snackTheme.behavior ?? SnackBarBehavior.floating;
    final backgroundColor = snackTheme.backgroundColor ?? Colors.white;
    final elevation = snackTheme.elevation ?? 0;
    final textStyle =
        snackTheme.contentTextStyle ??
        const TextStyle(
          color: AppTheme.textDark,
          fontWeight: FontWeight.w700,
          height: 1.35,
        );

    void present() {
      if (!messenger.mounted) return;
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          duration: duration,
          dismissDirection: DismissDirection.horizontal,
          behavior: behavior,
          backgroundColor: backgroundColor,
          elevation: elevation,
          margin: EdgeInsets.fromLTRB(12, 0, 12, marginBottom),
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.snackRadius,
            side: BorderSide(color: color.withValues(alpha: 0.35)),
          ),
          content: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: textStyle)),
            ],
          ),
        ),
      );
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle) {
      present();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => present());
  }
}

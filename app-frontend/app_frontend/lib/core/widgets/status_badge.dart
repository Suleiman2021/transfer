import '../entities/app_models.dart';
import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  factory StatusBadge.transfer(String state) {
    return StatusBadge(
      text: transferStateLabelAr(state),
      color: stateColor(state),
    );
  }

  static Color stateColor(String state) {
    return switch (state) {
      'completed' => AppTheme.noticeSuccess,
      'pending_review' => AppTheme.noticeWarning,
      'rejected' || 'failed' => AppTheme.noticeError,
      _ => AppTheme.brandCoral,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

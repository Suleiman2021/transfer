import '../../../../core/entities/app_models.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class AdminHeroHeader extends StatelessWidget {
  const AdminHeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.userLine,
    required this.onLogout,
  });

  final String title;
  final String subtitle;
  final String userLine;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white30),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandInk.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.06),
                    ],
                    stops: const [0.0, 0.58, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -18,
            right: -18,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final identity = Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.30),
                          Colors.white.withValues(alpha: 0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.26),
                      ),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            height: 1.14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.34,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          userLine,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final logout = OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                ),
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('\u062e\u0631\u0648\u062c'),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identity,
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: logout),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 12),
                  logout,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class AdminMetricCard extends StatelessWidget {
  const AdminMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    this.icon = Icons.pie_chart_rounded,
    this.accent = AppTheme.brandTeal,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 114,
      child: Card(
        child: Container(
          decoration: AppTheme.metricCardDecoration(accent: accent),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 14, color: accent),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 10.2,
                    color: AppTheme.textSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminSectionCard extends StatelessWidget {
  const AdminSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: Container(
        decoration: AppTheme.sectionCardDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.8,
                  color: AppTheme.textMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class AdminTransferTile extends StatelessWidget {
  const AdminTransferTile({
    super.key,
    required this.transfer,
    this.onApprove,
    this.onReject,
    this.onTap,
    this.busy = false,
  });

  final TransferModel transfer;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final showActions = onApprove != null || onReject != null;
    final stateColor = switch (transfer.state) {
      'completed' => const Color(0xFF0F766E),
      'approved' => const Color(0xFF0F766E),
      'pending_review' => const Color(0xFFE76F51),
      'rejected' => const Color(0xFFB91C1C),
      _ => AppTheme.brandInk,
    };

    final tileBody = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.brandTeal.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandInk.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 4,
            decoration: BoxDecoration(
              color: stateColor.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  transferTypeLabelAr(transfer.operationType),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              AdminStateBadge(text: transferStateLabelAr(transfer.state)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            transferSummaryAr(transfer),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '\u0627\u0644\u0645\u0628\u0644\u063a: ${moneyText(transfer.amountValue)} - \u0639\u0645\u0648\u0644\u0629 \u0627\u0644\u062e\u0632\u0646\u0629: ${moneyText(transfer.commissionValue)} - \u0631\u0628\u062d \u0627\u0644\u0645\u0646\u0641\u0630: ${moneyText(transfer.agentProfitValue)}',
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          if (transfer.cashoutProfitValue > 0) ...[
            const SizedBox(height: 4),
            Text(
              '\u0631\u0628\u062d \u0635\u0631\u0641 \u0627\u0644\u0639\u0645\u064a\u0644: ${moneyText(transfer.cashoutProfitValue)}',
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
          if ((transfer.customerName ?? '').isNotEmpty ||
              (transfer.customerPhone ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0639\u0645\u064a\u0644: ${transfer.customerName ?? '-'} - ${transfer.customerPhone ?? '-'}',
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
          if ((transfer.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '\u0645\u0644\u0627\u062d\u0638\u0629: ${transfer.note}',
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: busy ? null : onApprove,
                  child: const Text('\u0627\u0639\u062a\u0645\u0627\u062f'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : onReject,
                  child: const Text('\u0631\u0641\u0636'),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return tileBody;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: tileBody,
      ),
    );
  }
}

class AdminStateBadge extends StatelessWidget {
  const AdminStateBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.brandSky.withValues(alpha: 0.72),
        border: Border.all(color: AppTheme.brandTeal.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

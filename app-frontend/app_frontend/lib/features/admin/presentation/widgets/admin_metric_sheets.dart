import '../../../../core/entities/app_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import 'package:flutter/material.dart';

const _kCurrencyColors = <String, Color>{
  'SYP': AppTheme.brandTeal,
  'USD': Color(0xFF2E7D32),
  'EUR': Color(0xFF1565C0),
  'USDT': Color(0xFF00695C),
};

// ─── تفاصيل المستخدمين ────────────────────────────────────────────────────────

void showUsersDetailSheet(BuildContext context, List<AppUser> users) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _UsersSheet(users: users),
  );
}

class _UsersSheet extends StatelessWidget {
  const _UsersSheet({required this.users});
  final List<AppUser> users;

  @override
  Widget build(BuildContext context) {
    final roles = [
      UserRole.superAdmin,
      UserRole.admin,
      UserRole.accredited,
      UserRole.agent,
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetTitle(
              title: 'تفاصيل المستخدمين',
              badge: '${users.length} مستخدم',
            ),
            const SizedBox(height: 12),
            ...roles.map((role) {
              final group = users.where((u) => u.role == role).toList();
              if (group.isEmpty) return const SizedBox.shrink();
              final active = group.where((u) => u.isActive).length;
              return _GroupCard(
                icon: Icons.person_rounded,
                color: _roleColor(role),
                title: roleLabelAr(role),
                subtitle: '$active فعّال / ${group.length - active} موقوف',
                value: group.length.toString(),
                children: group
                    .map(
                      (u) => _RowItem(
                        label: '${u.fullName} (@${u.username})',
                        value: u.isActive ? 'فعّال' : 'موقوف',
                        valueColor: u.isActive ? Colors.green : Colors.red,
                      ),
                    )
                    .toList(),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Colors.purple;
      case UserRole.admin:
        return Colors.indigo;
      case UserRole.accredited:
        return AppTheme.brandTeal;
      case UserRole.agent:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

// ─── رصيد الشبكة ─────────────────────────────────────────────────────────────

void showNetworkBalanceSheet(
  BuildContext context,
  List<CashboxModel> cashboxes,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _NetworkBalanceSheet(cashboxes: cashboxes),
  );
}

class _NetworkBalanceSheet extends StatelessWidget {
  const _NetworkBalanceSheet({required this.cashboxes});
  final List<CashboxModel> cashboxes;

  @override
  Widget build(BuildContext context) {
    final nonTreasury = cashboxes.where((b) => !b.isTreasury).toList();
    final treasury = cashboxes.where((b) => b.isTreasury).firstOrNull;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetTitle(
                title: 'رصيد الشبكة',
                badge: '${cashboxes.length} صندوق',
              ),
              const SizedBox(height: 4),
              _ActualCurrencyTotals(cashboxes: cashboxes),
              const SizedBox(height: 12),
              if (treasury != null) ...[
                _SectionLabel('الخزنة الرئيسية'),
                _CashboxBalanceCard(box: treasury, color: Colors.purple),
                const SizedBox(height: 10),
              ],
              _SectionLabel('صناديق المعتمدين'),
              ...nonTreasury
                  .where((b) => b.isAccredited)
                  .map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CashboxBalanceCard(
                          box: b, color: AppTheme.brandTeal),
                    ),
                  ),
              _SectionLabel('صناديق الوكلاء'),
              ...nonTreasury
                  .where((b) => b.isAgent)
                  .map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child:
                          _CashboxBalanceCard(box: b, color: Colors.orange),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── تفاصيل العمولات ─────────────────────────────────────────────────────────

void showCommissionDetailSheet(
  BuildContext context,
  List<TransferModel> transfers,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CommissionSheet(transfers: transfers),
  );
}

class _CommissionSheet extends StatelessWidget {
  const _CommissionSheet({required this.transfers});
  final List<TransferModel> transfers;

  static void _add(
    Map<String, double> map,
    double amount,
    String sourceCurrency,
  ) {
    if (amount <= 0) return;
    map[sourceCurrency] = (map[sourceCurrency] ?? 0) + amount;
  }

  @override
  Widget build(BuildContext context) {
    final completed = transfers.where((t) => t.state == 'completed').toList();

    final commByCurrency = <String, double>{};
    final agentProfitByCurrency = <String, double>{};
    final byTypeByCurrency = <String, Map<String, double>>{};

    for (final t in completed) {
      _add(commByCurrency, t.commissionValue, t.sourceCurrency);
      _add(agentProfitByCurrency, t.agentProfitValue, t.sourceCurrency);

      if (t.commissionValue > 0) {
        final typeMap = byTypeByCurrency.putIfAbsent(t.operationType, () => {});
        _add(typeMap, t.commissionValue, t.sourceCurrency);
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetTitle(
                title: 'إيراد العمولات',
                badge: '${completed.length} عملية مكتملة',
              ),
              const SizedBox(height: 12),

              // ── إجمالي العمولات ──
              if (commByCurrency.isNotEmpty) ...[
                _CurrencyGroupCard(
                  label: 'إجمالي العمولات',
                  icon: Icons.paid_rounded,
                  amounts: commByCurrency,
                  color: Colors.amber,
                ),
                const SizedBox(height: 10),
              ],

              // ── ربح الوكلاء ──
              if (agentProfitByCurrency.isNotEmpty) ...[
                _CurrencyGroupCard(
                  label: 'ربح الوكلاء',
                  icon: Icons.store_rounded,
                  amounts: agentProfitByCurrency,
                  color: Colors.orange,
                ),
                const SizedBox(height: 10),
              ],

              // ── توزيع حسب نوع العملية ──
              if (byTypeByCurrency.isNotEmpty) ...[
                const Divider(height: 16),
                const Text(
                  'توزيع حسب نوع العملية',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                ...byTypeByCurrency.entries
                    .toList()
                    .sorted((a, b) {
                      final sa = a.value.values.fold(0.0, (s, v) => s + v);
                      final sb = b.value.values.fold(0.0, (s, v) => s + v);
                      return sb.compareTo(sa);
                    })
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TypeRow(
                          label: transferTypeLabelAr(e.key),
                          amounts: e.value,
                        ),
                      ),
                    ),
              ],

              if (commByCurrency.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'لا توجد عمولات في العمليات الحديثة.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── تفاصيل الصناديق ─────────────────────────────────────────────────────────

void showCashboxesDetailSheet(
  BuildContext context,
  List<CashboxModel> cashboxes,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CashboxesSheet(cashboxes: cashboxes),
  );
}

class _CashboxesSheet extends StatelessWidget {
  const _CashboxesSheet({required this.cashboxes});
  final List<CashboxModel> cashboxes;

  @override
  Widget build(BuildContext context) {
    final treasury = cashboxes.where((b) => b.isTreasury).toList();
    final accredited = cashboxes.where((b) => b.isAccredited).toList();
    final agents = cashboxes.where((b) => b.isAgent).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetTitle(
                title: 'الصناديق',
                badge: '${cashboxes.length} صندوق',
              ),
              const SizedBox(height: 14),

              if (treasury.isNotEmpty) ...[
                _SectionLabel('الخزنة الرئيسية'),
                ...treasury.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CashboxBalanceCard(box: b, color: Colors.purple),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (accredited.isNotEmpty) ...[
                _SectionLabelWithTotals(
                  label: 'صناديق المعتمدين (${accredited.length})',
                  cashboxes: accredited,
                ),
                const SizedBox(height: 8),
                ...accredited.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CashboxBalanceCard(
                        box: b, color: AppTheme.brandTeal),
                  ),
                ),
                const SizedBox(height: 6),
              ],

              if (agents.isNotEmpty) ...[
                _SectionLabelWithTotals(
                  label: 'صناديق الوكلاء (${agents.length})',
                  cashboxes: agents,
                ),
                const SizedBox(height: 8),
                ...agents.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child:
                        _CashboxBalanceCard(box: b, color: Colors.orange),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets مساعدة مشتركة ────────────────────────────────────────────────────

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title, required this.badge});
  final String title;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.brandTeal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              color: AppTheme.brandTeal,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: AppTheme.textMuted,
        ),
      ),
    );
  }
}

/// تسمية قسم مع إجمالي عملاته.
class _SectionLabelWithTotals extends StatelessWidget {
  const _SectionLabelWithTotals({
    required this.label,
    required this.cashboxes,
  });
  final String label;
  final List<CashboxModel> cashboxes;

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final b in cashboxes) {
      for (final e in b.currencyBalances.entries) {
        if (e.value != 0) totals[e.key] = (totals[e.key] ?? 0) + e.value;
      }
    }
    final entries = totals.entries.where((e) => e.value > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppTheme.textMuted,
          ),
        ),
        if (entries.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: entries
                .map((e) => _CurrencyBadge(
                      e.key,
                      e.value,
                      _kCurrencyColors[e.key] ?? AppTheme.brandTeal,
                    ))
                .toList(),
          ),
          const SizedBox(height: 2),
        ],
      ],
    );
  }
}

/// يعرض إجمالي العملات لمجموعة صناديق.
class _ActualCurrencyTotals extends StatelessWidget {
  const _ActualCurrencyTotals({required this.cashboxes});
  final List<CashboxModel> cashboxes;

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final b in cashboxes) {
      for (final e in b.currencyBalances.entries) {
        if (e.value != 0) totals[e.key] = (totals[e.key] ?? 0) + e.value;
      }
    }
    if (totals.isEmpty) return const SizedBox.shrink();

    final entries = totals.entries.where((e) => e.value > 0).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppTheme.brandTeal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.brandTeal.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: entries
            .map((e) => Expanded(
                  child: _CurrencyColumn(
                    currency: e.key,
                    amount: e.value,
                    color: _kCurrencyColors[e.key] ?? AppTheme.brandTeal,
                  ),
                ))
            .toList(),
      ),
    );
  }
}

/// بطاقة رصيد صندوق واحد.
class _CashboxBalanceCard extends StatelessWidget {
  const _CashboxBalanceCard({required this.box, required this.color});
  final CashboxModel box;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cb = box.currencyBalances;
    final entries = cb.isNotEmpty
        ? cb.entries.where((e) => e.value != 0).toList()
        : [MapEntry('SYP', box.balanceValue)];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      box.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${box.managerName ?? '-'} — ${box.city}، ${box.country}',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!box.isActive)
                const Chip(
                  label: Text('موقوف', style: TextStyle(fontSize: 11)),
                  backgroundColor: Color(0xFFFFEEEE),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: entries
                .where((e) => e.value != 0)
                .map(
                  (e) => _CurrencyBadge(
                    e.key,
                    e.value,
                    _kCurrencyColors[e.key] ?? color,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// بطاقة مجموعة عملات مع أيقونة وعنوان.
class _CurrencyGroupCard extends StatelessWidget {
  const _CurrencyGroupCard({
    required this.label,
    required this.icon,
    required this.amounts,
    required this.color,
  });
  final String label;
  final IconData icon;
  final Map<String, double> amounts;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final entries = amounts.entries.where((e) => e.value > 0).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: entries
                .map((e) => Expanded(
                      child: _CurrencyColumn(
                        currency: e.key,
                        amount: e.value,
                        color: _kCurrencyColors[e.key] ?? color,
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// صف توزيع حسب نوع العملية.
class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.label, required this.amounts});
  final String label;
  final Map<String, double> amounts;

  @override
  Widget build(BuildContext context) {
    final entries = amounts.entries.where((e) => e.value > 0).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.brandTeal.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.brandTeal.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Wrap(
            spacing: 8,
            children: entries
                .map((e) => _CurrencyBadge(
                      e.key,
                      e.value,
                      _kCurrencyColors[e.key] ?? AppTheme.brandTeal,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// عمود عملة: label فوق المبلغ.
class _CurrencyColumn extends StatelessWidget {
  const _CurrencyColumn({
    required this.currency,
    required this.amount,
    required this.color,
  });
  final String currency;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          currencyLabel(currency),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatCurrencyAmount(amount, currency),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _CurrencyBadge extends StatelessWidget {
  const _CurrencyBadge(this.currency, this.amount, this.color);
  final String currency;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        formatCurrencyAmount(amount, currency),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _GroupCard extends StatefulWidget {
  const _GroupCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.children,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String? subtitle;
  final List<Widget> children;

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.children.isNotEmpty
                ? () => setState(() => _expanded = !_expanded)
                : null,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    widget.value,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: widget.color,
                    ),
                  ),
                  if (widget.children.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: widget.color,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_expanded && widget.children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  const Divider(height: 8),
                  ...widget.children,
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  const _RowItem({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

extension _Sorted<T> on List<T> {
  List<T> sorted(int Function(T, T) compare) => [...this]..sort(compare);
}

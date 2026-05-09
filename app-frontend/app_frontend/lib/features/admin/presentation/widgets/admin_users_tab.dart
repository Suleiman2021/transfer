import '../../../../core/entities/app_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_section_card.dart';
import 'package:flutter/material.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({
    super.key,
    required this.users,
    required this.onOpenReport,
    required this.onToggleActive,
    required this.onOpenQr,
  });

  final List<AppUser> users;
  final ValueChanged<AppUser> onOpenReport;
  final ValueChanged<AppUser> onToggleActive;
  final ValueChanged<AppUser> onOpenQr;

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final _search = TextEditingController();
  UserRole? _role;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AppUser> get _filtered {
    final query = _search.text.trim().toLowerCase();
    return widget.users.where((user) {
      if (_role != null && user.role != _role) return false;
      if (query.isEmpty) return true;
      return '${user.fullName} ${user.username}'.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final users = _filtered;
    return Column(
      children: [
        AppSectionCard(
          title: 'بحث وفلترة',
          icon: Icons.filter_alt_rounded,
          child: Column(
            children: [
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  labelText: 'بحث باسم المستخدم أو الاسم الكامل',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('الكل'),
                    selected: _role == null,
                    onSelected: (_) => setState(() => _role = null),
                  ),
                  for (final role in [
                    UserRole.admin,
                    UserRole.agent,
                    UserRole.accredited,
                  ])
                    ChoiceChip(
                      label: Text(roleLabelAr(role)),
                      selected: _role == role,
                      onSelected: (_) => setState(() => _role = role),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppSectionCard(
          title: 'قائمة المستخدمين',
          icon: Icons.people_alt_rounded,
          child: users.isEmpty
              ? const AppEmptyState(
                  title: 'لا توجد نتائج',
                  subtitle: 'جرّب تغيير البحث أو الفلترة.',
                )
              : Column(
                  children: users
                      .map(
                        (user) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _UserCard(
                            user: user,
                            onOpenReport: () => widget.onOpenReport(user),
                            onToggle: () => widget.onToggleActive(user),
                            onQr: () => widget.onOpenQr(user),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onOpenReport,
    required this.onToggle,
    required this.onQr,
  });

  final AppUser user;
  final VoidCallback onOpenReport;
  final VoidCallback onToggle;
  final VoidCallback onQr;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.tileDecoration().copyWith(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                child: Text(user.fullName.isEmpty ? '-' : user.fullName[0]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text('@${user.username} - ${roleLabelAr(user.role)}'),
                  ],
                ),
              ),
              Chip(label: Text(user.isActive ? 'فعال' : 'موقوف')),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenReport,
                icon: const Icon(Icons.badge_rounded),
                label: const Text('تفاصيل'),
              ),
              OutlinedButton.icon(
                onPressed: onQr,
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('QR'),
              ),
              OutlinedButton.icon(
                onPressed: user.role == UserRole.admin ? null : onToggle,
                icon: Icon(
                  user.isActive
                      ? Icons.person_off_rounded
                      : Icons.verified_rounded,
                ),
                label: Text(user.isActive ? 'إيقاف' : 'تفعيل'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

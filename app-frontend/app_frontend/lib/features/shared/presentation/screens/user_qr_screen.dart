import '../../../../core/entities/app_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class UserQrScreen extends StatelessWidget {
  const UserQrScreen({
    super.key,
    required this.fullName,
    required this.username,
    required this.role,
    required this.city,
    required this.country,
    required this.userCode,
  });

  factory UserQrScreen.fromSession(AuthSession session) {
    return UserQrScreen(
      fullName: session.fullName,
      username: session.username,
      role: roleLabelAr(session.role),
      city: session.city,
      country: session.country,
      userCode: session.userId,
    );
  }

  factory UserQrScreen.fromUser(AppUser user) {
    return UserQrScreen(
      fullName: user.fullName,
      username: user.username,
      role: roleLabelAr(user.role),
      city: user.city,
      country: user.country,
      userCode: user.id,
    );
  }

  final String fullName;
  final String username;
  final String role;
  final String city;
  final String country;
  final String userCode;

  @override
  Widget build(BuildContext context) {
    final payload = 'radical-transfer:user:$userCode';
    return Scaffold(
      appBar: AppBar(title: const Text('رمز المستخدم')),
      body: AppBackground(
        child: ListView(
          children: [
            ResponsivePage(
              maxWidth: 520,
              child: AppSectionCard(
                title: 'باركود ثابت',
                subtitle: 'استخدمه للتعرف السريع على المستخدم لاحقًا',
                icon: Icons.qr_code_2_rounded,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.glassLine),
                      ),
                      child: QrImageView(data: payload, size: 230),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      fullName,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@$username - $role - $city, $country',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Clipboard.setData(
                              ClipboardData(text: userCode),
                            ),
                            icon: const Icon(Icons.copy_rounded),
                            label: const Text('نسخ الكود'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                Clipboard.setData(ClipboardData(text: payload)),
                            icon: const Icon(Icons.qr_code_rounded),
                            label: const Text('نسخ QR'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

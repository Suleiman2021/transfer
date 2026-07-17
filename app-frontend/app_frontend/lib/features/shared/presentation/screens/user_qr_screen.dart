import 'dart:io';
import 'dart:ui' as ui;

import '../../../../core/entities/app_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/app_notifier.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

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

  String get _payload => 'radical-transfer:user:$userCode';

  Future<void> _shareQr(BuildContext context) async {
    try {
      const padding = 80.0;
      const labelHeight = 80.0;
      const qrSize = 740.0;
      const imgWidth = qrSize + padding * 2;
      const imgHeight = qrSize + padding * 2 + labelHeight;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // White background
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, imgWidth, imgHeight),
        Paint()..color = Colors.white,
      );

      // QR code centred with equal padding on all four sides
      final painter = QrPainter(
        data: _payload,
        version: QrVersions.auto,
        gapless: true,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      );
      canvas.save();
      canvas.translate(padding, padding);
      painter.paint(canvas, const Size(qrSize, qrSize));
      canvas.restore();

      // Name label centred below the QR
      final labelTop = padding + qrSize + 18.0;
      final paragraphStyle = ui.ParagraphStyle(
        textAlign: TextAlign.center,
        maxLines: 2,
      );
      final textStyle = ui.TextStyle(
        color: const Color(0xFF111111),
        fontSize: 32,
        fontWeight: ui.FontWeight.w700,
      );
      final pb = ui.ParagraphBuilder(paragraphStyle)
        ..pushStyle(textStyle)
        ..addText('$fullName\n@$username');
      final paragraph = pb.build()
        ..layout(ui.ParagraphConstraints(width: imgWidth - padding * 2));
      canvas.drawParagraph(paragraph, Offset(padding, labelTop));

      final picture = recorder.endRecording();
      final image = await picture.toImage(imgWidth.toInt(), imgHeight.toInt());
      final imageData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (imageData == null) throw StateError('QR image generation failed');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/radical-user-$username-qr.png');
      await file.writeAsBytes(imageData.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          text: '$fullName\n@$username\n$userCode',
          files: [XFile(file.path)],
        ),
      );
    } catch (_) {
      if (context.mounted) {
        AppNotifier.error(context, 'تعذر مشاركة صورة QR.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      child: QrImageView(data: _payload, size: 230),
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
                            onPressed: () => _shareQr(context),
                            icon: const Icon(Icons.share_rounded),
                            label: const Text('مشاركة QR'),
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

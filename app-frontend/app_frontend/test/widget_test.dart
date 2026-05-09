import 'package:app_frontend/app.dart';
import 'package:app_frontend/core/entities/app_models.dart';
import 'package:app_frontend/features/auth/logic/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoSessionAuthController extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
}

void main() {
  testWidgets('Login screen appears when no session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_NoSessionAuthController.new),
        ],
        child: const CashboxTransferApp(),
      ),
    );
    await tester.pump();

    expect(find.text('اسم المستخدم'), findsOneWidget);
  });
}

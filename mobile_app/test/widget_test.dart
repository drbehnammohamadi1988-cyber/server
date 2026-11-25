import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_ai/app.dart';
import 'package:orbi_ai/core/config/app_config.dart';
import 'package:orbi_ai/core/network/gateway_client.dart';
import 'package:orbi_ai/core/security/secure_storage_service.dart';
import 'package:orbi_ai/core/theme/app_theme_mode.dart';
import 'package:orbi_ai/core/theme/theme_controller.dart';
import 'package:orbi_ai/features/gateway/data/gateway_repository.dart';
import 'package:orbi_ai/features/gateway/domain/gateway_models.dart';
import 'package:orbi_ai/features/gateway/presentation/gateway_providers.dart';
import 'package:orbi_ai/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStorage extends SecureStorageService {
  String? _key;

  @override
  Future<String?> readGatewayApiKey() async => _key;

  @override
  Future<void> writeGatewayApiKey(String? apiKey) async {
    _key = apiKey;
  }
}

class _FakeGatewayRepository extends GatewayRepository {
  _FakeGatewayRepository()
      : super(client: GatewayHttpClient(secureStorage: _FakeSecureStorage()));

  @override
  Future<List<GatewayModel>> fetchModels(String baseUrl, {cancelToken}) async {
    return const [
      GatewayModel(id: 'gpt-4o-mini', isFast: true, supportsVision: true),
      GatewayModel(id: 'claude-3-haiku-20240307', isFast: true, isCoding: true),
    ];
  }
}

void main() {
  testWidgets('Renders RTL Persian ChatScreen with starter chips and floating composer',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          gatewayRepositoryProvider.overrideWithValue(_FakeGatewayRepository()),
        ],
        child: const OrbiApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify RTL directionality
    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);

    // Verify floating composer hint & starter chips
    expect(find.text('هرچی میخوای بپرس...'), findsOneWidget);
    expect(find.text('حل مسئله'), findsOneWidget);
    expect(find.text('تولید محتوا'), findsOneWidget);
    expect(find.text('ساخت فایل و سند'), findsOneWidget);

    // Verify dynamic model name synced from fake gateway repo
    expect(find.text('gpt-4o-mini'), findsOneWidget);

    // Tapping starter chip populates composer text
    await tester.tap(find.text('برنامه‌نویسی'));
    await tester.pump();
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, contains('کد تمیز'));

    // Switching theme live via Riverpod updates theme preset cleanly
    final element = tester.element(find.byType(OrbiApp));
    final container = ProviderScope.containerOf(element);
    await container
        .read(themeSettingsProvider.notifier)
        .setPreset(AppThemePreset.softCeramic);
    await tester.pump();
    expect(
      container.read(themeSettingsProvider).preset,
      AppThemePreset.softCeramic,
    );
  });

  testWidgets('SettingsScreen hides Gateway connection settings cleanly',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      // Simulate an upgraded install that previously stored an emulator URL
      'orbi_gateway_base_url': 'http://10.0.2.2:8080',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          gatewayRepositoryProvider.overrideWithValue(_FakeGatewayRepository()),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    expect(
      container.read(gatewayConfigProvider).baseUrl,
      AppConfig.defaultGatewayBaseUrl,
    );

    expect(find.text('انتخاب تم و هویت بصری زنده'), findsOneWidget);
    expect(find.text('تنظیمات پیشرفته هوش مصنوعی و پشتیبان'), findsOneWidget);
    expect(find.text('اتصال به هسته سرور Gateway'), findsNothing);
    expect(find.text('آدرس Base URL سرور Gateway'), findsNothing);
    expect(find.text('تست اتصال و سنجش پینگ'), findsNothing);
  });
}

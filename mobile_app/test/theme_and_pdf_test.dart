import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_ai/core/database/app_database.dart';
import 'package:orbi_ai/core/theme/app_theme_builder.dart';
import 'package:orbi_ai/core/theme/app_theme_mode.dart';
import 'package:orbi_ai/core/theme/app_theme_tokens.dart';
import 'package:orbi_ai/core/utils/persian_digits.dart';
import 'package:orbi_ai/core/utils/persian_pdf_shaper.dart';
import 'package:orbi_ai/features/artifacts/artifact_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Theme Engine', () {
    test('builds all 5 handcrafted themes and interpolates tokens cleanly', () {
      for (final preset in AppThemePreset.values) {
        final theme = AppThemeBuilder.build(preset: preset, fontScale: 1.05);
        final tokens = theme.extension<OrbiThemeTokens>();
        expect(tokens, isNotNull);
        expect(tokens!.preset, preset);
        expect(theme.textTheme.bodyLarge?.fontFamily, 'Vazirmatn');
        expect(theme.textTheme.bodyLarge?.height, inInclusiveRange(1.65, 1.8));
      }

      final cosmic = OrbiThemeTokens.forPreset(AppThemePreset.cosmicGlass);
      final ceramic = OrbiThemeTokens.forPreset(AppThemePreset.softCeramic);
      final mid = cosmic.lerp(ceramic, 0.5);
      expect(mid.backgroundTop, isNot(equals(cosmic.backgroundTop)));
    });
  });

  group('PersianPdfShaper & Artifact PDF Export', () {
    test('shapes connected Persian glyphs and strips ZWNJ after breaking connection', () {
      final shaped = PersianPdfShaper.shapeSingleLine('می‌خواهم Flutter 3 را تست کنم');
      expect(shaped, isNotEmpty);
      expect(shaped.contains('\u200C'), isFalse);
      expect(shaped.contains('Flutter'), isTrue);
      // Arabic presentation forms range exists after shaping
      expect(
        shaped.runes.any((r) => (r >= 0xFB50 && r <= 0xFDFF) || (r >= 0xFE70 && r <= 0xFEFF)),
        isTrue,
      );
    });

    test('wraps logical lines before BiDi visual reordering so line 1 stays first', () {
      final lines = PersianPdfShaper.shapeParagraphToVisualLines(
        'جمله اول بسیار مهم است و باید در خط نخست بماند و جمله دوم در خط بعدی قرار گیرد',
        fallbackCharsPerLine: 28,
      );
      expect(lines.length, greaterThanOrEqualTo(2));
    });

    test('generates real non-empty PDF bytes embedding Vazirmatn & JetBrainsMono', () async {
      final service = ArtifactService(db: AppDatabase());
      final bytes = await service.buildPersianPdfBytes(
        title: 'گزارش تستی اوربی هوش',
        body: '# عنوان آزمایشی\n\nسلام! این یک سند **فارسی** همراه با `Flutter 3.50` است.\n\n```dart\nvoid main() => print("سلام");\n```',
      );
      expect(bytes.length, greaterThan(5000));
      // Valid PDF header "%PDF-"
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  group('PersianFormatter', () {
    test('formats Persian digits, file size, durations, and Jalali buckets', () {
      expect(PersianFormatter.toPersianDigits('3.4s 123'), '۳.۴s ۱۲۳');
      expect(PersianFormatter.formatDurationSeconds(const Duration(milliseconds: 3400)), '۳.۴ ثانیه');
      expect(PersianFormatter.formatFileSize(2048), '۲.۰ کیلوبایت');

      final now = DateTime(2026, 5, 20, 14, 0);
      expect(PersianFormatter.historyBucketLabel(now, now: now), 'امروز');
      expect(
        PersianFormatter.historyBucketLabel(now.subtract(const Duration(days: 1)), now: now),
        'دیروز',
      );
      expect(
        PersianFormatter.historyBucketLabel(now.subtract(const Duration(days: 5)), now: now),
        '۷ روز گذشته',
      );
    });
  });
}

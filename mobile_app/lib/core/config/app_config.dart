/// Compile-time and runtime configuration for Orbi AI.
class AppConfig {
  const AppConfig._();

  static const String appNameFa = 'اوربی هوش';
  static const String appNameEn = 'Orbi AI';
  static const String appTaglineFa =
      'دستیار هوشمند پارسی متصل به مدل‌های زنده Duck.ai';

  /// Base URL injected at build time via `--dart-define=GATEWAY_BASE_URL=...`.
  static const String _definedGatewayBaseUrl = String.fromEnvironment(
    'GATEWAY_BASE_URL',
    defaultValue: '',
  );

  /// Built-in default backend relay URL so the app connects silently in the
  /// background with zero manual user configuration.
  static String get defaultGatewayBaseUrl {
    final trimmed = _definedGatewayBaseUrl.trim();
    if (trimmed.isNotEmpty) {
      return normalizeBaseUrl(trimmed);
    }
    return 'https://park-analyses-durable-analyses.trycloudflare.com';
  }

  /// Normalizes a gateway base URL by removing trailing slashes and an optional
  /// trailing `/v1` suffix so endpoint paths (`/v1/models`, `/v1/chat/completions`)
  /// compose predictably.
  static String normalizeBaseUrl(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.endsWith('/v1')) {
      value = value.substring(0, value.length - 3);
    }
    return value;
  }

  static const String defaultSystemPrompt =
      'تو اوربی هوش، یک دستیار هوش مصنوعی دقیق، خوش‌برخورد و حرفه‌ای به زبان فارسی هستی. '
      'پاسخ‌هایت را شفاف، ساختاریافته و با نیم‌فاصلهٔ استاندارد فارسی بنویس. '
      'در صورت نیاز به کد، جدول یا فرمول ریاضی، از Markdown و LaTeX استاندارد استفاده کن.';
}

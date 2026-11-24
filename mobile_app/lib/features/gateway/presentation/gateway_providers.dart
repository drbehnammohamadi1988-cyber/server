import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/gateway_client.dart';
import '../../../core/network/gateway_error.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../data/gateway_repository.dart';
import '../domain/gateway_models.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final gatewayHttpClientProvider = Provider<GatewayHttpClient>((ref) {
  return GatewayHttpClient(
    secureStorage: ref.watch(secureStorageProvider),
  );
});

final gatewayRepositoryProvider = Provider<GatewayRepository>((ref) {
  return GatewayRepository(
    client: ref.watch(gatewayHttpClientProvider),
  );
});

@immutable
class GatewayConfigState {
  const GatewayConfigState({
    required this.baseUrl,
    required this.hasApiKey,
    required this.systemPrompt,
    required this.temperature,
    required this.maxTokens,
    required this.multimodalVision,
    this.selectedModelId,
    this.models = const [],
    this.isSyncingModels = false,
    this.modelErrorFa,
    this.lastHealth,
  });

  final String baseUrl;
  final bool hasApiKey;
  final String systemPrompt;
  final double temperature;
  final int maxTokens;
  final bool multimodalVision;
  final String? selectedModelId;
  final List<GatewayModel> models;
  final bool isSyncingModels;
  final String? modelErrorFa;
  final HealthCheckResult? lastHealth;

  GatewayModel? get selectedModel {
    if (models.isEmpty) return null;
    if (selectedModelId != null) {
      for (final m in models) {
        if (m.id == selectedModelId) return m;
      }
    }
    return models.first;
  }

  GatewayConfigState copyWith({
    String? baseUrl,
    bool? hasApiKey,
    String? systemPrompt,
    double? temperature,
    int? maxTokens,
    bool? multimodalVision,
    String? selectedModelId,
    List<GatewayModel>? models,
    bool? isSyncingModels,
    String? modelErrorFa,
    bool clearModelError = false,
    HealthCheckResult? lastHealth,
  }) {
    return GatewayConfigState(
      baseUrl: baseUrl ?? this.baseUrl,
      hasApiKey: hasApiKey ?? this.hasApiKey,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      multimodalVision: multimodalVision ?? this.multimodalVision,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      models: models ?? this.models,
      isSyncingModels: isSyncingModels ?? this.isSyncingModels,
      modelErrorFa:
          clearModelError ? null : (modelErrorFa ?? this.modelErrorFa),
      lastHealth: lastHealth ?? this.lastHealth,
    );
  }
}

class GatewayConfigNotifier extends Notifier<GatewayConfigState> {
  static const _kBaseUrl = 'orbi_gateway_base_url';
  static const _kSelectedModel = 'orbi_selected_model_id';
  static const _kSystemPrompt = 'orbi_system_prompt';
  static const _kTemperature = 'orbi_temperature';
  static const _kMaxTokens = 'orbi_max_tokens';
  static const _kMultimodal = 'orbi_multimodal_vision';

  @override
  GatewayConfigState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final storedUrl = prefs.getString(_kBaseUrl);
    final baseUrl = (storedUrl != null && storedUrl.trim().isNotEmpty)
        ? AppConfig.normalizeBaseUrl(storedUrl)
        : AppConfig.defaultGatewayBaseUrl;

    Future.microtask(_bootstrap);

    return GatewayConfigState(
      baseUrl: baseUrl,
      hasApiKey: false,
      systemPrompt: prefs.getString(_kSystemPrompt) ?? AppConfig.defaultSystemPrompt,
      temperature: (prefs.getDouble(_kTemperature) ?? 0.7).clamp(0.0, 2.0),
      maxTokens: prefs.getInt(_kMaxTokens) ?? 2048,
      multimodalVision: prefs.getBool(_kMultimodal) ?? false,
      selectedModelId: prefs.getString(_kSelectedModel),
    );
  }

  Future<void> _bootstrap() async {
    final apiKey = await ref.read(secureStorageProvider).readGatewayApiKey();
    state = state.copyWith(hasApiKey: apiKey != null && apiKey.isNotEmpty);
    await syncModels();
  }

  Future<void> syncModels() async {
    if (state.isSyncingModels) return;
    state = state.copyWith(isSyncingModels: true, clearModelError: true);
    try {
      final models = await ref
          .read(gatewayRepositoryProvider)
          .fetchModels(state.baseUrl);
      final currentSelected = state.selectedModelId;
      final hasSelected =
          currentSelected != null && models.any((m) => m.id == currentSelected);
      final nextSelected =
          hasSelected ? currentSelected : (models.isNotEmpty ? models.first.id : null);

      state = state.copyWith(
        models: models,
        selectedModelId: nextSelected,
        isSyncingModels: false,
        clearModelError: true,
      );
      if (nextSelected != null) {
        await ref
            .read(sharedPreferencesProvider)
            .setString(_kSelectedModel, nextSelected);
      }
    } on GatewayException catch (e) {
      state = state.copyWith(
        isSyncingModels: false,
        modelErrorFa: e.messageFa,
      );
    } catch (e) {
      state = state.copyWith(
        isSyncingModels: false,
        modelErrorFa: 'همگام‌سازی مدل‌ها ناموفق بود: $e',
      );
    }
  }

  Future<HealthCheckResult> runHealthCheck() async {
    final result = await ref
        .read(gatewayRepositoryProvider)
        .checkHealth(state.baseUrl);
    state = state.copyWith(lastHealth: result);
    if (result.isHealthy) {
      await syncModels();
    }
    return result;
  }

  Future<void> updateBaseUrl(String url) async {
    final normalized = AppConfig.normalizeBaseUrl(url);
    if (normalized.isEmpty) return;
    state = state.copyWith(baseUrl: normalized, clearModelError: true);
    await ref.read(sharedPreferencesProvider).setString(_kBaseUrl, normalized);
    await syncModels();
  }

  Future<void> updateApiKey(String? key) async {
    await ref.read(secureStorageProvider).writeGatewayApiKey(key);
    final hasKey = key != null && key.trim().isNotEmpty;
    state = state.copyWith(hasApiKey: hasKey);
    await syncModels();
  }

  Future<void> selectModel(String modelId) async {
    state = state.copyWith(selectedModelId: modelId);
    await ref.read(sharedPreferencesProvider).setString(_kSelectedModel, modelId);
  }

  Future<void> updateSystemPrompt(String prompt) async {
    final cleaned = prompt.trim();
    final value = cleaned.isEmpty ? AppConfig.defaultSystemPrompt : cleaned;
    state = state.copyWith(systemPrompt: value);
    await ref.read(sharedPreferencesProvider).setString(_kSystemPrompt, value);
  }

  Future<void> updateTemperature(double value) async {
    final clamped = double.parse(value.clamp(0.0, 2.0).toStringAsFixed(2));
    state = state.copyWith(temperature: clamped);
    await ref.read(sharedPreferencesProvider).setDouble(_kTemperature, clamped);
  }

  Future<void> updateMaxTokens(int value) async {
    final clamped = value.clamp(128, 16384);
    state = state.copyWith(maxTokens: clamped);
    await ref.read(sharedPreferencesProvider).setInt(_kMaxTokens, clamped);
  }

  Future<void> setMultimodalVision(bool enabled) async {
    state = state.copyWith(multimodalVision: enabled);
    await ref.read(sharedPreferencesProvider).setBool(_kMultimodal, enabled);
  }
}

final gatewayConfigProvider =
    NotifierProvider<GatewayConfigNotifier, GatewayConfigState>(
  GatewayConfigNotifier.new,
);

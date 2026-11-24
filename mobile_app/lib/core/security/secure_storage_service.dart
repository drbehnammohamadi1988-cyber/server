import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted credential storage backed by Android Keystore.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
            );

  static const String _gatewayApiKeySlot = 'orbi_gateway_api_key';

  final FlutterSecureStorage _storage;

  Future<String?> readGatewayApiKey() async {
    final value = await _storage.read(key: _gatewayApiKeySlot);
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  Future<void> writeGatewayApiKey(String? apiKey) async {
    final trimmed = apiKey?.trim() ?? '';
    if (trimmed.isEmpty) {
      await _storage.delete(key: _gatewayApiKeySlot);
      return;
    }
    await _storage.write(key: _gatewayApiKeySlot, value: trimmed);
  }

  Future<void> clearAll() => _storage.deleteAll();
}

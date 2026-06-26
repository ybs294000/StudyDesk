import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ai_provider_type.dart';

final aiSecureStorageServiceProvider = Provider<AiSecureStorageService>((ref) {
  return AiSecureStorageService();
});

class AiSecureStorageService {
  AiSecureStorageService()
      : _storage = kIsWeb
            ? null
            : FlutterSecureStorage(
                aOptions: AndroidOptions(
                  migrateWithBackup: true,
                ),
              );

  final FlutterSecureStorage? _storage;

  static final Map<String, String> _webSessionKeys = <String, String>{};

  Future<bool> hasKey(AiProviderType provider) async {
    final key = _storageKey(provider);
    if (kIsWeb) {
      return _webSessionKeys.containsKey(key);
    }
    return await _storage?.containsKey(key: key) ?? false;
  }

  Future<String?> readKey(AiProviderType provider) async {
    final key = _storageKey(provider);
    if (kIsWeb) {
      return _webSessionKeys[key];
    }
    return _storage?.read(key: key);
  }

  Future<void> writeKey(
    AiProviderType provider,
    String apiKey,
  ) async {
    final key = _storageKey(provider);
    if (kIsWeb) {
      _webSessionKeys[key] = apiKey;
      return;
    }
    await _storage?.write(key: key, value: apiKey);
  }

  Future<void> deleteKey(AiProviderType provider) async {
    final key = _storageKey(provider);
    if (kIsWeb) {
      _webSessionKeys.remove(key);
      return;
    }
    await _storage?.delete(key: key);
  }

  String _storageKey(AiProviderType provider) {
    return 'studydesk.ai.${provider.storageValue}.api_key';
  }
}

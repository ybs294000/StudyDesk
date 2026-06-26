import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/ai_secure_storage_service.dart';
import '../domain/ai_provider_type.dart';

const _selectedAiProviderKey = 'ai_selected_provider_v1';
const _openAiModelKey = 'ai_openai_model_v1';
const _claudeModelKey = 'ai_claude_model_v1';

final aiSettingsControllerProvider =
    AsyncNotifierProvider<AiSettingsController, AiSettingsState>(
  AiSettingsController.new,
);

class AiSettingsController extends AsyncNotifier<AiSettingsState> {
  @override
  Future<AiSettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final storage = ref.read(aiSecureStorageServiceProvider);
    final selectedProvider = AiProviderTypeX.fromStorage(
      prefs.getString(_selectedAiProviderKey),
    );
    final openAiModel =
        prefs.getString(_openAiModelKey)?.trim().isNotEmpty == true
            ? prefs.getString(_openAiModelKey)!.trim()
            : AiProviderType.openAi.defaultModel;
    final claudeModel =
        prefs.getString(_claudeModelKey)?.trim().isNotEmpty == true
            ? prefs.getString(_claudeModelKey)!.trim()
            : AiProviderType.claude.defaultModel;
    final hasOpenAiKey = await storage.hasKey(AiProviderType.openAi);
    final hasClaudeKey = await storage.hasKey(AiProviderType.claude);
    return AiSettingsState(
      selectedProvider: selectedProvider,
      openAiModel: openAiModel,
      claudeModel: claudeModel,
      hasOpenAiKey: hasOpenAiKey,
      hasClaudeKey: hasClaudeKey,
      sessionOnlyOnWeb: kIsWeb,
    );
  }

  Future<void> saveProvider(AiProviderType provider) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedAiProviderKey, provider.storageValue);
    state = AsyncData(current.copyWith(selectedProvider: provider));
  }

  Future<void> saveModels({
    required String openAiModel,
    required String claudeModel,
  }) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final normalizedOpenAi =
        openAiModel.trim().isEmpty ? AiProviderType.openAi.defaultModel : openAiModel.trim();
    final normalizedClaude =
        claudeModel.trim().isEmpty ? AiProviderType.claude.defaultModel : claudeModel.trim();
    await prefs.setString(_openAiModelKey, normalizedOpenAi);
    await prefs.setString(_claudeModelKey, normalizedClaude);
    state = AsyncData(
      current.copyWith(
        openAiModel: normalizedOpenAi,
        claudeModel: normalizedClaude,
      ),
    );
  }

  Future<void> saveApiKey({
    required AiProviderType provider,
    required String apiKey,
  }) async {
    final normalized = apiKey.trim();
    if (normalized.isEmpty) {
      throw const FormatException('API key cannot be empty.');
    }
    final storage = ref.read(aiSecureStorageServiceProvider);
    await storage.writeKey(provider, normalized);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          hasOpenAiKey: provider == AiProviderType.openAi ? true : current.hasOpenAiKey,
          hasClaudeKey: provider == AiProviderType.claude ? true : current.hasClaudeKey,
        ),
      );
    }
  }

  Future<void> deleteApiKey(AiProviderType provider) async {
    final storage = ref.read(aiSecureStorageServiceProvider);
    await storage.deleteKey(provider);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          hasOpenAiKey: provider == AiProviderType.openAi ? false : current.hasOpenAiKey,
          hasClaudeKey: provider == AiProviderType.claude ? false : current.hasClaudeKey,
        ),
      );
    }
  }

  Future<String?> readApiKey(AiProviderType provider) {
    return ref.read(aiSecureStorageServiceProvider).readKey(provider);
  }
}

class AiSettingsState {
  const AiSettingsState({
    required this.selectedProvider,
    required this.openAiModel,
    required this.claudeModel,
    required this.hasOpenAiKey,
    required this.hasClaudeKey,
    required this.sessionOnlyOnWeb,
  });

  final AiProviderType selectedProvider;
  final String openAiModel;
  final String claudeModel;
  final bool hasOpenAiKey;
  final bool hasClaudeKey;
  final bool sessionOnlyOnWeb;

  bool hasKeyFor(AiProviderType provider) {
    return switch (provider) {
      AiProviderType.openAi => hasOpenAiKey,
      AiProviderType.claude => hasClaudeKey,
    };
  }

  String modelFor(AiProviderType provider) {
    return switch (provider) {
      AiProviderType.openAi => openAiModel,
      AiProviderType.claude => claudeModel,
    };
  }

  AiSettingsState copyWith({
    AiProviderType? selectedProvider,
    String? openAiModel,
    String? claudeModel,
    bool? hasOpenAiKey,
    bool? hasClaudeKey,
    bool? sessionOnlyOnWeb,
  }) {
    return AiSettingsState(
      selectedProvider: selectedProvider ?? this.selectedProvider,
      openAiModel: openAiModel ?? this.openAiModel,
      claudeModel: claudeModel ?? this.claudeModel,
      hasOpenAiKey: hasOpenAiKey ?? this.hasOpenAiKey,
      hasClaudeKey: hasClaudeKey ?? this.hasClaudeKey,
      sessionOnlyOnWeb: sessionOnlyOnWeb ?? this.sessionOnlyOnWeb,
    );
  }
}

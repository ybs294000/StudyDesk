enum AiProviderType {
  openAi,
  claude,
}

extension AiProviderTypeX on AiProviderType {
  String get storageValue => switch (this) {
        AiProviderType.openAi => 'openai',
        AiProviderType.claude => 'claude',
      };

  String get label => switch (this) {
        AiProviderType.openAi => 'OpenAI',
        AiProviderType.claude => 'Claude',
      };

  String get defaultModel => switch (this) {
        AiProviderType.openAi => 'gpt-5.5',
        AiProviderType.claude => 'claude-sonnet-4-6',
      };

  static AiProviderType fromStorage(String? value) {
    return switch (value) {
      'claude' => AiProviderType.claude,
      _ => AiProviderType.openAi,
    };
  }
}

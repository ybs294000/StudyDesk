import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/profile_settings_controller.dart';
import '../../notes/application/note_markdown_utils.dart';
import '../domain/ai_chat_message.dart';
import '../domain/ai_content_kind.dart';
import '../domain/ai_provider_type.dart';
import 'ai_settings_controller.dart';
import 'ai_subject_context_service.dart';

final aiGenerationServiceProvider = Provider<AiGenerationService>((ref) {
  return AiGenerationService(
    ref: ref,
    dio: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
        headers: const {
          'Content-Type': 'application/json',
        },
      ),
    ),
  );
});

class AiGenerationService {
  AiGenerationService({
    required this.ref,
    required this._dio,
  });

  final Ref ref;
  final Dio _dio;

  Future<void> testConnection({
    required AiProviderType provider,
  }) async {
    await generateReply(
      subjectId: '__connection_test__',
      providerOverride: provider,
      kind: AiContentKind.note,
      userMessage:
          'Reply with a single line saying "StudyDesk AI connection ready." Do not return JSON.',
      existingMessages: const [],
      includeSubjectContext: false,
      noteId: null,
      importTargetUnitId: null,
    );
  }

  Future<AiChatMessage> generateReply({
    required String subjectId,
    required AiContentKind kind,
    required String userMessage,
    required List<AiChatMessage> existingMessages,
    required bool includeSubjectContext,
    required String? noteId,
    required String? importTargetUnitId,
    AiProviderType? providerOverride,
  }) async {
    final aiSettings = await ref.read(aiSettingsControllerProvider.future);
    final provider = providerOverride ?? aiSettings.selectedProvider;
    final model = aiSettings.modelFor(provider);
    final apiKey = await ref.read(aiSettingsControllerProvider.notifier).readApiKey(provider);
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw StateError('No ${provider.label} API key is saved yet.');
    }

    final activeSchema = ref.read(profileSettingsControllerProvider).activeSchemaTemplate;
    final subjectContext = includeSubjectContext && subjectId != '__connection_test__'
        ? await ref.read(aiSubjectContextServiceProvider).buildSubjectContext(
              subjectId: subjectId,
              noteId: noteId,
            )
        : 'No subject context was requested for this call.';
    final systemPrompt = _buildSystemPrompt(
      kind: kind,
      schemaTemplate: activeSchema,
      subjectContext: subjectContext,
      importTargetUnitId: importTargetUnitId,
      hasActiveNote: noteId != null,
    );

    final responseText = switch (provider) {
      AiProviderType.openAi => await _callOpenAi(
          apiKey: apiKey,
          model: model,
          systemPrompt: systemPrompt,
          messages: existingMessages,
          userMessage: userMessage,
        ),
      AiProviderType.claude => await _callClaude(
          apiKey: apiKey,
          model: model,
          systemPrompt: systemPrompt,
          messages: existingMessages,
          userMessage: userMessage,
        ),
    };

    final preview = _buildPreview(
      rawResponse: responseText,
      kind: kind,
    );
    return AiChatMessage(
      role: AiChatRole.assistant,
      content: responseText,
      preview: preview,
    );
  }

  String _buildSystemPrompt({
    required AiContentKind kind,
    required String schemaTemplate,
    required String subjectContext,
    required String? importTargetUnitId,
    required bool hasActiveNote,
  }) {
    final kindInstructions = switch (kind) {
      AiContentKind.deck => '''
Return only one valid StudyDesk deck JSON object.
The top-level "type" must be "deck".
Do not wrap JSON in markdown fences.
Make the deck complete and immediately importable.
''',
      AiContentKind.quiz => '''
Return only one valid StudyDesk quiz JSON object.
The top-level "type" must be "quiz".
Do not wrap JSON in markdown fences.
Make the quiz complete and immediately importable.
''',
      AiContentKind.note => '''
Return only one valid StudyDesk note JSON object.
The top-level "type" must be "note".
Use Markdown in "body_markdown".
Prefer consistent ## headings and include frontmatter:
---
section-level: h2
---
Do not wrap JSON in markdown fences.
''',
      AiContentKind.qaBank => '''
Return only one valid StudyDesk Q&A bank JSON object.
The top-level "type" must be "qa_bank".
Use Markdown in each "answer_markdown" field.
Do not wrap JSON in markdown fences.
''',
    };

    final noteInstruction = hasActiveNote
        ? 'If the user asks you to revise or expand the current note, keep the same conceptual scope unless they explicitly ask for a new note.'
        : 'If the user asks for note output, create a fresh note payload.';

    final unitInstruction = importTargetUnitId == null
        ? 'The app may import this content into the uncategorized subject scope.'
        : 'The app intends to import this content into the currently selected unit scope.';

    return '''
You are generating content for StudyDesk, an offline-first study app.

$kindInstructions

Follow the active StudyDesk schema exactly when returning JSON.
Never include surrounding commentary, apologies, or setup text.
If revising content from the chat history, return the complete new payload, not a diff.
$noteInstruction
$unitInstruction

CURRENT SUBJECT CONTEXT
$subjectContext

ACTIVE SCHEMA
$schemaTemplate
''';
  }

  Future<String> _callOpenAi({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required List<AiChatMessage> messages,
    required String userMessage,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'https://api.openai.com/v1/responses',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
          },
        ),
        data: {
          'model': model,
          'instructions': systemPrompt,
          'input': [
            for (final message in messages)
              {
                'role': message.isUser ? 'user' : 'assistant',
                'content': [
                  {
                    'type': 'input_text',
                    'text': message.content,
                  },
                ],
              },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'input_text',
                  'text': userMessage,
                },
              ],
            },
          ],
        },
      );
      final data = response.data ?? const <String, dynamic>{};
      return _extractOpenAiText(data);
    } on DioException catch (error) {
      throw StateError(_formatProviderError('OpenAI', error));
    }
  }

  Future<String> _callClaude({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required List<AiChatMessage> messages,
    required String userMessage,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'https://api.anthropic.com/v1/messages',
        options: Options(
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          },
        ),
        data: {
          'model': model,
          'max_tokens': 6000,
          'system': systemPrompt,
          'messages': [
            for (final message in messages)
              {
                'role': message.isUser ? 'user' : 'assistant',
                'content': message.content,
              },
            {
              'role': 'user',
              'content': userMessage,
            },
          ],
        },
      );
      final data = response.data ?? const <String, dynamic>{};
      return _extractClaudeText(data);
    } on DioException catch (error) {
      throw StateError(_formatProviderError('Claude', error));
    }
  }

  String _extractOpenAiText(Map<String, dynamic> data) {
    final direct = data['output_text'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct.trim();
    }
    final output = data['output'];
    if (output is List) {
      final buffer = StringBuffer();
      for (final item in output) {
        if (item is! Map) {
          continue;
        }
        final content = item['content'];
        if (content is! List) {
          continue;
        }
        for (final chunk in content) {
          if (chunk is! Map) {
            continue;
          }
          final text = chunk['text'];
          if (text is String && text.trim().isNotEmpty) {
            if (buffer.isNotEmpty) {
              buffer.writeln();
            }
            buffer.write(text.trim());
          }
        }
      }
      if (buffer.isNotEmpty) {
        return buffer.toString().trim();
      }
    }
    throw const FormatException('OpenAI returned no readable text output.');
  }

  String _extractClaudeText(Map<String, dynamic> data) {
    final content = data['content'];
    if (content is List) {
      final buffer = StringBuffer();
      for (final item in content) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final text = item['text'];
        if (text is String && text.trim().isNotEmpty) {
          if (buffer.isNotEmpty) {
            buffer.writeln();
          }
          buffer.write(text.trim());
        }
      }
      if (buffer.isNotEmpty) {
        return buffer.toString().trim();
      }
    }
    throw const FormatException('Claude returned no readable text output.');
  }

  String _formatProviderError(String provider, DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final errorObject = data['error'];
      if (errorObject is Map<String, dynamic>) {
        final message = errorObject['message'];
        if (message is String && message.trim().isNotEmpty) {
          return '$provider request failed: ${message.trim()}';
        }
      }
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return '$provider request failed: ${message.trim()}';
      }
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return '$provider request timed out. Check your network and try again.';
    }
    return '$provider request failed. Please verify the API key, model, and network connection.';
  }

  AiGeneratedPreview? _buildPreview({
    required String rawResponse,
    required AiContentKind kind,
  }) {
    switch (kind) {
      case AiContentKind.note:
        return _buildNotePreview(rawResponse);
      case AiContentKind.deck:
      case AiContentKind.quiz:
      case AiContentKind.qaBank:
        return _buildJsonPreview(rawResponse, expectedType: kind.storageValue);
    }
  }

  AiGeneratedPreview? _buildNotePreview(String rawResponse) {
    final jsonCandidate = _extractJsonCandidate(rawResponse);
    if (jsonCandidate != null) {
      final parsed = jsonDecode(jsonCandidate);
      if (parsed is Map<String, dynamic> && parsed['type'] == 'note') {
        final content = (parsed['content'] as Map?)?.cast<String, dynamic>() ?? const {};
        final title = (content['title'] as String?)?.trim();
        final body = (content['body_markdown'] as String?) ?? '';
        return AiGeneratedPreview(
          kind: 'note',
          rawPayload: jsonEncode(parsed),
          title: title == null || title.isEmpty
              ? deriveTitleFromMarkdown(body)
              : title,
          itemCount: 1,
          summary: _clip(body, 220),
        );
      }
    }

    final markdown = rawResponse.trim();
    if (markdown.isEmpty) {
      return null;
    }
    final wrapped = {
      'studydesk_version': '1.0',
      'type': 'note',
      'content': {
        'title': deriveTitleFromMarkdown(markdown),
        'tags': <String>[],
        'body_markdown': markdown,
      },
    };
    return AiGeneratedPreview(
      kind: 'note',
      rawPayload: const JsonEncoder.withIndent('  ').convert(wrapped),
      title: deriveTitleFromMarkdown(markdown),
      itemCount: 1,
      summary: _clip(markdown, 220),
    );
  }

  AiGeneratedPreview? _buildJsonPreview(
    String rawResponse, {
    required String expectedType,
  }) {
    final jsonCandidate = _extractJsonCandidate(rawResponse);
    if (jsonCandidate == null) {
      return null;
    }
    final parsed = jsonDecode(jsonCandidate);
    if (parsed is! Map<String, dynamic>) {
      return null;
    }
    if ((parsed['type'] as String?) != expectedType) {
      return null;
    }
    final content = (parsed['content'] as Map?)?.cast<String, dynamic>() ?? const {};
    final title = (content['name'] as String?)?.trim() ??
        (content['title'] as String?)?.trim() ??
        expectedType;
    final itemCount = switch (expectedType) {
      'deck' => (content['cards'] as List?)?.length ?? 0,
      'quiz' => (content['questions'] as List?)?.length ?? 0,
      'qa_bank' => (content['items'] as List?)?.length ?? 0,
      _ => 1,
    };
    final summary = switch (expectedType) {
      'deck' => '${itemCount.toString()} cards ready to import.',
      'quiz' => '${itemCount.toString()} questions ready to import.',
      'qa_bank' => '${itemCount.toString()} Q&A prompts ready to import.',
      _ => 'Ready to import.',
    };
    return AiGeneratedPreview(
      kind: expectedType,
      rawPayload: const JsonEncoder.withIndent('  ').convert(parsed),
      title: title.isEmpty ? expectedType : title,
      itemCount: itemCount,
      summary: summary,
    );
  }

  String? _extractJsonCandidate(String rawResponse) {
    final trimmed = rawResponse.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return trimmed;
    }

    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```', multiLine: true)
        .firstMatch(rawResponse);
    if (fenced != null) {
      final candidate = fenced.group(1)?.trim();
      if (candidate != null && candidate.startsWith('{') && candidate.endsWith('}')) {
        return candidate;
      }
    }

    final start = rawResponse.indexOf('{');
    final end = rawResponse.lastIndexOf('}');
    if (start != -1 && end > start) {
      return rawResponse.substring(start, end + 1).trim();
    }
    return null;
  }

  String _clip(String value, int maxLength) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength - 3)}...';
  }
}

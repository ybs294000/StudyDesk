import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/studydesk_security.dart';
import '../../../theme/app_spacing.dart';
import '../../../services/content_portability_service.dart';
import '../../notes/application/subject_notes_controller.dart';
import '../../qa/application/subject_qa_controller.dart';
import '../../subjects/application/subjects_controller.dart';
import '../../units/application/subject_units_controller.dart';
import '../../units/domain/subject_unit_record.dart';
import '../application/ai_generation_service.dart';
import '../application/ai_settings_controller.dart';
import '../domain/ai_chat_message.dart';
import '../domain/ai_content_kind.dart';
import '../domain/ai_provider_type.dart';

class SubjectAiWorkspaceScreen extends ConsumerStatefulWidget {
  const SubjectAiWorkspaceScreen({
    required this.subjectId,
    this.initialKind,
    this.noteId,
    super.key,
  });

  final String subjectId;
  final String? initialKind;
  final String? noteId;

  @override
  ConsumerState<SubjectAiWorkspaceScreen> createState() =>
      _SubjectAiWorkspaceScreenState();
}

class _SubjectAiWorkspaceScreenState
    extends ConsumerState<SubjectAiWorkspaceScreen> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  final List<AiChatMessage> _messages = <AiChatMessage>[];

  bool _includeSubjectContext = true;
  bool _isSending = false;
  bool _isApplying = false;
  String? _selectedUnitId;
  late AiContentKind _selectedKind;

  @override
  void initState() {
    super.initState();
    _selectedKind = _kindFromStorage(widget.initialKind);
  }

  @override
  void dispose() {
    _promptController.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsControllerProvider);
    final unitsAsync = ref.watch(subjectUnitsControllerProvider(widget.subjectId));
    final aiSettingsAsync = ref.watch(aiSettingsControllerProvider);

    return subjectsAsync.when(
      data: (subjects) {
        final subject = subjects.where((item) => item.id == widget.subjectId).firstOrNull;
        if (subject == null) {
          return const Center(child: Text('Subject not found.'));
        }
        return unitsAsync.when(
          data: (units) {
            _selectedUnitId ??= _resolveInitialUnitId(units);
            final isCompact = MediaQuery.sizeOf(context).width < 980;
            return aiSettingsAsync.when(
              data: (aiSettings) => Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WorkspaceHeader(
                      subjectName: subject.name,
                      hasActiveNote: widget.noteId != null,
                      onBack: _goBack,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _WorkspaceControls(
                      selectedKind: _selectedKind,
                      includeSubjectContext: _includeSubjectContext,
                      selectedUnitId: _selectedUnitId,
                      units: units,
                      aiSettings: aiSettings,
                      onKindChanged: (value) {
                        setState(() => _selectedKind = value);
                      },
                      onIncludeSubjectContextChanged: (value) {
                        setState(() => _includeSubjectContext = value);
                      },
                      onUnitChanged: (value) {
                        setState(() => _selectedUnitId = value);
                      },
                      onOpenSettings: () => context.push('/settings'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: isCompact
                          ? Column(
                              children: [
                                Expanded(
                                  child: _ConversationCard(
                                    messages: _messages,
                                    isSending: _isSending,
                                    controller: _promptController,
                                    scrollController: _messagesScrollController,
                                    onSend: _sendPrompt,
                                    hintText: _composerHint(),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                SizedBox(
                                  height: 360,
                                  child: _PreviewCard(
                                    latestPreview: _latestPreview,
                                    hasActiveNote: widget.noteId != null,
                                    isApplying: _isApplying,
                                    onCopyPayload: _copyPayload,
                                    onApply: _applyPreview,
                                    onInsertRevisionPrompt: _insertRevisionPrompt,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 12,
                                  child: _ConversationCard(
                                    messages: _messages,
                                    isSending: _isSending,
                                    controller: _promptController,
                                    scrollController: _messagesScrollController,
                                    onSend: _sendPrompt,
                                    hintText: _composerHint(),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.lg),
                                Expanded(
                                  flex: 8,
                                  child: _PreviewCard(
                                    latestPreview: _latestPreview,
                                    hasActiveNote: widget.noteId != null,
                                    isApplying: _isApplying,
                                    onCopyPayload: _copyPayload,
                                    onApply: _applyPreview,
                                    onInsertRevisionPrompt: _insertRevisionPrompt,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Center(child: Text('Could not load AI settings: $error')),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text('Could not load units: $error')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Could not load subjects: $error')),
    );
  }

  AiGeneratedPreview? get _latestPreview {
    for (final message in _messages.reversed) {
      if (message.preview != null) {
        return message.preview;
      }
    }
    return null;
  }

  AiContentKind _kindFromStorage(String? value) {
    return switch (value) {
      'deck' => AiContentKind.deck,
      'quiz' => AiContentKind.quiz,
      'note' => AiContentKind.note,
      'qa_bank' => AiContentKind.qaBank,
      _ => widget.noteId != null ? AiContentKind.note : AiContentKind.deck,
    };
  }

  String? _resolveInitialUnitId(List<SubjectUnitRecord> units) {
    if (widget.noteId == null) {
      return null;
    }
    final notes = ref.read(subjectNotesControllerProvider(widget.subjectId)).valueOrNull;
    final activeNote = notes?.where((item) => item.id == widget.noteId).firstOrNull;
    if (activeNote == null) {
      return null;
    }
    return units.any((unit) => unit.id == activeNote.unitId) ? activeNote.unitId : null;
  }

  Future<void> _sendPrompt() async {
    if (_isSending) {
      return;
    }
    final String prompt;
    try {
      prompt = StudyDeskSecurity.sanitizeMultiline(
        _promptController.text,
        field: 'AI request',
        maxLength: 24000,
        allowEmpty: false,
      );
    } catch (error) {
      _showMessage(error.toString());
      return;
    }
    final allHistory =
        _messages.where((item) => item.errorMessage == null).toList();
    final history = allHistory.length <= 8
        ? allHistory
        : allHistory.sublist(allHistory.length - 8);
    setState(() {
      _isSending = true;
      _messages.add(AiChatMessage(role: AiChatRole.user, content: prompt));
      _promptController.clear();
    });
    _scrollToBottom();
    try {
      final response = await ref.read(aiGenerationServiceProvider).generateReply(
            subjectId: widget.subjectId,
            kind: _selectedKind,
            userMessage: prompt,
            existingMessages: history,
            includeSubjectContext: _includeSubjectContext,
            noteId: widget.noteId,
            importTargetUnitId: _selectedUnitId,
          );
      if (!mounted) {
        return;
      }
      setState(() => _messages.add(response));
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          AiChatMessage(
            role: AiChatRole.assistant,
            content: 'StudyDesk could not complete that AI request.',
            errorMessage: error.toString(),
          ),
        );
      });
      _showMessage('AI request failed: $error');
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _applyPreview() async {
    final preview = _latestPreview;
    if (preview == null || _isApplying) {
      return;
    }
    setState(() => _isApplying = true);
    try {
      if (preview.kind == 'note' && widget.noteId != null) {
        await _applyPreviewToCurrentNote(preview);
        _showMessage('Current note updated from AI output.');
      } else {
        final result = await ref.read(contentPortabilityServiceProvider).importStudyJson(
              subjectId: widget.subjectId,
              jsonSource: preview.rawPayload,
              unitId: _selectedUnitId,
            );
        ref.invalidate(subjectNotesControllerProvider(widget.subjectId));
        ref.invalidate(subjectQaControllerProvider(widget.subjectId));
        _showMessage('Imported ${result.name} into this subject.');
      }
    } catch (error) {
      _showMessage('Could not apply AI output: $error');
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  Future<void> _applyPreviewToCurrentNote(AiGeneratedPreview preview) async {
    final payload = StudyDeskSecurity.decodeJsonObject(
      preview.rawPayload,
      label: 'AI note payload',
    );
    final content = (payload['content'] as Map?)?.cast<String, dynamic>() ?? const {};
    final notes = await ref.read(subjectNotesControllerProvider(widget.subjectId).future);
    final existing = notes.where((item) => item.id == widget.noteId).firstOrNull;
    if (existing == null) {
      throw StateError('The current note no longer exists.');
    }
    final validUnitIds = (await ref.read(subjectUnitsControllerProvider(widget.subjectId).future))
        .map((item) => item.id)
        .toSet();
    final requestedUnitId = (content['unit_id'] ?? content['unitId'])?.toString().trim();
    final resolvedUnitId = requestedUnitId != null && validUnitIds.contains(requestedUnitId)
        ? requestedUnitId
        : _selectedUnitId;
    final updated = existing.copyWith(
      title: (content['title'] as String?)?.trim().isNotEmpty == true
          ? content['title'] as String
          : existing.title,
      unitId: resolvedUnitId,
      bodyMarkdown: (content['body_markdown'] ??
              content['bodyMarkdown'] ??
              content['markdown'] ??
              content['body'])
          ?.toString() ??
          existing.bodyMarkdown,
      tags: (((content['tags'] as List?) ?? const [])
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty))
          .toList(),
    );
    await ref
        .read(subjectNotesControllerProvider(widget.subjectId).notifier)
        .updateNote(updated);
  }

  Future<void> _copyPayload() async {
    final preview = _latestPreview;
    if (preview == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: preview.rawPayload));
    if (!mounted) {
      return;
    }
    _showMessage('AI payload copied.');
  }

  void _insertRevisionPrompt() {
    final preview = _latestPreview;
    if (preview == null) {
      return;
    }
    _promptController.text = switch (preview.kind) {
      'deck' =>
        'Revise the deck you just created. Keep valid StudyDesk JSON, improve clarity, and avoid duplicates with existing subject content.',
      'quiz' =>
        'Revise the quiz you just created. Keep valid StudyDesk JSON, improve balance, and make explanations stronger.',
      'note' =>
        'Revise the note you just created. Keep valid StudyDesk note JSON, improve structure, and strengthen headings and summaries.',
      'qa_bank' =>
        'Revise the Q&A bank you just created. Keep valid StudyDesk JSON, improve answers, and remove overlapping prompts.',
      _ => 'Revise the content you just created while preserving valid StudyDesk output.',
    };
    _promptController.selection = TextSelection.collapsed(
      offset: _promptController.text.length,
    );
  }

  String _composerHint() {
    if (widget.noteId != null && _selectedKind == AiContentKind.note) {
      return 'Example: rewrite this note into a clearer exam-ready structure with stronger section headings and a concise summary.';
    }
    return switch (_selectedKind) {
      AiContentKind.deck =>
        'Ask for a deck tied to this subject, unit, and existing study material.',
      AiContentKind.quiz =>
        'Ask for a quiz with a target difficulty, question mix, and explanation style.',
      AiContentKind.note =>
        'Ask for a markdown note with formulas, clean headings, and good study flow.',
      AiContentKind.qaBank =>
        'Ask for long-form recall prompts with complete model answers.',
    };
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    if (widget.noteId != null) {
      context.go('/subjects/${widget.subjectId}/notes/${widget.noteId}');
      return;
    }
    context.go('/subjects/${widget.subjectId}');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messagesScrollController.hasClients) {
        return;
      }
      _messagesScrollController.animateTo(
        _messagesScrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.subjectName,
    required this.hasActiveNote,
    required this.onBack,
  });

  final String subjectName;
  final bool hasActiveNote;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Workspace',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.micro),
              Text(
                hasActiveNote
                    ? '$subjectName • current note context included'
                    : '$subjectName • local subject context available',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkspaceControls extends StatelessWidget {
  const _WorkspaceControls({
    required this.selectedKind,
    required this.includeSubjectContext,
    required this.selectedUnitId,
    required this.units,
    required this.aiSettings,
    required this.onKindChanged,
    required this.onIncludeSubjectContextChanged,
    required this.onUnitChanged,
    required this.onOpenSettings,
  });

  final AiContentKind selectedKind;
  final bool includeSubjectContext;
  final String? selectedUnitId;
  final List<SubjectUnitRecord> units;
  final AiSettingsState aiSettings;
  final ValueChanged<AiContentKind> onKindChanged;
  final ValueChanged<bool> onIncludeSubjectContextChanged;
  final ValueChanged<String?> onUnitChanged;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generation Target',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final kind in AiContentKind.values)
                  ChoiceChip(
                    label: Text(_kindLabel(kind)),
                    selected: selectedKind == kind,
                    onSelected: (_) => onKindChanged(kind),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String?>(
                    initialValue: selectedUnitId,
                    decoration: const InputDecoration(
                      labelText: 'Import into unit',
                      prefixIcon: Icon(Icons.folder_copy_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Uncategorized'),
                      ),
                      for (final unit in units)
                        DropdownMenuItem<String?>(
                          value: unit.id,
                          child: Text(unit.name),
                        ),
                    ],
                    onChanged: onUnitChanged,
                  ),
                ),
                SizedBox(
                  width: 340,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: includeSubjectContext,
                    onChanged: onIncludeSubjectContextChanged,
                    title: const Text('Use current subject context'),
                    subtitle: const Text(
                      'Include existing notes, decks, quizzes, Q&A, and units in the request.',
                    ),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.hub_rounded, size: 18),
                  label: Text(
                    '${aiSettings.selectedProvider.label} • ${aiSettings.modelFor(aiSettings.selectedProvider)}',
                  ),
                  onPressed: onOpenSettings,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _kindLabel(AiContentKind kind) {
    return switch (kind) {
      AiContentKind.deck => 'Deck',
      AiContentKind.quiz => 'Quiz',
      AiContentKind.note => 'Note',
      AiContentKind.qaBank => 'Q&A Bank',
    };
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.messages,
    required this.isSending,
    required this.controller,
    required this.scrollController,
    required this.onSend,
    required this.hintText,
  });

  final List<AiChatMessage> messages;
  final bool isSending;
  final TextEditingController controller;
  final ScrollController scrollController;
  final Future<void> Function() onSend;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chat',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Text(
                        'Start with a concrete study request. StudyDesk keeps the conversation so you can refine a generated deck, quiz, note, or Q&A bank instead of starting from zero.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: messages.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isUser = message.isUser;
                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: isUser
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isUser ? 'You' : 'StudyDesk AI',
                                      style: Theme.of(context).textTheme.labelLarge,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    SelectableText(message.content),
                                    if (message.errorMessage != null) ...[
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                        message.errorMessage!,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                      ),
                                    ],
                                    if (message.preview != null) ...[
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                        'Recognized importable ${message.preview!.kind} payload: ${message.preview!.title}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 7,
              decoration: InputDecoration(
                alignLabelWithHint: true,
                labelText: 'Prompt',
                hintText: hintText,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Generated content still has to pass StudyDesk validation before import.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: isSending ? null : () => onSend(),
                  icon: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(isSending ? 'Generating...' : 'Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.latestPreview,
    required this.hasActiveNote,
    required this.isApplying,
    required this.onCopyPayload,
    required this.onApply,
    required this.onInsertRevisionPrompt,
  });

  final AiGeneratedPreview? latestPreview;
  final bool hasActiveNote;
  final bool isApplying;
  final Future<void> Function() onCopyPayload;
  final Future<void> Function() onApply;
  final VoidCallback onInsertRevisionPrompt;

  @override
  Widget build(BuildContext context) {
    final preview = latestPreview;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Preview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (preview == null)
              Text(
                'When the assistant returns valid StudyDesk JSON or a valid note payload, it will appear here with a direct import action.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else ...[
              Text(
                preview.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                preview.summary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.52),
                    ),
                    child: SelectableText(
                      _prettyPayload(preview.rawPayload),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'Courier New',
                            height: 1.45,
                          ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.icon(
                    onPressed: isApplying ? null : () => onApply(),
                    icon: isApplying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            hasActiveNote && preview.kind == 'note'
                                ? Icons.save_as_rounded
                                : Icons.download_done_rounded,
                          ),
                    label: Text(
                      isApplying
                          ? 'Applying...'
                          : hasActiveNote && preview.kind == 'note'
                              ? 'Apply to Current Note'
                              : 'Import into Subject',
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => onCopyPayload(),
                    icon: const Icon(Icons.copy_all_rounded),
                    label: const Text('Copy Payload'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onInsertRevisionPrompt,
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Refine This'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _prettyPayload(String rawPayload) {
    try {
      final parsed = jsonDecode(rawPayload);
      return const JsonEncoder.withIndent('  ').convert(parsed);
    } catch (_) {
      return rawPayload;
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

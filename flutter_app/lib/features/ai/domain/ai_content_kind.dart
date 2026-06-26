enum AiContentKind {
  deck,
  quiz,
  note,
  qaBank,
}

extension AiContentKindX on AiContentKind {
  String get storageValue => switch (this) {
        AiContentKind.deck => 'deck',
        AiContentKind.quiz => 'quiz',
        AiContentKind.note => 'note',
        AiContentKind.qaBank => 'qa_bank',
      };

  String get label => switch (this) {
        AiContentKind.deck => 'Deck',
        AiContentKind.quiz => 'Quiz',
        AiContentKind.note => 'Note',
        AiContentKind.qaBank => 'Q&A Bank',
      };

  String get assistantLabel => switch (this) {
        AiContentKind.deck => 'flashcard deck JSON',
        AiContentKind.quiz => 'quiz JSON',
        AiContentKind.note => 'note JSON',
        AiContentKind.qaBank => 'Q&A bank JSON',
      };
}

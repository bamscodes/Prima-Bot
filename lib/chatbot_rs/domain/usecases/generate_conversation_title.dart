import '../../data/datasources/ai_datasource.dart';
import '../utils/conversation_title_formatter.dart';

class GenerateConversationTitle {
  /// Returns a local title immediately; this is used until the AI title has
  /// been generated or when the device is offline.
  String fallback({
    required String userMessage,
  }) {
    return ConversationTitleFormatter.format(userMessage);
  }

  /// Asks the AI to summarize the opening exchange into a short chat title.
  /// A null return means callers should retain [fallback].
  Future<String?> execute({
    required String userMessage,
    required String assistantMessage,
  }) async {
    final generated = await AIService.generateConversationTitle(
      userMessage: userMessage,
      assistantMessage: assistantMessage,
    );
    if (generated == null || generated.trim().isEmpty) return null;

    return ConversationTitleFormatter.formatGenerated(
      generated,
      fallback: userMessage,
    );
  }
}

import '../utils/conversation_title_formatter.dart';

class GenerateConversationTitle {
  String execute({
    required String userMessage,
  }) {
    return ConversationTitleFormatter.format(userMessage);
  }
}

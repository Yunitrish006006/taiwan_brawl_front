import 'package:user_basic_system/user_basic_system.dart';

/// Optional extension implemented by services that support event-based edits.
/// The base package's [DmService] remains unchanged for compatibility.
abstract interface class EditableDmService {
  Future<void> editMessage(ChatMessage message, String text);
}

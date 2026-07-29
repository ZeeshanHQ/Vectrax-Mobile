import 'package:flutter/foundation.dart';

class AiService {
  /// The intelligent fallback controller
  /// Routes the SQL generation request directly to the secure backend API,
  /// which will cascade through Gemini, GitHub Models, and OpenRouter privately.
  Future<String?> generateSql({
    required String prompt,
    required Map<String, dynamic> schema,
    required Future<String?> Function() getBackendCall,
  }) async {
    try {
      debugPrint('[AiService] 🧠 Querying secure backend AI pipeline...');
      final result = await getBackendCall();
      if (result != null && result.isNotEmpty) {
        debugPrint('[AiService] ✅ AI query generated successfully.');
        return result;
      }
    } catch (e) {
      debugPrint('[AiService] ❌ Backend AI query failed: $e');
    }
    return null;
  }
}

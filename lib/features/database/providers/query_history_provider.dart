import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QueryHistoryItem {
  final String id;
  final String query;
  final DateTime timestamp;

  QueryHistoryItem({
    required this.id,
    required this.query,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'query': query,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory QueryHistoryItem.fromJson(Map<String, dynamic> json) {
    return QueryHistoryItem(
      id: json['id'] ?? '',
      query: json['query'] ?? '',
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class QueryHistoryNotifier extends StateNotifier<List<QueryHistoryItem>> {
  QueryHistoryNotifier() : super([]) {
    _loadHistory();
  }

  static const String _storageKey = 'sql_query_history_elite';

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_storageKey);
      if (raw != null) {
        final List<dynamic> decoded = jsonDecode(raw);
        state = decoded.map((e) => QueryHistoryItem.fromJson(e)).toList();
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(state.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      // Ignore errors
    }
  }

  void addQuery(String query) {
    if (query.trim().isEmpty) return;

    // De-duplicate: If the same query exists, move it to the top
    final existingIndex =
        state.indexWhere((item) => item.query.trim() == query.trim());
    if (existingIndex != -1) {
      final existing = state[existingIndex];
      state = [
        QueryHistoryItem(
            id: existing.id, query: query, timestamp: DateTime.now()),
        ...state.where((item) => item.id != existing.id),
      ];
    } else {
      final newItem = QueryHistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        query: query,
        timestamp: DateTime.now(),
      );
      // Keep only last 20
      state = [newItem, ...state].take(20).toList();
    }
    _saveHistory();
  }

  void removeQuery(String id) {
    state = state.where((item) => item.id != id).toList();
    _saveHistory();
  }

  void clearHistory() {
    state = [];
    _saveHistory();
  }
}

final queryHistoryProvider =
    StateNotifierProvider<QueryHistoryNotifier, List<QueryHistoryItem>>((ref) {
  return QueryHistoryNotifier();
});

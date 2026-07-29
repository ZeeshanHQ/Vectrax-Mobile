import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supa_app/features/database/models/sql_snippet.dart';
import 'package:supa_app/core/services/api_service.dart';
import 'package:supa_app/core/services/project_context.dart';
import 'package:flutter/foundation.dart';

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class SqlSnippetsNotifier extends StateNotifier<List<SqlSnippet>> {
  SqlSnippetsNotifier() : super([]) {
    _loadSnippets();
  }

  static const String _storageKey = 'sql_snippets_v1_final';
  final _supabase = Supabase.instance.client;

  Future<void> _loadSnippets() async {
    // 1. Load from local cache for instant UI
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_storageKey);
      if (raw != null) {
        final List<dynamic> decoded = jsonDecode(raw);
        state = decoded.map((e) => SqlSnippet.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('[Snippets] Local load error: $e');
    }

    // 2. Sync from Cloud DB
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabase
            .from('sql_snippets')
            .select()
            .eq('user_id', user.id);

        if (response != null) {
          final List<dynamic> data = response;
          final cloudSnippets = data.map((e) {
            return SqlSnippet(
              id: e['id'].toString(),
              title: e['title'] ?? 'Untitled',
              query: e['code'] ?? '',
              description: e['description'] ?? '',
              category: e['category'] ?? 'General',
            );
          }).toList();

          state = cloudSnippets;
          _saveLocalCache();
        }
      }
    } catch (e) {
      debugPrint('[Snippets] Cloud sync error: $e');
    }
  }

  Future<void> _saveLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(state.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('[Snippets] Local save error: $e');
    }
  }

  Future<void> addSnippet(SqlSnippet snippet) async {
    state = [...state, snippet];
    _saveLocalCache();

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('sql_snippets').insert({
          'user_id': user.id,
          'title': snippet.title,
          'code': snippet.query,
          'description': snippet.description,
          'category': snippet.category,
        });
        debugPrint('[Snippets] Cloud add success');
      }
    } catch (e) {
      debugPrint('[Snippets] Cloud add error: $e');
    }
  }

  Future<void> removeSnippet(String id) async {
    state = state.where((s) => s.id != id).toList();
    _saveLocalCache();

    try {
      await _supabase.from('sql_snippets').delete().eq('id', id);
      debugPrint('[Snippets] Cloud delete success');
    } catch (e) {
      debugPrint('[Snippets] Cloud delete error: $e');
    }
  }

  Future<void> updateSnippet(SqlSnippet snippet) async {
    state = [
      for (final s in state)
        if (s.id == snippet.id) snippet else s
    ];
    _saveLocalCache();

    try {
      await _supabase.from('sql_snippets').update({
        'title': snippet.title,
        'code': snippet.query,
        'description': snippet.description,
        'category': snippet.category,
      }).eq('id', snippet.id);
      debugPrint('[Snippets] Cloud update success');
    } catch (e) {
      debugPrint('[Snippets] Cloud update error: $e');
    }
  }
}

final sqlSnippetsProvider =
    StateNotifierProvider<SqlSnippetsNotifier, List<SqlSnippet>>((ref) {
  return SqlSnippetsNotifier();
});

class QueryKey {
  final String query;
  final String projectRef;
  QueryKey(this.query, this.projectRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryKey &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          projectRef == other.projectRef;

  @override
  int get hashCode => query.hashCode ^ projectRef.hashCode;
}

final queryExecutionProvider =
    FutureProvider.family<List<Map<String, dynamic>>, QueryKey>(
        (ref, key) async {
  final apiService = ApiService();

  final result = await apiService.executeSql(key.projectRef, key.query);

  if (result is List) {
    return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } else if (result is Map) {
    return [Map<String, dynamic>.from(result)];
  }

  return [
    {'message': 'Query executed successfully'}
  ];
});

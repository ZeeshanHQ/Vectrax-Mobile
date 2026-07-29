import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:supa_app/core/config/app_config.dart';
import 'package:supa_app/core/services/auth_service.dart';
import 'package:supa_app/core/services/ai_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  final AuthService _authService = AuthService();
  final AiService _aiService = AiService();

  /// Helper to get common headers including the Access Token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Lists all projects from the API Backend with Cloud Cache support
  Future<List<dynamic>> listProjects() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    // 1. Fetch from Cloud Cache first for immediate availability
    List<dynamic> cachedProjects = [];
    if (userId != null) {
      try {
        final cache = await client
            .from('project_cache')
            .select()
            .eq('user_id', userId);
        cachedProjects = cache as List<dynamic>;
        debugPrint('[ApiService] 📦 Loaded ${cachedProjects.length} projects from cache');
      } catch (e) {
        debugPrint('[ApiService] ⚠️ Cache fetch failed: $e');
      }
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/projects'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> apiProjects = jsonDecode(response.body);
        
        // Sync to Cloud Cache for persistence
        if (userId != null) {
          try {
            for (final project in apiProjects) {
              await client.from('project_cache').upsert({
                'id': project['id'], 
                'user_id': userId,
                'project_ref': project['id'],
                'name': project['name'],
                'region': project['region'],
                'status': project['status'],
                'metadata': project,
              });
            }
            debugPrint('[ApiService] ☁️ Project cache updated');
          } catch (e) {
            debugPrint('[ApiService] ⚠️ Cache sync failed: $e');
          }
        }

        // Merge API projects with cached projects (prefer API)
        final Map<String, dynamic> merged = {};
        for (var p in cachedProjects) {
          merged[p['project_ref']] = p['metadata'] ?? p;
        }
        for (var p in apiProjects) {
          merged[p['id']] = p;
        }

        return merged.values.toList();
      }
      
      // If API fails, return cache if available
      return cachedProjects.isNotEmpty ? cachedProjects.map((e) => e['metadata'] ?? e).toList() : [];
    } catch (e) {
      return cachedProjects.isNotEmpty ? cachedProjects.map((e) => e['metadata'] ?? e).toList() : [];
    }
  }

  /// Alias for listProjects used by core features
  Future<List<dynamic>> getProjects() => listProjects();

  /// Lists all organizations
  Future<List<dynamic>> listOrganizations() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/organizations'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Pings a project to keep it alive (prevents pausing)
  Future<bool> pingProject(String ref) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/projects/$ref/ping'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Lists all tables for a project
  Future<List<dynamic>> listTables(String ref, {String? apiKey}) async {
    try {
      final queryParams = apiKey != null ? '?apiKey=$apiKey' : '';
      final response = await http.get(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/api/projects/$ref/tables$queryParams'),
        headers: await _getHeaders(),
      );

      debugPrint('[ApiService] 📡 Response for $ref: ${response.statusCode}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        debugPrint('[ApiService] ❌ Discovery failed: ${response.body}');
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetches records from a table
  Future<List<dynamic>> fetchRecords(String ref, String tableName,
      {String? apiKey}) async {
    try {
      final queryParams = apiKey != null ? '?apiKey=$apiKey' : '';
      final response = await http.get(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/api/projects/$ref/tables/$tableName/records$queryParams'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Lists all edge functions for a project
  Future<List<dynamic>> listFunctions(String ref) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/projects/$ref/functions'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Lists all storage buckets for a project
  Future<List<dynamic>> listBuckets(String ref) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/projects/$ref/buckets'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> listFiles(String ref, String bucketId,
      {String? prefix}) async {
    try {
      final queryParams =
          prefix != null ? '?prefix=${Uri.encodeComponent(prefix)}' : '';
      final response = await http.get(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/api/projects/$ref/buckets/$bucketId/files$queryParams'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Gets the database schema for the AI architect
  Future<Map<String, dynamic>> getSchema(String ref) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/projects/$ref/schema'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Executes arbitrary SQL on the project
  Future<dynamic> executeSql(String ref, String query) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/projects/$ref/sql'),
        headers: await _getHeaders(),
        body: jsonEncode({'query': query}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('SQL Execution failed: ${response.body}');
    } catch (e) {
      rethrow;
    }
  }

  /// Generates SQL from natural language via Intelligent Fallback System
  Future<String?> generateAiSql(String prompt, Map<String, dynamic> schema,
      {String? ref, String? projectName}) async {
    Map<String, dynamic> enrichedSchema = Map.from(schema);
    if (projectName != null) enrichedSchema['project_name'] = projectName;

    // 1. Fetch buckets if ref is available to provide storage context
    if (ref != null) {
      try {
        final buckets = await listBuckets(ref);
        enrichedSchema['storage_buckets'] = buckets;
      } catch (e) {
        debugPrint(
            '[ApiService] ⚠️ Failed to fetch buckets for AI context: $e');
      }
    }

    return await _aiService.generateSql(
      prompt: prompt,
      schema: enrichedSchema,
      getBackendCall: () async {
        final response = await http
            .post(
              Uri.parse('${AppConfig.apiBaseUrl}/api/ai/generate-sql'),
              headers: await _getHeaders(),
              body: jsonEncode({
                'prompt': prompt,
                'schema': enrichedSchema,
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['sql'] as String?;
        }
        return null;
      },
    );
  }

  /// Deletes a resource (table, bucket, function)
  Future<bool> deleteResource(String ref, String type, String id) async {
    try {
      final response = await http.delete(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/api/projects/$ref/resources/$type/$id'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Lists logs for a project service (api, postgres, edge-function, auth)
  Future<List<dynamic>> listLogs(String ref, {String service = 'edge-function'}) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/projects/$ref/logs?service=$service'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] ⚠️ Logs fetch failed: $e');
      return [];
    }
  }

  /// Lists users for a project
  Future<List<dynamic>> listUsers(String ref) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/projects/$ref/users'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] ⚠️ Users fetch failed: $e');
      return [];
    }
  }

  /// Restarts the database for a project
  Future<bool> restartDatabase(String ref) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/projects/$ref/restart'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] ⚠️ Restart failed: $e');
      return false;
    }
  }

  /// Pauses a project
  Future<bool> pauseProject(String ref) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/projects/$ref/pause'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] ⚠️ Pause failed: $e');
      return false;
    }
  }
}

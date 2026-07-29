import 'dart:convert';
import 'package:http/http.dart' as http;

class ManagementService {
  final String _baseUrl = 'https://api.supabase.com/v1';
  final String _authToken;

  ManagementService(this._authToken);

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_authToken',
        'Content-Type': 'application/json',
      };

  // Fetch all projects
  Future<List<dynamic>> getProjects() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/projects'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load projects: ${response.body}');
    }
  }

  // Pause a project (Infrastructure Control)
  Future<void> pauseProject(String projectRef) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/projects/$projectRef/pause'),
      headers: _headers,
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to pause project: ${response.body}');
    }
  }

  // Resume a project
  Future<void> resumeProject(String projectRef) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/projects/$projectRef/resume'),
      headers: _headers,
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to resume project: ${response.body}');
    }
  }

  // Restart Database (Simulated via Pause/Resume if no direct endpoint)
  Future<void> restartDatabase(String projectRef) async {
    await pauseProject(projectRef);
    // Wait a bit for the pause to start, then resume
    await Future.delayed(const Duration(seconds: 5));
    await resumeProject(projectRef);
  }

  // Fetch Project Health / Usage (for Health Alerts)
  Future<Map<String, dynamic>> getProjectUsage(String projectRef) async {
    // This endpoint provides CPU and Ram usage in Management API
    final response = await http.get(
      Uri.parse('$_baseUrl/projects/$projectRef/usage'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch usage: ${response.body}');
    }
  }
}

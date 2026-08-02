import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProjectContext extends ChangeNotifier {
  static final ProjectContext _instance = ProjectContext._internal();
  factory ProjectContext() => _instance;
  ProjectContext._internal() {
    _loadFromPrefs();
  }

  Map<String, dynamic>? _currentProject;
  final Map<String, String> _serviceRoleKeys = {};
  final Set<String> _monitoredProjectIds = {};

  Map<String, dynamic>? get currentProject => _currentProject;
  bool get hasProject => _currentProject != null;
  Set<String> get monitoredProjectIds => _monitoredProjectIds;

  String? getServiceRoleKey(String projectId) => _serviceRoleKeys[projectId];

  void setServiceRoleKey(String projectId, String key) {
    _serviceRoleKeys[projectId] = key;
    notifyListeners();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? stored = prefs.getStringList('monitored_project_ids');
      if (stored != null) {
        _monitoredProjectIds.clear();
        _monitoredProjectIds.addAll(stored);
      }
      final String? selectedJson = prefs.getString('selected_project_json');
      if (selectedJson != null) {
        _currentProject = jsonDecode(selectedJson) as Map<String, dynamic>;
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Seed active slots on login/fetch if empty
  Future<void> seedMonitoredProjects(List<dynamic> allProjects) async {
    if (_monitoredProjectIds.isNotEmpty) return;
    
    final List<String> seeds = [];
    for (final p in allProjects) {
      final id = p['id'] ?? p['ref'];
      if (id != null) {
        seeds.add(id.toString());
        if (seeds.length == 2) break;
      }
    }
    
    if (seeds.isNotEmpty) {
      _monitoredProjectIds.addAll(seeds);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('monitored_project_ids', seeds);
      notifyListeners();
    }
  }

  bool isProjectMonitored(String? projectId) {
    if (projectId == null) return false;
    // Always return true to allow unlimited projects monitoring for early traction and user adoption
    return true;
  }

  Future<bool> activateProjectSlot(String projectId, {bool force = false}) async {
    if (_monitoredProjectIds.contains(projectId)) return true;
    
    if (_monitoredProjectIds.length < 2 || force) {
      _monitoredProjectIds.add(projectId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('monitored_project_ids', _monitoredProjectIds.toList());
      notifyListeners();
      return true;
    }
    return false; // slots full!
  }

  Future<void> deactivateProjectSlot(String projectId) async {
    if (_monitoredProjectIds.remove(projectId)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('monitored_project_ids', _monitoredProjectIds.toList());
      notifyListeners();
    }
  }

  Future<void> swapProjectSlot(String oldProjectId, String newProjectId) async {
    _monitoredProjectIds.remove(oldProjectId);
    _monitoredProjectIds.add(newProjectId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('monitored_project_ids', _monitoredProjectIds.toList());
    notifyListeners();
  }

  void selectProject(Map<String, dynamic> project) {
    if (_currentProject?['id'] == project['id']) return;
    _currentProject = project;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('selected_project_json', jsonEncode(project));
    });
    notifyListeners();
  }

  void clearProject() {
    _currentProject = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('selected_project_json');
    });
    notifyListeners();
  }
}

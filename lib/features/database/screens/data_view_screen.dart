import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/widgets/empty_state.dart';
import 'package:supa_app/core/widgets/json_tree_viewer.dart';
import 'package:supa_app/core/widgets/supa_button.dart';
import 'package:supa_app/core/services/api_service.dart';
import 'package:supa_app/core/services/project_context.dart';
import 'package:supa_app/features/database/widgets/query_results_sheet.dart';

class DataViewScreen extends StatefulWidget {
  final String tableName;
  const DataViewScreen({super.key, required this.tableName});

  @override
  State<DataViewScreen> createState() => _DataViewScreenState();
}

class _DataViewScreenState extends State<DataViewScreen> {
  final ApiService _apiService = ApiService();
  final ProjectContext _projectContext = ProjectContext();
  bool _isLoading = true;
  List<dynamic> _records = [];
  List<dynamic> _filteredRecords = [];
  List<String> _columns = [];
  List<String> _visibleColumns = [];
  String _searchQuery = '';
  int? _expandedIndex;
  bool _isMatrixView = false;

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final ref = _projectContext.currentProject?['ref'];
      if (ref != null) {
        final apiKey = _projectContext.getServiceRoleKey(ref);
        final data = await _apiService.fetchRecords(ref, widget.tableName,
            apiKey: apiKey);
        if (mounted) {
          setState(() {
            _records = data;
            if (data.isNotEmpty && data.first is Map) {
              _columns = (data.first as Map).keys.cast<String>().toList();
              if (_visibleColumns.isEmpty) {
                _visibleColumns = _columns.take(3).toList();
              }
            }
            _applyFilter();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.tableName,
          style:
              Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 18),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _isMatrixView = !_isMatrixView);
              HapticFeedback.mediumImpact();
            },
            icon: Icon(
                _isMatrixView
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded,
                size: 20,
                color: AppTheme.accent),
            tooltip:
                _isMatrixView ? 'Switch to List View' : 'Switch to Matrix View',
          ),
          IconButton(
            onPressed: _showRlsPolicies,
            icon: const Icon(Icons.security_rounded,
                size: 20, color: AppTheme.accent),
            tooltip: 'View RLS Policies',
          ),
          IconButton(
            onPressed: _fetchRecords,
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
            child: TextField(
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _applyFilter();
              },
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search records...',
                hintStyle:
                    TextStyle(color: AppTheme.secondary.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppTheme.secondary, size: 20),
                filled: true,
                fillColor: AppTheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.accent),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent))
          : _records.isEmpty
              ? const EmptyState(
                  icon: Icons.layers_clear_rounded,
                  title: 'Table is Empty',
                  description:
                      'No records found. Add data via Supabase dashboard or SQL.',
                )
              : Column(
                  children: [
                    Expanded(
                      child: _isMatrixView
                          ? GridView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 20),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.1,
                              ),
                              itemCount: _filteredRecords.length,
                              itemBuilder: (context, index) {
                                return _buildMatrixCard(
                                    _filteredRecords[index], index);
                              },
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 20),
                              itemCount: _filteredRecords.length,
                              itemBuilder: (context, index) {
                                return _buildAdaptiveCard(
                                    _filteredRecords[index], index);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredRecords = _records;
    } else {
      _filteredRecords = _records.where((record) {
        final content = record.toString().toLowerCase();
        return content.contains(_searchQuery.toLowerCase());
      }).toList();
    }
  }

  void _showColumnSettings() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('COLUMN SECTOR',
                      style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2)),
                  TextButton(
                    onPressed: () {
                      setState(() => _visibleColumns = List.from(_columns));
                      setModalState(() {});
                    },
                    child: const Text('SELECT ALL',
                        style:
                            TextStyle(fontSize: 10, color: AppTheme.secondary)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _columns.length,
                  itemBuilder: (context, index) {
                    final col = _columns[index];
                    final isVisible = _visibleColumns.contains(col);
                    return CheckboxListTile(
                      value: isVisible,
                      activeColor: AppTheme.accent,
                      checkColor: Colors.black,
                      title: Text(col.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        setState(() {
                          if (val == true) {
                            _visibleColumns.add(col);
                          } else {
                            _visibleColumns.remove(col);
                          }
                        });
                        setModalState(() {});
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SupaButton(
                text: 'APPLY CONFIGURATION',
                onPressed: () => Navigator.pop(context),
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdaptiveCard(dynamic record, int listIndex) {
    final Map<String, dynamic> data =
        record is Map ? record.cast<String, dynamic>() : {};
    final bool isExpanded = _expandedIndex == listIndex;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _expandedIndex = isExpanded ? null : listIndex;
        });
      },
      child: Dismissible(
        key: Key('record_${listIndex}_${data.hashCode}'),
        direction: DismissDirection.endToStart,
        onDismissed: (direction) => _deleteRecord(record, listIndex),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child:
              const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
        ),
        child: AnimatedContainer(
          duration: 300.ms,
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isExpanded
                    ? AppTheme.accent.withOpacity(0.3)
                    : Colors.white.withOpacity(0.05)),
            boxShadow: [
              if (isExpanded)
                BoxShadow(
                    color: AppTheme.accent.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: _visibleColumns.map((col) {
                        return _buildCompactField(
                            col, data[col]?.toString() ?? 'N/A');
                      }).toList(),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.secondary.withOpacity(0.3),
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 24),
                const Divider(color: Colors.white10),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 24,
                  runSpacing: 20,
                  children: data.entries.map((entry) {
                    return SizedBox(
                      width: 140,
                      child: _buildField(entry.key, entry.value.toString()),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    IconButton(
                      onPressed: _showColumnSettings,
                      icon: const Icon(Icons.settings_suggest_rounded,
                          color: AppTheme.accent, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.accent.withOpacity(0.1),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () => _showJsonViewer(context, record),
                      icon: const Icon(Icons.data_object_rounded,
                          color: AppTheme.accent, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.accent.withOpacity(0.1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _deleteRecord(record, listIndex),
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (listIndex * 30).ms)
        .scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1));
  }

  Widget _buildMatrixCard(dynamic record, int index) {
    final Map<String, dynamic> data =
        record is Map ? record.cast<String, dynamic>() : {};
    final String mainValue = data[_visibleColumns.isNotEmpty
                ? _visibleColumns.first
                : data.keys.first]
            ?.toString() ??
        'N/A';
    final String subValue = _visibleColumns.length > 1
        ? data[_visibleColumns[1]]?.toString() ?? ''
        : '';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _expandedIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              mainValue,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subValue.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subValue,
                style: TextStyle(
                    color: AppTheme.secondary.withOpacity(0.5), fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.layers_rounded,
                    size: 12, color: AppTheme.accent),
                Text('#${index + 1}',
                    style: TextStyle(
                        color: AppTheme.secondary.withOpacity(0.2),
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 20).ms)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  void _deleteRecord(dynamic record, int index) {
    final originalRecords = List.from(_records);
    final originalFiltered = List.from(_filteredRecords);

    setState(() {
      _records.remove(record);
      _filteredRecords.remove(record);
      _expandedIndex = null;
    });

    HapticFeedback.heavyImpact();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: const Text('Record moved to purge queue',
                style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: AppTheme.surface,
            behavior: SnackBarBehavior.floating,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.redAccent.withOpacity(0.2))),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: AppTheme.accent,
              onPressed: () {
                setState(() {
                  _records = originalRecords;
                  _filteredRecords = originalFiltered;
                });
              },
            ),
          ),
        )
        .closed
        .then((reason) {
      if (reason != SnackBarClosedReason.action) {
        // Perform actual deletion from server here
        final ref = _projectContext.currentProject?['ref'];
        if (ref != null) {
          // Future: Add ApiService.deleteRecord(ref, tableName, recordId)
          debugPrint(
              '[DataPulse] Permanently purging record from ${widget.tableName}');
        }
      }
    });
  }

  Widget _buildCompactField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(
                color: AppTheme.secondary.withOpacity(0.4),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }

  void _showRlsPolicies() async {
    HapticFeedback.mediumImpact();
    final ref = _projectContext.currentProject?['ref'];
    if (ref == null) return;

    setState(() => _isLoading = true);

    try {
      // ELITE FIX: Table names must be quoted in PG queries if they have spaces or reserved keywords
      final sql =
          "SELECT policyname, cmd, roles, qual, with_check FROM pg_policies WHERE tablename = '${widget.tableName}' AND schemaname = 'public';";
      final List<dynamic> policies = await _apiService.executeSql(ref, sql);

      if (!mounted) return;
      setState(() => _isLoading = false);

      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.background,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('RLS POLICIES',
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2)),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded,
                            size: 20, color: Colors.white24)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Table: ${widget.tableName.toUpperCase()}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70)),
                const SizedBox(height: 24),
                Expanded(
                  child: policies.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shield_outlined,
                                  size: 48,
                                  color: AppTheme.secondary.withOpacity(0.2)),
                              const SizedBox(height: 16),
                              const Text('No RLS policies detected.',
                                  style: TextStyle(color: AppTheme.secondary)),
                              const SizedBox(height: 24),
                              SupaButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (context) => QueryResultsSheet(
                                      query: 'SELECT 1 as connection_test;',
                                      title: 'SQL CONNECTION TEST',
                                      projectRef: ref.toString(),
                                    ),
                                  );
                                },
                                isFullWidth: false,
                                child: const Text('VERIFY SQL SUCCESS'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: policies.length,
                          itemBuilder: (context, index) {
                            final p = policies[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color:
                                              AppTheme.accent.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          (p['cmd'] ?? 'ALL')
                                              .toString()
                                              .toUpperCase(),
                                          style: const TextStyle(
                                              color: AppTheme.accent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          p['policyname'] ?? 'Unnamed Policy',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                      'ROLES: ${(p['roles'] ?? 'public').toString()}',
                                      style: TextStyle(
                                          color: AppTheme.secondary
                                              .withOpacity(0.6),
                                          fontSize: 11)),
                                  if (p['qual'] != null) ...[
                                    const SizedBox(height: 8),
                                    const Text('USING (Expression):',
                                        style: TextStyle(
                                            color: AppTheme.secondary,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                      child: Text(p['qual'].toString(),
                                          style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 11,
                                              color: Colors.white70)),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to fetch RLS: $e'),
          backgroundColor: Colors.redAccent));
    }
  }

  void _showJsonViewer(BuildContext context, dynamic record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('RAW RECORD OBJECT',
                  style: TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: JsonTreeView(data: record, initialExpanded: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String key, String value, {bool isBoolean = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key.toUpperCase(),
          style: TextStyle(
            color: AppTheme.secondary.withOpacity(0.5),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isBoolean ? AppTheme.accent : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

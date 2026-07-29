import 'package:flutter/material.dart';
import 'package:supa_app/core/theme/app_theme.dart';

class JsonTreeView extends StatefulWidget {
  final dynamic data;
  final String? label;
  final bool initialExpanded;

  const JsonTreeView({
    super.key,
    required this.data,
    this.label,
    this.initialExpanded = false,
  });

  @override
  State<JsonTreeView> createState() => _JsonTreeViewState();
}

class _JsonTreeViewState extends State<JsonTreeView> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data is Map) {
      return _buildMapNode(widget.data as Map);
    } else if (widget.data is List) {
      return _buildListNode(widget.data as List);
    } else {
      return _buildLeafNode(widget.data);
    }
  }

  Widget _buildMapNode(Map map) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Row(
            children: [
              Icon(
                _isExpanded
                    ? Icons.arrow_drop_down_rounded
                    : Icons.arrow_right_rounded,
                color: AppTheme.secondary.withOpacity(0.5),
                size: 20,
              ),
              if (widget.label != null) ...[
                Text(
                  widget.label!,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                const Text(': ', style: TextStyle(color: Colors.white54)),
              ],
              Text(
                '{${map.length}}',
                style: TextStyle(
                    color: AppTheme.secondary.withOpacity(0.4),
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: map.entries.map((entry) {
                return JsonTreeView(
                  label: entry.key.toString(),
                  data: entry.value,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildListNode(List list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Row(
            children: [
              Icon(
                _isExpanded
                    ? Icons.arrow_drop_down_rounded
                    : Icons.arrow_right_rounded,
                color: AppTheme.secondary.withOpacity(0.5),
                size: 20,
              ),
              if (widget.label != null) ...[
                Text(
                  widget.label!,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                const Text(': ', style: TextStyle(color: Colors.white54)),
              ],
              Text(
                '[${list.length}]',
                style: TextStyle(
                    color: AppTheme.secondary.withOpacity(0.4),
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: list.asMap().entries.map((entry) {
                return JsonTreeView(
                  label: entry.key.toString(),
                  data: entry.value,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildLeafNode(dynamic value) {
    Color valueColor = Colors.white;
    if (value is String) valueColor = AppTheme.accent;
    if (value is num) valueColor = Colors.orangeAccent;
    if (value is bool) valueColor = Colors.purpleAccent;

    return Padding(
      padding: const EdgeInsets.only(left: 20.0, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null) ...[
            Text(
              widget.label!,
              style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
            const Text(': ', style: TextStyle(color: Colors.white54)),
          ],
          Expanded(
            child: Text(
              value.toString(),
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

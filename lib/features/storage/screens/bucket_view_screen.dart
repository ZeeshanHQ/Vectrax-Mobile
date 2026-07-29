import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supa_app/core/theme/app_theme.dart';
import 'package:supa_app/core/services/api_service.dart';
import 'package:supa_app/core/services/project_context.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BucketViewScreen extends StatefulWidget {
  final String bucketName;
  final String bucketId;

  const BucketViewScreen({
    super.key,
    required this.bucketName,
    required this.bucketId,
  });

  @override
  State<BucketViewScreen> createState() => _BucketViewScreenState();
}

class _BucketViewScreenState extends State<BucketViewScreen> {
  final ApiService _apiService = ApiService();
  final ProjectContext _projectContext = ProjectContext();
  List<dynamic> _files = [];
  bool _isLoading = true;
  String _currentPath = '';
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _fetchFiles();
  }

  Future<void> _fetchFiles() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final ref = _projectContext.currentProject?['ref'];
      if (ref != null) {
        // Ensure prefix ends with / if not empty to avoid folder loops/misinterpretation
        final queryPath = _currentPath.isEmpty ? '' : '$_currentPath/';
        final data = await _apiService.listFiles(ref, widget.bucketId,
            prefix: queryPath);

        if (mounted) {
          setState(() {
            // Filter out the folder itself if returned as an object
            // Supabase list returns objects with names relative to the bucket or prefix.
            // When listing folder "A/", it might return an object called "A" or "A/".
            final lastFolderName = _currentPath.split('/').last;
            _files = data.where((f) {
              final name = f['name'];
              if (name == null) return false;
              // Skip if name is exactly the folder we are inside
              if (name == lastFolderName || name == '$lastFolderName/')
                return false;
              // Skip empty names
              if (name == '' || name == '.') return false;
              return true;
            }).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateInto(String folderName) {
    setState(() {
      _currentPath =
          _currentPath.isEmpty ? folderName : '$_currentPath/$folderName';
      _fetchFiles();
    });
    HapticFeedback.mediumImpact();
  }

  void _navigateBack() {
    if (_currentPath.isEmpty) return;
    final parts = _currentPath.split('/');
    setState(() {
      if (parts.length == 1) {
        _currentPath = '';
      } else {
        _currentPath = parts.sublist(0, parts.length - 1).join('/');
      }
      _fetchFiles();
    });
    HapticFeedback.mediumImpact();
  }

  void _navigateToPath(String path) {
    setState(() {
      _currentPath = path;
      _fetchFiles();
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: _currentPath.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: _navigateBack)
            : null,
        title: Text(widget.bucketName,
            style: Theme.of(context)
                .textTheme
                .displayMedium
                ?.copyWith(fontSize: 18)),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
              HapticFeedback.selectionClick();
            },
            icon: Icon(
                _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                size: 20,
                color: AppTheme.accent),
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _fetchFiles();
            },
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildBreadcrumbs(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent))
          : _files.isEmpty
              ? _buildEmptyState()
              : _isGridView
                  ? _buildGalleryView()
                  : _buildListView(),
    );
  }

  Widget _buildBreadcrumbs() {
    final parts = _currentPath.split('/').where((s) => s.isNotEmpty).toList();
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerLeft,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildBreadcrumbItem('root', '', isLast: parts.isEmpty),
          ...List.generate(parts.length, (index) {
            final path = parts.sublist(0, index + 1).join('/');
            return _buildBreadcrumbItem(parts[index], path,
                isLast: index == parts.length - 1);
          }),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbItem(String label, String path,
      {bool isLast = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != 'root')
          Icon(Icons.chevron_right_rounded,
              size: 16, color: Colors.white.withOpacity(0.2)),
        GestureDetector(
          onTap: isLast ? null : () => _navigateToPath(path),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: isLast ? AppTheme.accent : Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      itemCount: _files.length,
      itemBuilder: (context, index) => _buildFileRow(_files[index], index),
    );
  }

  Widget _buildGalleryView() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _files.length,
      itemBuilder: (context, index) => _buildGalleryItem(_files[index], index),
    );
  }

  Widget _buildGalleryItem(dynamic file, int index) {
    final name = file['name'] ?? 'Unknown';
    final metadata = file['metadata'] ?? {};
    final mimetype = metadata['mimetype'] ?? '';
    final isFolder = file['id'] == null;
    final isImage = mimetype.startsWith('image/');

    final ref = _projectContext.currentProject?['ref'];
    final fullPath = _currentPath.isEmpty ? name : '$_currentPath/$name';
    final publicUrl = isImage && ref != null
        ? 'https://$ref.supabase.co/storage/v1/object/public/${widget.bucketId}/$fullPath'
        : null;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (isFolder) {
          _navigateInto(name);
        } else {
          _showFileDetails(file);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
                image: (isImage && publicUrl != null)
                    ? DecorationImage(
                        image: NetworkImage(publicUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (!isImage || publicUrl == null)
                  ? Center(
                      child: Icon(
                        isFolder
                            ? Icons.folder_copy_rounded
                            : _getFileIcon(mimetype),
                        color: AppTheme.accent.withOpacity(0.5),
                        size: 32,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              isFolder ? 'FOLDER' : _formatBytes(metadata['size'] ?? 0),
              style: TextStyle(
                  color: AppTheme.secondary.withOpacity(0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      )
          .animate()
          .fadeIn(delay: (index * 30).ms)
          .scale(begin: const Offset(0.9, 0.9)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 64, color: AppTheme.secondary.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text('EMPTY SECTOR',
              style: TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
          const SizedBox(height: 8),
          const Text('No objects detected in this path.',
              style: TextStyle(color: AppTheme.secondary, fontSize: 13)),
          if (_currentPath.isNotEmpty) ...[
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _navigateBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('GO BACK'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
            ),
          ]
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildFileRow(dynamic file, int index) {
    final name = file['name'] ?? 'Unknown';
    final metadata = file['metadata'] ?? {};
    final size = metadata['size'] ?? 0;
    final mimetype = metadata['mimetype'] ?? '';
    final isFolder = file['id'] == null;

    final ref = _projectContext.currentProject?['ref'];
    final fullPath = _currentPath.isEmpty ? name : '$_currentPath/$name';
    final isImage = mimetype.startsWith('image/');
    final publicUrl = isImage && ref != null
        ? 'https://$ref.supabase.co/storage/v1/object/public/${widget.bucketId}/$fullPath'
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: isFolder
              ? const Icon(Icons.folder_rounded,
                  color: AppTheme.accent, size: 24)
              : (isImage && publicUrl != null)
                  ? Image.network(
                      publicUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Icon(_getFileIcon(mimetype),
                          color: AppTheme.accent, size: 20),
                    )
                  : Icon(_getFileIcon(mimetype),
                      color: AppTheme.accent, size: 20),
        ),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            overflow: TextOverflow.ellipsis),
        subtitle: isFolder
            ? Text('FOLDER',
                style: TextStyle(
                    color: AppTheme.accent.withOpacity(0.5),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1))
            : Text(_formatBytes(size),
                style: TextStyle(
                    color: AppTheme.secondary.withOpacity(0.5), fontSize: 11)),
        trailing: const Icon(Icons.more_vert_rounded,
            color: Colors.white10, size: 18),
        onTap: () {
          HapticFeedback.lightImpact();
          if (isFolder) {
            _navigateInto(name);
          } else {
            _showFileDetails(file);
          }
        },
      ),
    ).animate().fadeIn(delay: (index * 40).ms).slideX(begin: 0.1, end: 0);
  }

  void _showFileDetails(dynamic file) {
    final name = file['name'] ?? 'Unknown';
    final metadata = file['metadata'] ?? {};
    final mimetype = metadata['mimetype'] ?? 'application/octet-stream';
    final size = metadata['size'] ?? 0;
    final created = file['created_at'] ?? 'N/A';

    final ref = _projectContext.currentProject?['ref'];
    final fullPath = _currentPath.isEmpty ? name : '$_currentPath/$name';
    final isImage = mimetype.startsWith('image/');
    final publicUrl = ref != null
        ? 'https://$ref.supabase.co/storage/v1/object/public/${widget.bucketId}/$fullPath'
        : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ListView(
            controller: scrollController,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 32),
              if (isImage && publicUrl != null)
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    image: DecorationImage(
                        image: NetworkImage(publicUrl), fit: BoxFit.cover),
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.accent.withOpacity(0.2),
                          blurRadius: 40,
                          offset: const Offset(0, 20))
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(_getFileIcon(mimetype),
                      size: 48, color: AppTheme.accent),
                ),
              const SizedBox(height: 32),
              const Text('OBJECT DATA',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
              const SizedBox(height: 12),
              Text(name,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 32),
              Row(
                children: [
                  _buildInfoChip(Icons.data_usage_rounded, _formatBytes(size)),
                  const SizedBox(width: 12),
                  _buildInfoChip(Icons.timer_rounded, created.split('T').first),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white10),
              const SizedBox(height: 24),
              _buildDetailRow('MIMETYPE', mimetype),
              _buildDetailRow('BUCKET ID', widget.bucketId),
              _buildDetailRow('FULL PATH', '/$fullPath'),
              if (publicUrl != null) ...[
                const SizedBox(height: 16),
                Text('PUBLIC URL',
                    style: TextStyle(
                        color: AppTheme.secondary.withOpacity(0.5),
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: publicUrl));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('URL copied to clipboard!')));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.05))),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(publicUrl,
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: Colors.white60),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                        const Icon(Icons.copy_rounded,
                            size: 14, color: AppTheme.accent),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surface,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('DISMISS'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () {}, // Future: Delete File
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.accent),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppTheme.secondary.withOpacity(0.5),
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontSize: 14, color: Colors.white70)),
        ],
      ),
    );
  }

  IconData _getFileIcon(String mimetype) {
    if (mimetype.contains('image')) return Icons.image_rounded;
    if (mimetype.contains('video')) return Icons.videocam_rounded;
    if (mimetype.contains('audio')) return Icons.audiotrack_rounded;
    if (mimetype.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (mimetype.contains('zip')) return Icons.folder_zip_rounded;
    return Icons.insert_drive_file_rounded;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return "${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}";
  }
}

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:campuslink/core/api/api_client.dart';
import 'package:campuslink/core/theme/app_theme.dart';

// Warm palette
const _cream  = Color(0xFFFFF8F0);
const _orange = Color(0xFFFF7A00);
const _card   = Colors.white;
const _border = Color(0xFFF0E8DC);
const _txt1   = Color(0xFF1A1A1A);
const _txt2   = Color(0xFF8A7060);
const _txt3   = Color(0xFFBBAA99);

final documentsProvider = FutureProvider<List>((ref) async {
  final res = await ApiClient.instance.get('/documents');
  return res.data as List;
});

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  String _filter = 'All';
  final _filters = ['All', 'PDF', 'DOCX', 'PPTX'];

  String _fixUrl(String url) => url.replaceAll(
      'http://185.194.219.112:9000/campuslink-files',
      'http://185.194.219.112/files');

  Future<void> _open(Map<String, dynamic> doc) async {
    final url   = _fixUrl(doc['file_url'] as String? ?? '');
    final type  = (doc['file_type'] as String? ?? 'pdf').toLowerCase();
    final title = doc['title'] as String? ?? 'Document';
    if (url.isEmpty) return;

    if (type == 'pdf') {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => _PdfViewer(url: url, title: title)));
    } else {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('No app found to open this file')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(documentsProvider);

    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Column(
          children: [

            // ── Header ───────────────────────────────────
            Container(
              color: _card,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Documents',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: _txt1)),
                        SizedBox(height: 1),
                        Text('Your study materials',
                            style: TextStyle(fontSize: 12, color: _txt2)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _orange,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _orange.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.upload_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // ── Search ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8, offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.search_rounded, size: 18, color: _txt3),
                    const SizedBox(width: 10),
                    Text('Search documents…',
                        style: TextStyle(fontSize: 13, color: _txt3)),
                  ],
                ),
              ),
            ),

            // ── Filter chips ─────────────────────────────
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _filters.map((f) {
                  final active = f == _filter;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: active ? _orange : _card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: active ? _orange : _border),
                        boxShadow: active
                            ? [BoxShadow(
                                color: _orange.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: Text(f,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : _txt2,
                          )),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // ── List ─────────────────────────────────────
            Expanded(
              child: docs.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: _orange)),
                error: (_, __) => Center(
                  child: Text('Failed to load',
                      style: TextStyle(color: _txt2)),
                ),
                data: (list) {
                  final filtered = _filter == 'All'
                      ? list
                      : list
                          .where((d) =>
                              (d['file_type'] as String? ?? '')
                                  .toUpperCase() == _filter)
                          .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              color: _orange.withOpacity(0.10),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.description_outlined,
                                size: 36, color: _orange),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _filter == 'All'
                                ? 'No documents yet'
                                : 'No $_filter files',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _txt1),
                          ),
                          const SizedBox(height: 6),
                          Text('Upload your first document',
                              style:
                                  TextStyle(fontSize: 13, color: _txt2)),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: _orange,
                    onRefresh: () =>
                        ref.refresh(documentsProvider.future),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final doc = filtered[i] as Map<String, dynamic>;
                        return _DocCard(
                          doc: doc,
                          onOpen: () => _open(doc),
                          onMore: () => _showOptions(context, doc),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, Map<String, dynamic> doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(doc['title'] as String? ?? 'Document',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _txt1)),
            const SizedBox(height: 16),
            _OptionTile(
                icon: Icons.open_in_new_rounded,
                label: 'Open',
                color: _orange,
                onTap: () { Navigator.pop(context); _open(doc); }),
            _OptionTile(
                icon: Icons.download_rounded,
                label: 'Download',
                color: const Color(0xFF3B82F6),
                onTap: () => Navigator.pop(context)),
            _OptionTile(
                icon: Icons.share_rounded,
                label: 'Share',
                color: const Color(0xFF10B981),
                onTap: () => Navigator.pop(context)),
            _OptionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: Colors.red,
                onTap: () => Navigator.pop(context),
                destructive: true),
          ],
        ),
      ),
    );
  }
}

// ── Doc card ──────────────────────────────────────────────
class _DocCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onOpen, onMore;
  const _DocCard(
      {required this.doc, required this.onOpen, required this.onMore});

  static const _typeColors = {
    'pdf': Color(0xFFEF4444),
    'docx': Color(0xFF3B82F6),
    'pptx': Color(0xFFF59E0B),
  };

  @override
  Widget build(BuildContext context) {
    final type  = (doc['file_type'] as String? ?? 'pdf').toLowerCase();
    final title = doc['title'] as String? ?? 'Untitled';
    final tag   = doc['course_tag'] as String? ?? '';
    final color = _typeColors[type] ?? _orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.description_rounded, size: 22, color: color),
              Text(type.toUpperCase(),
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ],
          ),
        ),
        title: Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _txt1),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: tag.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(tag,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _orange)),
                    ),
                  ],
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onOpen,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _orange.withOpacity(0.2)),
                ),
                child: const Icon(Icons.open_in_new_rounded,
                    size: 16, color: _orange),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onMore,
              child: Icon(Icons.more_vert_rounded, size: 20, color: _txt3),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Option tile ───────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool destructive;
  const _OptionTile({
    required this.icon, required this.label,
    required this.color, required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _border))),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: destructive ? Colors.red : _txt1)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, size: 18, color: _txt3),
        ],
      ),
    ),
  );
}

// ── PDF Viewer ────────────────────────────────────────────
class _PdfViewer extends StatefulWidget {
  final String url, title;
  const _PdfViewer({required this.url, required this.title});
  @override
  State<_PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<_PdfViewer> {
  String? _path;
  String? _error;
  double  _progress = 0;
  int _page = 0, _total = 0;
  PDFViewController? _ctrl;

  @override
  void initState() { super.initState(); _download(); }

  Future<void> _download() async {
    try {
      final dir  = await getTemporaryDirectory();
      final name = widget.url.split('/').last.split('?').first;
      final file = File('${dir.path}/$name');
      if (!file.existsSync()) {
        await Dio().download(widget.url, file.path,
            onReceiveProgress: (r, t) {
          if (t > 0 && mounted) setState(() => _progress = r / t);
        });
      }
      if (mounted) setState(() => _path = file.path);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: _txt1),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _txt1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            if (_total > 0)
              Text('Page ${_page + 1} of $_total',
                  style: TextStyle(fontSize: 11, color: _txt2)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, color: _orange),
            onPressed: () => launchUrl(Uri.parse(widget.url),
                mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      body: Stack(
        children: [
          // PDF
          if (_path != null && _error == null)
            PDFView(
              filePath: _path!,
              enableSwipe: true,
              autoSpacing: true,
              pageFling: true,
              fitPolicy: FitPolicy.BOTH,
              onRender: (p) => setState(() => _total = p ?? 0),
              onViewCreated: (c) => _ctrl = c,
              onPageChanged: (p, _) => setState(() => _page = p ?? 0),
              onError: (e) => setState(() => _error = e.toString()),
            ),

          // Loading
          if (_path == null && _error == null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 72, height: 72,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          color: _orange,
                          strokeWidth: 4,
                          backgroundColor: _orange.withOpacity(0.12),
                        ),
                        if (_progress > 0)
                          Center(
                            child: Text(
                              '${(_progress * 100).toInt()}%',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _txt1),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _progress > 0 ? 'Downloading…' : 'Preparing…',
                    style: TextStyle(fontSize: 13, color: _txt2),
                  ),
                ],
              ),
            ),

          // Error
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.error_outline_rounded,
                          size: 32, color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    const Text("Couldn't open document",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _txt1)),
                    const SizedBox(height: 8),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: _txt2)),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _error = null;
                              _progress = 0;
                            });
                            _download();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: _orange,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                    color: _orange.withOpacity(0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3)),
                              ],
                            ),
                            child: const Text('Try again',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => launchUrl(Uri.parse(widget.url),
                              mode: LaunchMode.externalApplication),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                            ),
                            child: const Text('Open in browser',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _txt1)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Page nav
          if (_path != null && _total > 1 && _error == null)
            Positioned(
              bottom: 24, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_page > 0) _ctrl?.setPage(_page - 1);
                        },
                        child: const Icon(Icons.chevron_left_rounded,
                            color: _txt1, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Text('${_page + 1} / $_total',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _txt1)),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          if (_page < _total - 1)
                            _ctrl?.setPage(_page + 1);
                        },
                        child:
                            const Icon(Icons.chevron_right_rounded,
                                color: _txt1, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
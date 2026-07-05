import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:campuslink/core/api/api_client.dart';
import 'package:campuslink/core/auth/auth_provider.dart';
import 'package:campuslink/core/theme/app_theme.dart';
import 'group_info_screen.dart';

// ─────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────
const _bg       = Color(0xFF141414);
const _surface  = Color(0xFF1E1E1E);
const _surface2 = Color(0xFF252525);
const _divider  = Color(0xFF2A2A2A);
const _hint     = Color(0xFF666666);
const _txtSub   = Color(0xFF888888);

// ─────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────
class ChatRoomScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> room;
  const ChatRoomScreen({super.key, required this.room});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages   = <Map<String, dynamic>>[];
  final _picker     = ImagePicker();
  final _recorder   = AudioRecorder();

  WebSocketChannel? _ws;
  bool _loading    = true;
  bool _isAdmin    = false;
  bool _canChat    = true;
  bool _recording  = false;
  int  _recSeconds = 0;
  Timer? _recTimer;
  String? _recPath;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _connectWS();
    _checkPermissions();
  }

  // ── Data loading ────────────────────────────────────────
  Future<void> _loadMessages() async {
    try {
      final res = await ApiClient.instance
          .get('/chat/rooms/${widget.room['id']}/messages');
      final list = (res.data as List).reversed.toList();
      setState(() {
        _messages.addAll(list.cast<Map<String, dynamic>>());
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _checkPermissions() {
    final userId    = ref.read(authProvider).user?['id'];
    final createdBy = widget.room['created_by'];
    final type      = widget.room['group_type'] as String?;
    _isAdmin = userId == createdBy;
    _canChat = type == 'club' ? _isAdmin : true;
  }

  // ── WebSocket ────────────────────────────────────────────
  void _connectWS() async {
    final token  = await ApiClient.getToken();
    final wsUrl  =
        '${ApiClient.baseUrl.replaceFirst('http', 'ws')}'
        '/ws/chat/${widget.room['id']}?token=$token';
    try {
      _ws = WebSocketChannel.connect(Uri.parse(wsUrl));
      _ws!.stream.listen((data) {
        final msg = jsonDecode(data as String) as Map<String, dynamic>;
        // Replace optimistic message if exists
        setState(() {
          final idx = _messages.indexWhere(
              (m) => m['pending'] == true && m['content'] == msg['content']);
          if (idx != -1) {
            _messages[idx] = msg;
          } else {
            _messages.add(msg);
          }
        });
        _scrollToBottom();
      });
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send text ────────────────────────────────────────────
  void _sendText() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _ws == null) return;

    // Optimistic
    final optimistic = {
      'id': 'pending-${DateTime.now().millisecondsSinceEpoch}',
      'sender_id': ref.read(authProvider).user?['id'] ?? '',
      'sender_name': ref.read(authProvider).user?['full_name'] ?? '',
      'content': text,
      'sent_at': DateTime.now().toIso8601String(),
      'pending': true,
    };
    setState(() => _messages.add(optimistic));
    _ws!.sink.add(text);
    _inputCtrl.clear();
    _scrollToBottom();
  }

  // ── Upload helper ────────────────────────────────────────
  Future<void> _upload(File file, String type) async {
    final fixUrl = (String u) =>
        u.replaceAll('http://185.194.219.112:9000/campuslink-files',
            'http://185.194.219.112/files');

    // Optimistic placeholder
    final optimistic = {
      'id': 'pending-${DateTime.now().millisecondsSinceEpoch}',
      'sender_id': ref.read(authProvider).user?['id'] ?? '',
      'sender_name': ref.read(authProvider).user?['full_name'] ?? '',
      'content': type == 'image'
          ? '🖼️ Shared an image: uploading — uploading'
          : type == 'voice'
          ? '🎤 Voice note: uploading'
          : '📎 Shared a file: ${file.path.split('/').last} — uploading',
      'sent_at': DateTime.now().toIso8601String(),
      'pending': true,
    };
    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path,
            filename: file.path.split('/').last),
        if (type == 'file') 'title': file.path.split('/').last,
        if (type == 'file') 'is_public': 'true',
      });

      final endpoint =
          type == 'file' ? '/documents/upload' : '/documents/media';
      final res = await ApiClient.instance.post(endpoint, data: form);
      final data = res.data as Map<String, dynamic>;
      final fileUrl = fixUrl(data['file_url'] as String);

      String content;
      if (type == 'image') {
        content = '🖼️ Shared an image: ${data['title']} — $fileUrl';
      } else if (type == 'voice') {
        content = '🎤 Voice note: $fileUrl';
      } else {
        content = '📎 Shared a file: ${data['title']} — $fileUrl';
      }

      _ws?.sink.add(content);
      setState(() {
        final idx = _messages.indexOf(optimistic);
        if (idx != -1) {
          _messages[idx] = {...optimistic, 'content': content, 'pending': false};
        }
      });
    } catch (_) {
      setState(() {
        final idx = _messages.indexOf(optimistic);
        if (idx != -1) _messages[idx] = {...optimistic, 'failed': true, 'pending': false};
      });
    }
  }

  // ── Pick image ───────────────────────────────────────────
  Future<void> _pickImage() async {
    Navigator.pop(context);
    final xfile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile == null) return;
    await _upload(File(xfile.path), 'image');
  }

  Future<void> _takePhoto() async {
    Navigator.pop(context);
    final xfile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (xfile == null) return;
    await _upload(File(xfile.path), 'image');
  }

  // ── Record voice ─────────────────────────────────────────
  Future<void> _startRecording() async {
    final perm = await Permission.microphone.request();
    if (!perm.isGranted) return;
    final dir  = await getTemporaryDirectory();
    _recPath   = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: _recPath!);
    setState(() { _recording = true; _recSeconds = 0; });
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recSeconds++);
    });
  }

  Future<void> _stopRecording() async {
    _recTimer?.cancel();
    await _recorder.stop();
    setState(() => _recording = false);
    if (_recPath != null) {
      await _upload(File(_recPath!), 'voice');
    }
  }

  void _cancelRecording() async {
    _recTimer?.cancel();
    await _recorder.stop();
    setState(() => _recording = false);
  }

  String _fmtTime(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  // ── Attach sheet ─────────────────────────────────────────
  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: _hint, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AttachOption(icon: Icons.image_rounded,   label: 'Gallery',    color: AppColors.primary, onTap: _pickImage),
                _AttachOption(icon: Icons.camera_rounded,  label: 'Camera',     color: const Color(0xFF10B981), onTap: _takePhoto),
                _AttachOption(icon: Icons.insert_drive_file_rounded, label: 'Document', color: const Color(0xFF3B82F6), onTap: () {
                  Navigator.pop(context);
                  // TODO: file picker
                }),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ws?.sink.close();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _recTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth      = ref.watch(authProvider);
    final userId    = auth.user?['id'];
    final name      = widget.room['name']       as String? ?? 'Chat';
    final groupType = widget.room['group_type'] as String? ?? 'study';
    final isClub    = groupType == 'club';

    return Scaffold(
      backgroundColor: _bg,
      appBar: _AppBar(
        name: name,
        isClub: isClub,
        isAdmin: _isAdmin,
        onBack: () => Navigator.pop(context),
        onInfo: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) =>
                GroupInfoScreen(room: widget.room, isAdmin: _isAdmin))),
        onCall: () => ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Voice call coming soon'))),
        onVideo: () => ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Video call coming soon'))),
        onMore: () => _isAdmin ? _showAdminMenu() : _showMemberMenu(),
      ),
      body: Column(
        children: [
          // Club banner
          if (isClub && !_isAdmin) _ClubBanner(),

          // Messages
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _messages.isEmpty
                ? _EmptyState(isClub: isClub)
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg   = _messages[i];
                      final isMe  = msg['sender_id'] == userId;
                      final prev  = i > 0 ? _messages[i - 1] : null;
                      final showDate = prev == null ||
                          _diffDay(prev['sent_at'] as String?,
                              msg['sent_at'] as String?);
                      final showAvatar = !isMe &&
                          (i == _messages.length - 1 ||
                              _messages[i + 1]['sender_id'] != msg['sender_id']);
                      return Column(
                        children: [
                          if (showDate)
                            _DateChip(date: msg['sent_at'] as String?),
                          _Bubble(
                            msg: msg,
                            isMe: isMe,
                            isClub: isClub,
                            showAvatar: showAvatar,
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Input / recording / locked
          if (_canChat)
            _recording
                ? _RecordingBar(
                    seconds: _recSeconds,
                    onStop: _stopRecording,
                    onCancel: _cancelRecording,
                    fmtTime: _fmtTime,
                  )
                : _InputBar(
                    ctrl: _inputCtrl,
                    onSend: _sendText,
                    onAttach: _showAttachSheet,
                    onMicDown: _startRecording,
                  )
          else
            _LockedBar(),
        ],
      ),
    );
  }

  bool _diffDay(String? a, String? b) {
    if (a == null || b == null) return false;
    final da = DateTime.tryParse(a);
    final db = DateTime.tryParse(b);
    if (da == null || db == null) return false;
    return da.day != db.day || da.month != db.month || da.year != db.year;
  }

  // ── Menus ─────────────────────────────────────────────────
  void _showAdminMenu() {
    _bottomSheet('Admin options', [
      _SheetTile(icon: Icons.image_outlined,               label: 'Change group icon',        onTap: () {}),
      _SheetTile(icon: Icons.edit_outlined,                label: 'Edit name & description',  onTap: () {}),
      _SheetTile(icon: Icons.person_add_outlined,          label: 'Add members',              onTap: () {}),
      _SheetTile(icon: Icons.admin_panel_settings_outlined,label: 'Manage admins',            onTap: () {}),
      _SheetTile(icon: Icons.link_rounded,                 label: 'Invite link settings',     onTap: () {}),
      _SheetTile(icon: Icons.lock_outlined,                label: 'Group permissions',        onTap: () {}),
      _SheetTile(icon: Icons.delete_outline_rounded,       label: 'Delete group',             onTap: () {}, destructive: true),
    ]);
  }

  void _showMemberMenu() {
    _bottomSheet('Options', [
      _SheetTile(icon: Icons.info_outline_rounded,    label: 'Group info',        onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => GroupInfoScreen(room: widget.room, isAdmin: _isAdmin)));
      }),
      _SheetTile(icon: Icons.link_rounded,            label: 'Copy invite link',  onTap: () {
        Clipboard.setData(ClipboardData(
            text: 'campuslink://room/${widget.room['id']}'));
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Link copied')));
      }),
      _SheetTile(icon: Icons.notifications_outlined,  label: 'Mute notifications', onTap: () {}),
      _SheetTile(icon: Icons.exit_to_app_rounded,     label: 'Leave group',        onTap: () {}, destructive: true),
    ]);
  }

  void _bottomSheet(String title, List<Widget> tiles) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: _hint,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 17,
                fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 8),
            ...tiles,
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// AppBar
// ─────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final String name;
  final bool isClub, isAdmin;
  final VoidCallback onBack, onInfo, onCall, onVideo, onMore;

  const _AppBar({
    required this.name, required this.isClub, required this.isAdmin,
    required this.onBack, required this.onInfo,
    required this.onCall, required this.onVideo, required this.onMore,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      color: _surface,
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Colors.white),
            onPressed: onBack,
          ),
          GestureDetector(
            onTap: onInfo,
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: isClub
                        ? const Icon(Icons.campaign_rounded,
                            size: 18, color: AppColors.primary)
                        : Text(
                            name.length >= 2
                                ? name.substring(0, 2).toUpperCase()
                                : name.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800,
                                color: AppColors.primary),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    Text(
                      isClub
                          ? isAdmin ? 'Channel · Admin' : 'Channel'
                          : 'Tap for info',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.45)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          if (!isClub) _IABtn(icon: Icons.videocam_rounded,  onTap: onVideo),
          if (!isClub) _IABtn(icon: Icons.call_rounded,       onTap: onCall),
          _IABtn(icon: Icons.more_vert_rounded, onTap: onMore),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _IABtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IABtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: Colors.white.withOpacity(0.8)),
    ),
  );
}

// ─────────────────────────────────────────────────────────
// Bubble
// ─────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe, isClub, showAvatar;

  const _Bubble({
    required this.msg,
    required this.isMe,
    required this.isClub,
    required this.showAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final content    = msg['content']     as String? ?? '';
    final senderName = msg['sender_name'] as String? ?? '';
    final sentAt     = msg['sent_at']     as String?;
    final pending    = msg['pending']     as bool?   ?? false;
    final failed     = msg['failed']      as bool?   ?? false;

    final time = sentAt != null
        ? TimeOfDay.fromDateTime(DateTime.parse(sentAt)).format(context)
        : '';

    final isImage = content.startsWith('🖼️ Shared an image:');
    final isVoice = content.startsWith('🎤 Voice note:');
    final isFile  = content.startsWith('📎 Shared a file:');

    // Club announcement
    if (isClub && !isMe) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.campaign_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(senderName,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              const Spacer(),
              Text(time, style: TextStyle(fontSize: 10,
                  color: Colors.white.withOpacity(0.3))),
            ]),
            const SizedBox(height: 10),
            Text(content,
                style: TextStyle(fontSize: 14,
                    color: Colors.white.withOpacity(0.9), height: 1.5)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for others
          if (!isMe)
            showAvatar
                ? Container(
                    width: 30, height: 30,
                    margin: const EdgeInsets.only(right: 8, bottom: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Text(
                        senderName.isNotEmpty
                            ? senderName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppColors.primary),
                      ),
                    ),
                  )
                : const SizedBox(width: 38),

          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && showAvatar)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 3),
                    child: Text(senderName,
                        style: TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.4))),
                  ),

                // Content
                Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72),
                  decoration: BoxDecoration(
                    gradient: isMe && !isImage
                        ? LinearGradient(
                            colors: [AppColors.primary,
                              AppColors.primary.withOpacity(0.85)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight)
                        : null,
                    color: isMe ? null : _surface2,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(18),
                      topRight:    const Radius.circular(18),
                      bottomLeft:  Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                  ),
                  child: isImage
                      ? _ImageBubble(content: content, isMe: isMe)
                      : isVoice
                      ? _VoiceBubble(content: content, isMe: isMe)
                      : isFile
                      ? _FileBubble(content: content, isMe: isMe)
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Text(content,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: isMe
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.9),
                                  height: 1.45)),
                        ),
                ),

                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (failed)
                      const Icon(Icons.error_outline_rounded,
                          size: 12, color: Colors.red)
                    else if (pending)
                      Icon(Icons.access_time_rounded,
                          size: 12, color: Colors.white.withOpacity(0.3))
                    else if (isMe)
                      const Icon(Icons.done_all_rounded,
                          size: 13, color: AppColors.primary),
                    const SizedBox(width: 3),
                    Text(time,
                        style: TextStyle(fontSize: 10,
                            color: Colors.white.withOpacity(0.3))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Image bubble
// ─────────────────────────────────────────────────────────
class _ImageBubble extends StatelessWidget {
  final String content;
  final bool isMe;
  const _ImageBubble({required this.content, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final rest    = content.replaceFirst('🖼️ Shared an image: ', '');
    final parts   = rest.split(' — ');
    final url     = parts.length > 1 ? parts[1].split('\n').first : '';
    final caption = rest.contains('\n') ? rest.split('\n').skip(1).join('\n') : '';
    final uploading = url == 'uploading';

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          uploading
              ? Container(
                  width: 200, height: 150,
                  color: _surface2,
                  child: const Center(child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2)))
              : GestureDetector(
                  onTap: () => _openImage(context, url),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    width: 220,
                    height: 180,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                        width: 220, height: 180, color: _surface2,
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary, strokeWidth: 2))),
                    errorWidget: (_, __, ___) => Container(
                        width: 220, height: 180, color: _surface2,
                        child: const Icon(Icons.broken_image_outlined,
                            color: _hint, size: 36)),
                  ),
                ),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Text(caption,
                  style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ),
        ],
      ),
    );
  }

  void _openImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: CachedNetworkImage(imageUrl: url),
              ),
            ),
            Positioned(
              top: 44, right: 16,
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Voice bubble
// ─────────────────────────────────────────────────────────
class _VoiceBubble extends StatefulWidget {
  final String content;
  final bool isMe;
  const _VoiceBubble({required this.content, required this.isMe});
  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final _player = AudioPlayer();
  bool  _playing  = false;
  double _progress = 0;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    final url = widget.content.replaceFirst('🎤 Voice note: ', '');
    if (url != 'uploading') _init(url);
  }

  Future<void> _init(String url) async {
    try {
      await _player.setUrl(url);
      _duration = _player.duration ?? Duration.zero;
      _player.positionStream.listen((p) {
        if (mounted) setState(() {
          _position = p;
          _progress = _duration.inMilliseconds > 0
              ? p.inMilliseconds / _duration.inMilliseconds : 0;
        });
      });
      _player.playerStateStream.listen((s) {
        if (mounted) setState(() => _playing = s.playing);
        if (s.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          _player.pause();
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() { _player.dispose(); super.dispose(); }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final url       = widget.content.replaceFirst('🎤 Voice note: ', '');
    final uploading = url == 'uploading';
    final textColor = widget.isMe ? Colors.white : Colors.white.withOpacity(0.9);
    final subColor  = widget.isMe
        ? Colors.white.withOpacity(0.55)
        : Colors.white.withOpacity(0.4);
    final activeColor = widget.isMe ? Colors.white : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play button
          GestureDetector(
            onTap: uploading ? null : () =>
                _playing ? _player.pause() : _player.play(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withOpacity(0.2)
                    : AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: uploading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2))
                  : Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: activeColor, size: 22),
            ),
          ),
          const SizedBox(width: 10),

          // Waveform + time
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Waveform bars
              SizedBox(
                width: 130,
                height: 28,
                child: uploading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(24, (i) => Container(
                          width: 3, height: 8 + (i % 4) * 4.0,
                          decoration: BoxDecoration(
                            color: subColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )),
                      )
                    : GestureDetector(
                        onTapDown: (d) {
                          final pct = d.localPosition.dx / 130;
                          _player.seek(Duration(
                              milliseconds:
                                  (_duration.inMilliseconds * pct).toInt()));
                        },
                        child: CustomPaint(
                          painter: _WaveformPainter(
                            progress: _progress,
                            activeColor: activeColor,
                            inactiveColor: subColor,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    uploading ? '0:00' : _fmt(_playing ? _position : _duration),
                    style: TextStyle(fontSize: 10, color: subColor),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final speeds = [1.0, 1.5, 2.0];
                      final next = speeds[
                          (speeds.indexOf(_speed) + 1) % speeds.length];
                      setState(() => _speed = next);
                      _player.setSpeed(next);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: activeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('${_speed}×',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: activeColor)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Waveform painter
class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color activeColor, inactiveColor;
  const _WaveformPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final heights = [6,10,14,8,16,10,6,12,16,8,10,14,6,12,8,16,10,6,14,10,8,12,6,10];
    final barW = size.width / (heights.length * 1.6);
    final gap  = barW * 0.6;

    for (int i = 0; i < heights.length; i++) {
      final x      = i * (barW + gap);
      final h      = heights[i].toDouble();
      final filled = (i / heights.length) <= progress;
      final paint  = Paint()
        ..color = filled ? activeColor : inactiveColor
        ..style = PaintingStyle.fill;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, (size.height - h) / 2, barW, h),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────
// File bubble
// ─────────────────────────────────────────────────────────
class _FileBubble extends StatelessWidget {
  final String content;
  final bool isMe;
  const _FileBubble({required this.content, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final rest      = content.replaceFirst('📎 Shared a file: ', '');
    final parts     = rest.split(' — ');
    final name      = parts.first;
    final url       = parts.length > 1 ? parts[1] : '';
    final uploading = url == 'uploading';
    final ext       = name.split('.').last.toUpperCase();

    final extColors = {
      'PDF': Colors.red, 'DOCX': Colors.blue, 'PPTX': Colors.orange,
    };
    final extColor  = extColors[ext] ?? Colors.grey;
    final textColor = isMe ? Colors.white : Colors.white.withOpacity(0.9);
    final subColor  = isMe
        ? Colors.white.withOpacity(0.55)
        : Colors.white.withOpacity(0.4);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: uploading
                  ? Colors.white.withOpacity(0.1)
                  : extColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: uploading
                ? const Center(child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary)))
                : Center(
                    child: Text(ext,
                        style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: extColor))),
          ),
          const SizedBox(width: 10),

          // Name + action
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  uploading ? 'Uploading…' : name,
                  style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w600, color: textColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                uploading ? 'Please wait' : 'Tap to open',
                style: TextStyle(fontSize: 11, color: subColor),
              ),
            ],
          ),

          // Download icon
          if (!uploading) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                // open with external app
              },
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.download_rounded,
                    size: 16,
                    color: isMe ? Colors.white70 : AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Input bar
// ─────────────────────────────────────────────────────────
class _InputBar extends StatefulWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend, onAttach, onMicDown;
  const _InputBar({required this.ctrl, required this.onSend,
      required this.onAttach, required this.onMicDown});
  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;
  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(() =>
        setState(() => _hasText = widget.ctrl.text.trim().isNotEmpty));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          left: 12, right: 12, top: 10,
          bottom: MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Row(
        children: [
          // Attach
          GestureDetector(
            onTap: widget.onAttach,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.add_rounded,
                  size: 22, color: Colors.white.withOpacity(0.6)),
            ),
          ),
          const SizedBox(width: 8),

          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: _surface2,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: widget.ctrl,
                maxLines: null,
                style: const TextStyle(fontSize: 14, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  hintStyle: TextStyle(
                      fontSize: 14, color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send / Mic
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: _hasText
                ? GestureDetector(
                    key: const ValueKey('send'),
                    onTap: widget.onSend,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(22)),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                    ),
                  )
                : GestureDetector(
                    key: const ValueKey('mic'),
                    onLongPressStart: (_) => widget.onMicDown(),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(22)),
                      child: Icon(Icons.mic_rounded,
                          color: Colors.white.withOpacity(0.6), size: 22),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Recording bar
// ─────────────────────────────────────────────────────────
class _RecordingBar extends StatelessWidget {
  final int seconds;
  final VoidCallback onStop, onCancel;
  final String Function(int) fmtTime;
  const _RecordingBar({required this.seconds, required this.onStop,
      required this.onCancel, required this.fmtTime});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          left: 16, right: 16, top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12),
      color: _surface,
      child: Row(
        children: [
          GestureDetector(
            onTap: onCancel,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(
                color: Colors.red, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(fmtTime(seconds),
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Recording… release to send',
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withOpacity(0.4))),
          ),
          GestureDetector(
            onTap: onStop,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Supporting widgets
// ─────────────────────────────────────────────────────────
class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttachOption({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18)),
          child: Icon(icon, size: 26, color: color),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.6))),
      ],
    ),
  );
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const _SheetTile({required this.icon, required this.label,
      required this.onTap, this.destructive = false});

  @override
  Widget build(BuildContext context) {
    final c = destructive ? Colors.red : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: _divider))),
        child: Row(
          children: [
            Icon(icon, size: 19,
                color: destructive ? Colors.red : Colors.white54),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: c)),
            const Spacer(),
            if (!destructive)
              Icon(Icons.chevron_right_rounded,
                  size: 17, color: Colors.white.withOpacity(0.2)),
          ],
        ),
      ),
    );
  }
}

class _ClubBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    color: AppColors.primary.withOpacity(0.08),
    child: Row(
      children: [
        Icon(Icons.campaign_rounded, size: 15, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text('This is a channel. Only admins can send messages.',
              style: TextStyle(fontSize: 12, color: AppColors.primary,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    ),
  );
}

class _LockedBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(
        left: 20, right: 20, top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 14),
    color: _surface,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, size: 14,
            color: Colors.white.withOpacity(0.3)),
        const SizedBox(width: 6),
        Text('Only admins can send messages in this channel',
            style: TextStyle(
                fontSize: 12, color: Colors.white.withOpacity(0.35))),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final bool isClub;
  const _EmptyState({required this.isClub});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle),
          child: Icon(
              isClub ? Icons.campaign_outlined : Icons.chat_bubble_outline_rounded,
              size: 32, color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        Text(
          isClub ? 'No announcements yet'
              : 'No messages yet\nSay hello! 👋',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14,
              color: Colors.white.withOpacity(0.35), height: 1.5),
        ),
      ],
    ),
  );
}

class _DateChip extends StatelessWidget {
  final String? date;
  const _DateChip({this.date});
  @override
  Widget build(BuildContext context) {
    String label = 'Today';
    if (date != null) {
      final d = DateTime.tryParse(date!);
      if (d != null) {
        final now = DateTime.now();
        if (d.year == now.year && d.month == now.month && d.day == now.day) {
          label = 'Today';
        } else if (d.year == now.year && d.month == now.month &&
            d.day == now.day - 1) {
          label = 'Yesterday';
        } else {
          label = '${d.day}/${d.month}/${d.year}';
        }
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white.withOpacity(0.07))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11, color: Colors.white.withOpacity(0.35))),
            ),
          ),
          Expanded(child: Divider(color: Colors.white.withOpacity(0.07))),
        ],
      ),
    );
  }
}
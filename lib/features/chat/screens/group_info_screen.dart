import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campuslink/core/api/api_client.dart';
import 'package:campuslink/core/auth/auth_provider.dart';
import 'package:campuslink/core/theme/app_theme.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> room;
  final bool isAdmin;

  const GroupInfoScreen({
    super.key,
    required this.room,
    required this.isAdmin,
  });

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _editingDesc = false;
  final _descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadData();
    _descCtrl.text = widget.room['description'] as String? ?? '';
  }

  Future<void> _loadData() async {
    try {
      final res = await ApiClient.instance
          .get('/chat/rooms/${widget.room['id']}/messages',
              queryParameters: {'limit': 100});
      setState(() {
        _messages = (res.data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _mediaMessages => _messages
      .where((m) =>
          (m['content'] as String? ?? '').startsWith('🖼️ Shared an image:'))
      .toList();

  List<Map<String, dynamic>> get _docMessages => _messages
      .where((m) =>
          (m['content'] as String? ?? '').startsWith('📎 Shared a file:'))
      .toList();

  List<Map<String, dynamic>> get _voiceMessages => _messages
      .where((m) =>
          (m['content'] as String? ?? '').startsWith('🎤 Voice note:'))
      .toList();

  List<Map<String, dynamic>> get _linkMessages => _messages.where((m) {
        final content = m['content'] as String? ?? '';
        return content.contains('http://') || content.contains('https://');
      }).toList();

  @override
  void dispose() {
    _tabCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.room['name'] as String? ?? 'Group';
    final groupType = widget.room['group_type'] as String? ?? 'study';
    final isClub = groupType == 'club';
    final desc = widget.room['description'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (widget.isAdmin)
                IconButton(
                  icon: const Icon(Icons.edit_rounded,
                      size: 20, color: AppColors.primary),
                  onPressed: () => _editGroupName(context, name),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _GroupHero(
                name: name,
                isClub: isClub,
                groupType: groupType,
                isAdmin: widget.isAdmin,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabCtrl,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(text: 'Media'),
                    Tab(text: 'Docs'),
                    Tab(text: 'Links'),
                  ],
                ),
              ),
            ),
          ),

          // Description card
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Description',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5)),
                      const Spacer(),
                      if (widget.isAdmin)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _editingDesc = !_editingDesc),
                          child: Text(
                            _editingDesc ? 'Cancel' : 'Edit',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_editingDesc) ...[
                    TextField(
                      controller: _descCtrl,
                      maxLines: 3,
                      maxLength: 200,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Add a group description…',
                        hintStyle:
                            const TextStyle(color: AppColors.textHint),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _editingDesc = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Description updated')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Save',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ] else
                    Text(
                      desc?.isNotEmpty == true
                          ? desc!
                          : widget.isAdmin
                              ? 'Tap Edit to add a description…'
                              : 'No description yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: desc?.isNotEmpty == true
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                        height: 1.5,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Invite link
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  _InfoTile(
                    icon: Icons.link_rounded,
                    label: 'Invite link',
                    subtitle: 'campuslink://room/${widget.room['id']}',
                    onTap: () {
                      Clipboard.setData(ClipboardData(
                          text:
                              'campuslink://room/${widget.room['id']}'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Invite link copied!')),
                      );
                    },
                    trailing: const Icon(Icons.copy_rounded,
                        size: 16, color: AppColors.primary),
                  ),
                  if (widget.isAdmin)
                    _InfoTile(
                      icon: Icons.person_add_outlined,
                      label: 'Add members',
                      onTap: () {},
                    ),
                  if (widget.isAdmin)
                    _InfoTile(
                      icon: Icons.settings_outlined,
                      label: 'Group settings',
                      onTap: () => _showGroupSettings(context),
                    ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            // Media tab
            _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _mediaMessages.isEmpty
                    ? _EmptyMedia(
                        icon: Icons.image_outlined,
                        label: 'No photos or videos yet')
                    : GridView.builder(
                        padding: const EdgeInsets.all(2),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: _mediaMessages.length,
                        itemBuilder: (_, i) {
                          final msg = _mediaMessages[i];
                          final content =
                              msg['content'] as String? ?? '';
                          final url = content
                              .replaceFirst(
                                  '🖼️ Shared an image: ', '')
                              .split(' — ')
                              .last
                              .split('\n')
                              .first;
                          return GestureDetector(
                            onTap: () => _openMedia(context, url),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.surface,
                                child: const Icon(Icons.image_outlined,
                                    color: AppColors.textHint),
                              ),
                            ),
                          );
                        },
                      ),

            // Docs tab
            _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _docMessages.isEmpty
                    ? _EmptyMedia(
                        icon: Icons.description_outlined,
                        label: 'No documents shared yet')
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _docMessages.length,
                        itemBuilder: (_, i) {
                          final msg = _docMessages[i];
                          final content =
                              msg['content'] as String? ?? '';
                          final parts = content
                              .replaceFirst(
                                  '📎 Shared a file: ', '')
                              .split(' — ');
                          final fileName = parts.first;
                          final url =
                              parts.length > 1 ? parts[1] : '';
                          final ext = fileName
                              .split('.')
                              .last
                              .toUpperCase();
                          final extColors = {
                            'PDF': Colors.red,
                            'DOCX': Colors.blue,
                            'PPTX': Colors.orange,
                          };
                          final color =
                              extColors[ext] ?? AppColors.primary;
                          return Container(
                            margin:
                                const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color:
                                        color.withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(
                                            10),
                                  ),
                                  child: Center(
                                    child: Text(ext,
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight:
                                                FontWeight.w800,
                                            color: color)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fileName,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight:
                                                FontWeight.w600,
                                            color: AppColors
                                                .textPrimary),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        msg['sender_name']
                                                as String? ??
                                            '',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors
                                                .textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.download_rounded,
                                      size: 20,
                                      color: AppColors.primary),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          );
                        },
                      ),

            // Links tab
            _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _linkMessages.isEmpty
                    ? _EmptyMedia(
                        icon: Icons.link_outlined,
                        label: 'No links shared yet')
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _linkMessages.length,
                        itemBuilder: (_, i) {
                          final msg = _linkMessages[i];
                          final content =
                              msg['content'] as String? ?? '';
                          final urlMatch = RegExp(
                                  r'https?://[^\s]+')
                              .firstMatch(content);
                          final url = urlMatch?.group(0) ?? '';
                          return Container(
                            margin:
                                const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryTint,
                                    borderRadius:
                                        BorderRadius.circular(
                                            10),
                                  ),
                                  child: const Icon(
                                      Icons.link_rounded,
                                      color: AppColors.primary,
                                      size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        url,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors
                                                .primary,
                                            fontWeight:
                                                FontWeight.w600),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        msg['sender_name']
                                                as String? ??
                                            '',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors
                                                .textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(
                                        ClipboardData(text: url));
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                            content:
                                                Text('Link copied')));
                                  },
                                  child: const Icon(Icons.copy_rounded,
                                      size: 18,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }

  void _openMedia(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
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

  void _editGroupName(BuildContext context, String current) {
    final ctrl = TextEditingController(text: current);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit group name',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(
                  fontSize: 15, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Group name',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Group name updated')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                ),
                child: const Text('Save',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Text('Group settings',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _SettingToggle(
              label: 'Anyone can add members',
              subtitle: 'Members can add new people without admin approval',
              value: true,
              onChanged: (_) {},
            ),
            _SettingToggle(
              label: 'Admin approval to join',
              subtitle:
                  'New members must be approved by an admin via invite link',
              value: false,
              onChanged: (_) {},
            ),
            _SettingToggle(
              label: 'Only admins can send messages',
              subtitle: 'Turns this group into a channel',
              value: widget.room['group_type'] == 'club',
              onChanged: (_) {},
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Group hero (collapsible header) ──────────────────────
class _GroupHero extends StatelessWidget {
  final String name;
  final bool isClub;
  final String groupType;
  final bool isAdmin;

  const _GroupHero({
    required this.name,
    required this.isClub,
    required this.groupType,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          // Group icon
          Stack(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: isClub
                      ? const Color(0xFF06B6D4).withOpacity(0.12)
                      : AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: isClub
                        ? const Color(0xFF06B6D4).withOpacity(0.3)
                        : AppColors.primaryBorder,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isClub
                      ? const Icon(Icons.campaign_rounded,
                          size: 40, color: Color(0xFF06B6D4))
                      : Text(
                          name.length >= 2
                              ? name.substring(0, 2).toUpperCase()
                              : name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                ),
              ),
              if (isAdmin)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isClub
                  ? const Color(0xFF06B6D4).withOpacity(0.1)
                  : AppColors.primaryTint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isClub
                  ? 'Channel'
                  : groupType[0].toUpperCase() + groupType.substring(1),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    isClub ? const Color(0xFF06B6D4) : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Info tile ─────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _InfoTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

// ── Setting toggle ────────────────────────────────────────
class _SettingToggle extends StatefulWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggle({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_SettingToggle> createState() => _SettingToggleState();
}

class _SettingToggleState extends State<_SettingToggle> {
  late bool _val;

  @override
  void initState() {
    super.initState();
    _val = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(widget.subtitle,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.3)),
              ],
            ),
          ),
          Switch(
            value: _val,
            onChanged: (v) {
              setState(() => _val = v);
              widget.onChanged(v);
            },
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// ── Empty media state ─────────────────────────────────────
class _EmptyMedia extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EmptyMedia({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
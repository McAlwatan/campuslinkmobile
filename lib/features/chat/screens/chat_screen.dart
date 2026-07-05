import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campuslink/core/api/api_client.dart';
import 'package:campuslink/core/theme/app_theme.dart';
import 'chat_room_screen.dart';

final roomsProvider = FutureProvider<List>((ref) async {
  final res = await ApiClient.instance.get('/chat/rooms');
  return res.data as List;
});

// Warm palette (matches home)
const _cream   = Color(0xFFFFF8F0);
const _orange  = Color(0xFFFF7A00);
const _card    = Colors.white;
const _border  = Color(0xFFF0E8DC);
const _txt1    = Color(0xFF1A1A1A);
const _txt2    = Color(0xFF8A7060);
const _txt3    = Color(0xFFBBAA99);

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomsProvider);

    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Column(
          children: [

            // ── Header ──────────────────────────────────
            Container(
              color: _card,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Messages',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: _txt1)),
                        SizedBox(height: 1),
                        Text('Your conversations',
                            style: TextStyle(fontSize: 12, color: _txt2)),
                      ],
                    ),
                  ),
                  // New chat button
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
                      child: const Icon(Icons.edit_rounded,
                          color: Colors.white, size: 18),
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
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.search_rounded, size: 18, color: _txt3),
                    const SizedBox(width: 10),
                    Text('Search messages…',
                        style: TextStyle(fontSize: 13, color: _txt3)),
                  ],
                ),
              ),
            ),

            // ── Filter tabs ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  _Tab(label: 'All Chats', active: true, onTap: () {}),
                  const SizedBox(width: 8),
                  _Tab(label: 'Groups', active: false, onTap: () {}),
                  const SizedBox(width: 8),
                  _Tab(label: 'Channels', active: false, onTap: () {}),
                ],
              ),
            ),

            // ── Room list ────────────────────────────────
            Expanded(
              child: rooms.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: _orange)),
                error: (_, __) => Center(
                  child: Text('Failed to load',
                      style: TextStyle(color: _txt2, fontSize: 14)),
                ),
                data: (list) {
                  if (list.isEmpty) return _EmptyChats();
                  return RefreshIndicator(
                    color: _orange,
                    onRefresh: () => ref.refresh(roomsProvider.future),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final room = list[i] as Map<String, dynamic>;
                        return _RoomTile(
                          room: room,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ChatRoomScreen(room: room)),
                          ),
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
}

// ── Filter tab chip ───────────────────────────────────────
class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: active ? _orange : _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? _orange : _border),
        boxShadow: active
            ? [BoxShadow(color: _orange.withOpacity(0.3),
                blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: Text(label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : _txt2,
          )),
    ),
  );
}

// ── Room tile ─────────────────────────────────────────────
class _RoomTile extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onTap;
  const _RoomTile({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name      = room['name'] as String? ?? 'Direct Message';
    final isGroup   = room['is_group'] as bool? ?? false;
    final groupType = room['group_type'] as String? ?? 'study';
    final isClub    = groupType == 'club';

    final initials = name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();

    // Avatar color varies by type
    final avatarColor = isClub
        ? const Color(0xFF06B6D4)
        : isGroup
        ? const Color(0xFF7C5CFC)
        : _orange;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: avatarColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: avatarColor.withOpacity(0.25)),
              ),
              child: Center(
                child: isClub
                    ? Icon(Icons.campaign_rounded,
                        size: 20, color: avatarColor)
                    : Text(initials,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: avatarColor)),
              ),
            ),
            const SizedBox(width: 12),

            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _txt1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: avatarColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          isClub
                              ? 'Channel'
                              : isGroup
                              ? groupType[0].toUpperCase() +
                                  groupType.substring(1)
                              : 'DM',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: avatarColor),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('Tap to open',
                          style:
                              TextStyle(fontSize: 11, color: _txt3)),
                    ],
                  ),
                ],
              ),
            ),

            // Right side
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('now',
                    style: TextStyle(fontSize: 11, color: _txt3)),
                const SizedBox(height: 6),
                Container(
                  width: 9, height: 9,
                  decoration: BoxDecoration(
                    color: _orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: _orange.withOpacity(0.4),
                          blurRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────
class _EmptyChats extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: _orange.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded,
              size: 36, color: _orange),
        ),
        const SizedBox(height: 16),
        const Text('No conversations yet',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _txt1)),
        const SizedBox(height: 6),
        Text('Start chatting with your campus community',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _txt2)),
      ],
    ),
  );
}
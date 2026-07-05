import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campuslink/core/api/api_client.dart';
import 'package:campuslink/core/auth/auth_provider.dart';
import 'package:campuslink/core/theme/app_theme.dart';

final feedProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final results = await Future.wait([
    ApiClient.instance.get('/documents'),
    ApiClient.instance.get('/groups'),
    ApiClient.instance.get('/marketplace/listings'),
    ApiClient.instance.get('/courses'),
  ]);
  return {
    'documents': results[0].data as List,
    'groups': results[1].data as List,
    'listings': results[2].data as List,
    'courses': results[3].data as List,
  };
});

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final feed = ref.watch(feedProvider);
    final firstName = (auth.user?['full_name'] as String? ?? 'there')
        .split(' ')
        .first;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFFF7A00),
          onRefresh: () => ref.refresh(feedProvider.future),
          child: CustomScrollView(
            slivers: [

              // ── Warm header ──────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  color: const Color(0xFFFFF8F0),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting(),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFAA7B50),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              firstName,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A1A1A),
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _TopButton(
                            icon: Icons.notifications_outlined,
                            onTap: () {},
                            hasNotif: true,
                          ),
                          const SizedBox(width: 8),
                          _TopButton(
                            icon: Icons.more_vert_rounded,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── 3 feature blocks (horizontal scroll) ────
              SliverToBoxAdapter(
                child: feed.when(
                  loading: () => const SizedBox(
                    height: 160,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF7A00),
                      ),
                    ),
                  ),
                  error: (_, __) => const SizedBox(height: 160),
                  data: (data) => _FeatureBlocks(data: data),
                ),
              ),

              // ── Storage-style summary card ───────────────
              SliverToBoxAdapter(
                child: feed.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (data) => _SummaryCard(data: data),
                ),
              ),

              // ── Recent documents ─────────────────────────
              const SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Recent Files',
                  actionLabel: 'See All',
                ),
              ),
              SliverToBoxAdapter(
                child: feed.when(
                  loading: () => _ShimmerList(),
                  error: (_, __) => const SizedBox(),
                  data: (data) =>
                      _RecentFilesList(docs: data['documents'] as List),
                ),
              ),

              // ── Groups ───────────────────────────────────
              const SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'My Groups',
                  actionLabel: 'See All',
                ),
              ),
              SliverToBoxAdapter(
                child: feed.when(
                  loading: () => _ShimmerList(),
                  error: (_, __) => const SizedBox(),
                  data: (data) =>
                      _GroupsList(groups: data['groups'] as List),
                ),
              ),

              // ── Marketplace ──────────────────────────────
              const SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Marketplace',
                  actionLabel: 'Browse',
                ),
              ),
              SliverToBoxAdapter(
                child: feed.when(
                  loading: () => _ShimmerList(),
                  error: (_, __) => const SizedBox(),
                  data: (data) =>
                      _ListingsList(listings: data['listings'] as List),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

// ── Top icon button ───────────────────────────────────────
class _TopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool hasNotif;

  const _TopButton({
    required this.icon,
    required this.onTap,
    this.hasNotif = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(icon, size: 20, color: const Color(0xFF1A1A1A)),
            ),
            if (hasNotif)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF7A00),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 3 scrollable feature blocks ───────────────────────────
class _FeatureBlocks extends StatelessWidget {
  final Map<String, dynamic> data;
  const _FeatureBlocks({required this.data});

  @override
  Widget build(BuildContext context) {
    final docs = data['documents'] as List;
    final groups = data['groups'] as List;
    final listings = data['listings'] as List;

    final blocks = [
      _BlockData(
        title: 'Documents',
        subtitle: '${docs.length} files',
        color: const Color(0xFFFF7A00),
        lightColor: const Color(0xFFFFE8CC),
        icon: Icons.description_rounded,
        emoji: '📄',
      ),
      _BlockData(
        title: 'Groups',
        subtitle: '${groups.length} joined',
        color: const Color(0xFF7C5CFC),
        lightColor: const Color(0xFFEDE8FF),
        icon: Icons.groups_rounded,
        emoji: '👥',
      ),
      _BlockData(
        title: 'Market',
        subtitle: '${listings.length} listings',
        color: const Color(0xFF2D9CDB),
        lightColor: const Color(0xFFDEF0FF),
        icon: Icons.storefront_rounded,
        emoji: '🛍️',
      ),
    ];

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        itemCount: blocks.length,
        itemBuilder: (_, i) {
          final b = blocks[i];
          return Container(
            width: MediaQuery.of(context).size.width * 0.48,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: b.color,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: b.color.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background circle decoration
                Positioned(
                  bottom: -20,
                  right: -20,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  top: -10,
                  right: 30,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(b.emoji,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        b.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        b.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BlockData {
  final String title, subtitle, emoji;
  final Color color, lightColor;
  final IconData icon;

  const _BlockData({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.lightColor,
    required this.icon,
    required this.emoji,
  });
}

// ── Summary card (storage-style) ─────────────────────────
class _SummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final docs = (data['documents'] as List).length;
    final groups = (data['groups'] as List).length;
    final listings = (data['listings'] as List).length;
    final courses = (data['courses'] as List).length;
    final total = docs + groups + listings + courses;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Your Activity',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const Spacer(),
              Text(
                '$total items',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFAA7B50),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: total == 0
                    ? [
                        Expanded(
                          child: Container(color: const Color(0xFFF0F0F0)),
                        ),
                      ]
                    : [
                        _ProgressSegment(
                            flex: docs, total: total,
                            color: const Color(0xFFFF7A00)),
                        _ProgressSegment(
                            flex: groups, total: total,
                            color: const Color(0xFF7C5CFC)),
                        _ProgressSegment(
                            flex: listings, total: total,
                            color: const Color(0xFF2D9CDB)),
                        _ProgressSegment(
                            flex: courses, total: total,
                            color: const Color(0xFF10B981)),
                      ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatDot(color: const Color(0xFFFF7A00), label: 'Documents', value: '$docs'),
              _StatDot(color: const Color(0xFF7C5CFC), label: 'Groups', value: '$groups'),
              _StatDot(color: const Color(0xFF2D9CDB), label: 'Listings', value: '$listings'),
              _StatDot(color: const Color(0xFF10B981), label: 'Courses', value: '$courses'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressSegment extends StatelessWidget {
  final int flex, total;
  final Color color;
  const _ProgressSegment({required this.flex, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    if (flex == 0) return const SizedBox();
    return Flexible(
      flex: flex,
      child: Container(color: color),
    );
  }
}

class _StatDot extends StatelessWidget {
  final Color color;
  final String label, value;
  const _StatDot({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
            ],
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Color(0xFFAA7B50)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title, actionLabel;
  const _SectionHeader({required this.title, required this.actionLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A))),
          Text(actionLabel,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFFF7A00),
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Recent files list (like reference image) ──────────────
class _RecentFilesList extends StatelessWidget {
  final List docs;
  const _RecentFilesList({required this.docs});

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return _EmptyState(
          icon: Icons.description_outlined, message: 'No documents yet');
    }

    final fileColors = {
      'pdf': const Color(0xFFFF7A00),
      'docx': const Color(0xFF2D9CDB),
      'pptx': const Color(0xFF7C5CFC),
    };

    return Column(
      children: docs.take(5).map((d) {
        final doc = d as Map<String, dynamic>;
        final type = doc['file_type'] as String? ?? 'pdf';
        final color = fileColors[type] ?? const Color(0xFFFF7A00);

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
              // Thumbnail-style icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc['title'] as String? ?? 'Untitled',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      doc['course_tag'] as String? ?? 'No tag',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFAA7B50)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded,
                    size: 20, color: Color(0xFFCCCCCC)),
                onPressed: () {},
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Groups list ───────────────────────────────────────────
class _GroupsList extends StatelessWidget {
  final List groups;
  const _GroupsList({required this.groups});

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return _EmptyState(
          icon: Icons.groups_outlined, message: 'No groups yet');
    }

    final typeColors = {
      'study': const Color(0xFF7C5CFC),
      'club': const Color(0xFF2D9CDB),
      'class': const Color(0xFF10B981),
    };

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: groups.take(8).length,
        itemBuilder: (_, i) {
          final g = groups[i] as Map<String, dynamic>;
          final type = g['group_type'] as String? ?? 'study';
          final color = typeColors[type] ?? const Color(0xFF7C5CFC);
          final name = g['name'] as String? ?? 'Group';

          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: Text(
                      name.length >= 2
                          ? name.substring(0, 2).toUpperCase()
                          : name.toUpperCase(),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(name,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(type.toUpperCase(),
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Listings list ─────────────────────────────────────────
class _ListingsList extends StatelessWidget {
  final List listings;
  const _ListingsList({required this.listings});

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      return _EmptyState(
          icon: Icons.storefront_outlined, message: 'No listings yet');
    }

    return SizedBox(
      height: 175,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: listings.take(8).length,
        itemBuilder: (_, i) {
          final listing = listings[i] as Map<String, dynamic>;
          final images = listing['images'] as List?;
          final hasImage = images != null && images.isNotEmpty;

          return Container(
            width: 145,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    height: 100,
                    color: const Color(0xFFFFF8F0),
                    child: hasImage
                        ? Image.network(images.first as String,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.storefront_outlined,
                                    size: 28,
                                    color: Color(0xFFFF7A00))))
                        : const Center(
                            child: Icon(Icons.storefront_outlined,
                                size: 28, color: Color(0xFFFF7A00))),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing['title'] as String? ?? 'Item',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        listing['price'] != null
                            ? 'TZS ${listing['price']}'
                            : 'Free',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFF7A00)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: const Color(0xFFDDC4A8)),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFFAA7B50))),
        ],
      ),
    );
  }
}

// ── Shimmer placeholder ───────────────────────────────────
class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        itemBuilder: (_, __) => Container(
          width: 180,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEDD5),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:campuslink/core/api/api_client.dart';
import 'package:campuslink/core/auth/auth_provider.dart';
import 'package:campuslink/core/theme/app_theme.dart';

final profileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final results = await Future.wait([
    ApiClient.instance.get('/users/me'),
    ApiClient.instance.get('/documents'),
    ApiClient.instance.get('/skills/users/${ref.read(authProvider).user?['id']}'),
    ApiClient.instance.get('/courses'),
  ]);
  return {
    'user': results[0].data as Map<String, dynamic>,
    'documents': results[1].data as List,
    'skills': results[2].data as List,
    'courses': results[3].data as List,
  };
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (_, __) => const Center(child: Text('Failed to load profile')),
          data: (data) {
            final user = data['user'] as Map<String, dynamic>;
            final docs = data['documents'] as List;
            final skills = data['skills'] as List;
            final courses = data['courses'] as List;
            final name = user['full_name'] as String? ?? 'User';
            final firstName = name.split(' ').first;

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.refresh(profileProvider.future),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [

                    // Profile hero
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text('Profile',
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                              ),
                              GestureDetector(
                                onTap: () {},
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: const Icon(Icons.settings_outlined, size: 18, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Avatar + info
                          Row(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryTint,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.primaryBorder, width: 2),
                                ),
                                child: user['avatar_url'] != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: Image.network(user['avatar_url'] as String, fit: BoxFit.cover),
                                      )
                                    : Center(
                                        child: Text(
                                          firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primary),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                                    const SizedBox(height: 3),
                                    Text(user['email'] as String? ?? '',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    if (user['bio'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(user['bio'] as String,
                                          style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                                          maxLines: 2, overflow: TextOverflow.ellipsis),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Stats
                          Row(
                            children: [
                              _ProfileStat(value: '${docs.length}', label: 'Documents'),
                              _ProfileStat(value: '${courses.length}', label: 'Courses'),
                              _ProfileStat(value: '${skills.length}', label: 'Skills'),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Edit button
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Edit profile',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Skills
                    if (skills.isNotEmpty) ...[
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Skills', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: skills.map((s) {
                                final skill = s as Map<String, dynamic>;
                                final levelColors = {
                                  'beginner': const Color(0xFF10B981),
                                  'intermediate': const Color(0xFFF59E0B),
                                  'expert': AppColors.primary,
                                };
                                final level = skill['level'] as String? ?? 'beginner';
                                final color = levelColors[level] ?? AppColors.primary;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: color.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    skill['name'] as String? ?? '',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Menu items
                    Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          _MenuItem(icon: Icons.description_outlined, label: 'My Documents', count: docs.length),
                          _MenuItem(icon: Icons.storefront_outlined, label: 'My Listings', count: 0),
                          _MenuItem(icon: Icons.school_outlined, label: 'My Courses', count: courses.length),
                          _MenuItem(icon: Icons.groups_outlined, label: 'My Groups', count: 0),
                          _MenuItem(icon: Icons.settings_outlined, label: 'Settings', count: 0),
                          // Logout
                          GestureDetector(
                            onTap: () async {
                              await ref.read(authProvider.notifier).logout();
                              if (context.mounted) context.go('/onboarding');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.logout_rounded, size: 22, color: Colors.red),
                                  SizedBox(width: 14),
                                  Text('Sign out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;
  const _ProfileStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  const _MenuItem({required this.icon, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.textSecondary),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(10)),
              child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textHint),
        ],
      ),
    );
  }
}
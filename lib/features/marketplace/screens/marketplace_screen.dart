import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campuslink/core/api/api_client.dart';
import 'package:campuslink/core/theme/app_theme.dart';

final listingsProvider = FutureProvider<List>((ref) async {
  final res = await ApiClient.instance.get('/marketplace/listings');
  return res.data as List;
});

class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(listingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Marketplace',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 12),
                    Icon(Icons.search_rounded, size: 18, color: AppColors.textHint),
                    SizedBox(width: 8),
                    Text('Search listings…', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
                  ],
                ),
              ),
            ),

            // Category chips
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ['All', 'Books', 'Electronics', 'Clothing', 'Other'].map((c) {
                  final isActive = c == 'All';
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(c,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : AppColors.textSecondary,
                        )),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),

            // Grid
            Expanded(
              child: listings.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (_, __) => const Center(child: Text('Failed to load listings')),
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storefront_outlined, size: 48, color: AppColors.textHint),
                          const SizedBox(height: 12),
                          const Text('No listings yet', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () => ref.refresh(listingsProvider.future),
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final listing = list[i] as Map<String, dynamic>;
                        final images = listing['images'] as List?;
                        final hasImage = images != null && images.isNotEmpty;
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                child: Container(
                                  height: 110,
                                  color: AppColors.surface,
                                  child: hasImage
                                      ? Image.network(images.first as String, fit: BoxFit.cover, width: double.infinity,
                                          errorBuilder: (_, __, ___) => const Center(
                                              child: Icon(Icons.storefront_outlined, size: 32, color: AppColors.textHint)))
                                      : const Center(
                                          child: Icon(Icons.storefront_outlined, size: 32, color: AppColors.textHint)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(listing['title'] as String? ?? 'Item',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                        maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 6),
                                    Text(
                                      listing['price'] != null ? 'TZS ${listing['price']}' : 'Free',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (listing['category'] as String? ?? 'other').toUpperCase(),
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textHint),
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
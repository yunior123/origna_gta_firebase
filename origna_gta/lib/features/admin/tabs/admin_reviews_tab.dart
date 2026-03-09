// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/admin/admin_providers.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/animations.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

/// Documentation for AdminReviewsTab
class AdminReviewsTab extends ConsumerStatefulWidget {
  const AdminReviewsTab({super.key});

  @override
  ConsumerState<AdminReviewsTab> createState() => _AdminReviewsTabState();
}

class _AdminReviewsTabState extends ConsumerState<AdminReviewsTab> {
  bool _flaggedOnly = false;
  bool _hasPhotosOnly = false;

  @override
  Widget build(BuildContext context) {
    final filters = (flaggedOnly: _flaggedOnly, hasPhotosOnly: _hasPhotosOnly);
    final reviewsAsync = ref.watch(adminReviewsProvider(filters));

    return Column(
      children: [
        // Filters
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(DesignTokens.radius16),
            boxShadow: DesignTokens.shadowSm,
          ),
          child: Row(
            children: [
              Flexible(
                child: FilterChip(
                  key: const Key('admin_reviews_filter_flagged'),
                  label: Text('admin.reviews.flagged'.tr(), overflow: TextOverflow.ellipsis),
                  selected: _flaggedOnly,
                  onSelected: (v) => setState(() => _flaggedOnly = v),
                  selectedColor: DesignTokens.error.withValues(alpha: 0.15),
                  checkmarkColor: DesignTokens.error,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FilterChip(
                  key: const Key('admin_reviews_filter_photos'),
                  label: Text('admin.reviews.has_photos'.tr(), overflow: TextOverflow.ellipsis),
                  selected: _hasPhotosOnly,
                  onSelected: (v) => setState(() => _hasPhotosOnly = v),
                  selectedColor: DesignTokens.primary.withValues(alpha: 0.12),
                  checkmarkColor: DesignTokens.primary,
                ),
              ),
            ],
          ),
        ),
        // Reviews list
        Expanded(
          child: reviewsAsync.when(
            loading: () => const Center(child: ModernLoadingIndicator()),
            error: (e, _) => Center(child: Text('${'common.error'.tr()}: $e')),
            data: (reviews) {
              if (reviews.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.rate_review_rounded,
                        size: 56,
                        color: DesignTokens.textDisabled,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'admin.reviews.no_reviews'.tr(),
                        style: TextStyle(color: DesignTokens.textSecondary),
                      ),
                    ],
                  ),
                );
              }
              return FadeSlideIn(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) =>
                      _ReviewCard(review: reviews[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  final Map<String, dynamic> review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewId = review['id'] as String? ?? '';
    final rating = review[Fields.rating] as num? ?? 0;
    final reviewText = review[Fields.review] as String? ?? '';
    final userId = review[Fields.userId] as String? ?? '—';
    final productId = review[Fields.productId] as String? ?? '—';
    final imageUrls =
        (review[Fields.reviewImageUrls] as List?)?.cast<String>() ?? [];
    final isFlagged = review[Fields.isFlagged] as bool? ?? false;
    final createdAt = review[Fields.createdAt];

    return Card(
      key: Key('admin_review_$reviewId'),
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radius12),
        side: BorderSide(
          color: isFlagged
              ? DesignTokens.error.withValues(alpha: 0.4)
              : DesignTokens.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Stars
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: DesignTokens.warning,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isFlagged)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: DesignTokens.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag_rounded,
                          size: 12,
                          color: DesignTokens.error,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'admin.reviews.flagged'.tr(),
                          style: TextStyle(
                            fontSize: 11,
                            color: DesignTokens.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (imageUrls.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: DesignTokens.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_library_rounded,
                          size: 12,
                          color: DesignTokens.primary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${imageUrls.length}',
                          style: TextStyle(
                            fontSize: 11,
                            color: DesignTokens.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                // Action buttons
                Tooltip(
                  message: isFlagged
                      ? 'admin.reviews.unflag'.tr()
                      : 'admin.reviews.flag'.tr(),
                  child: IconButton(
                    key: Key('admin_review_flag_$reviewId'),
                    tooltip: isFlagged
                        ? 'admin.reviews.unflag'.tr()
                        : 'admin.reviews.flag'.tr(),
                    icon: Icon(
                      isFlagged ? Icons.flag_rounded : Icons.flag_outlined,
                      color: isFlagged
                          ? DesignTokens.error
                          : DesignTokens.textDisabled,
                      size: 20,
                    ),
                    onPressed: () =>
                        _toggleFlag(context, ref, reviewId, isFlagged),
                  ),
                ),
                Tooltip(
                  message: 'common.delete'.tr(),
                  child: IconButton(
                    key: Key('admin_review_delete_$reviewId'),
                    tooltip: 'common.delete'.tr(),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: DesignTokens.error,
                      size: 20,
                    ),
                    onPressed: () => _confirmDelete(context, ref, reviewId),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Metadata
            Text(
              'Product: ${productId.length > 20 ? '${productId.substring(0, 20)}…' : productId}  •  User: ${userId.length > 20 ? '${userId.substring(0, 20)}…' : userId}',
              style: const TextStyle(
                fontSize: 11,
                color: DesignTokens.textDisabled,
              ),
            ),
            if (reviewText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                reviewText,
                style: const TextStyle(
                  fontSize: 13,
                  color: DesignTokens.textPrimary,
                ),
              ),
            ],
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                createdAt.toString().substring(0, 19),
                style: const TextStyle(
                  fontSize: 11,
                  color: DesignTokens.textDisabled,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFlag(
    BuildContext context,
    WidgetRef ref,
    String reviewId,
    bool currentlyFlagged,
  ) async {
    try {
      await ref
          .read(adminRepositoryProvider)
          .flagReview(reviewId, flagged: !currentlyFlagged);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'common.error'.tr()}: $e'),
            backgroundColor: DesignTokens.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String reviewId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.reviews.delete_confirm_title'.tr()),
        content: Text('admin.reviews.delete_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: DesignTokens.error),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteReview(reviewId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.reviews.deleted'.tr()),
            backgroundColor: DesignTokens.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'common.error'.tr()}: $e'),
            backgroundColor: DesignTokens.error,
          ),
        );
      }
    }
  }
}

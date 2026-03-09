// coverage:ignore-file
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:origna_gta/core/routes.dart';
import 'package:origna_gta/features/products/product_rating_viewmodel.dart';
import 'package:origna_gta/features/subscription/subscription_provider.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

/// Shows the rating dialog
Future<void> showRatingDialog({
  required BuildContext context,
  required String orderId,
  required String productId,
  required String productName,
  VoidCallback? onRatingSubmitted,
}) {
  return showDialog(
    context: context,
    builder: (context) => RatingDialog(orderId: orderId, productId: productId, productName: productName, onRatingSubmitted: onRatingSubmitted),
  );
}

/// Documentation for RatingDialog
class RatingDialog extends ConsumerStatefulWidget {
  final String orderId;
  final String productId;
  final String productName;
  final VoidCallback? onRatingSubmitted;

  const RatingDialog({super.key, required this.orderId, required this.productId, required this.productName, this.onRatingSubmitted});

  @override
  ConsumerState<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends ConsumerState<RatingDialog> {
  int _selectedRating = 0;
  bool _isSubmitting = false;
  final List<Uint8List> _reviewImages = [];
  final _picker = ImagePicker();
  final _reviewTextController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(subscriptionStreamProvider).whenOrNull(data: (s) => s?.isPremium) ?? false;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('rating.title'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.productName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Text('rating.prompt'.tr(), style: const TextStyle(color: DesignTokens.textSecondary)),
            const SizedBox(height: 16),
            _buildStarRating(),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _getRatingText(),
                style: TextStyle(color: _selectedRating > 0 ? DesignTokens.warning : DesignTokens.textSecondary, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 16),
            // Review text field
            TextField(
              controller: _reviewTextController,
              maxLines: 3,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'rating.review_body'.tr(),
                hintText: 'rating.review_body_hint'.tr(),
                alignLabelWithHint: true,
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            // Photo picker section
            _buildPhotoPicker(isPremium),
          ],
        ),
      ),
      actions: [
        Semantics(
          button: true,
          label: 'rating.cancel_label'.tr(),
          child: TextButton(onPressed: _isSubmitting ? null : () => Navigator.pop(context), child: Text('common.cancel'.tr())),
        ),
        Semantics(
          button: true,
          label: 'rating.submit_label'.tr(),
          child: ElevatedButton(
            onPressed: (_selectedRating == 0 || _isSubmitting) ? null : _submitRating,
            style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primary, foregroundColor: Colors.white),
            child: _isSubmitting ? const ModernLoadingIndicator.small(color: Colors.white) : Text('common.submit'.tr()),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _reviewTextController.dispose();
    super.dispose();
  }

  Widget _buildImageThumb(int index, Uint8List bytes) {
    return Stack(
      children: [
        Container(
          width: 60,
          height: 60,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: -2,
          right: 2,
          child: GestureDetector(
            onTap: () => setState(() => _reviewImages.removeAt(index)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPicker(bool isPremium) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'rating.add_photos'.tr(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DesignTokens.textSecondary),
            ),
            const SizedBox(width: 4),
            if (isPremium)
              Text('(${_reviewImages.length}/3)', style: const TextStyle(fontSize: 12, color: DesignTokens.textDisabled))
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(gradient: DesignTokens.primaryGradient, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  'common.premium'.tr(),
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (!isPremium)
          Tooltip(
            message: 'rating.upgrade_photos_tooltip'.tr(),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed(AppRoutes.subscription);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                decoration: BoxDecoration(
                  color: DesignTokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DesignTokens.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded, color: DesignTokens.textDisabled, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('rating.photos_premium_only'.tr(), style: const TextStyle(fontSize: 12, color: DesignTokens.textSecondary)),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: DesignTokens.textDisabled, size: 18),
                  ],
                ),
              ),
            ),
          )
        else
          Row(
            children: [
              ..._reviewImages.asMap().entries.map((entry) => _buildImageThumb(entry.key, entry.value)),
              if (_reviewImages.length < 3)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: DesignTokens.outlineVariant, style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(8),
                      color: DesignTokens.surface,
                    ),
                    child: const Icon(Icons.add_photo_alternate_outlined, color: DesignTokens.textSecondary, size: 28),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        return Semantics(
          button: true,
          label: 'rating.star_label'.tr(namedArgs: {'count': starNumber.toString()}),
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedRating = starNumber);
            },
            child: Padding(
              padding: const EdgeInsets.all(4), // WCAG 2.5.8: 4+40+4=48dp touch target
              child: Icon(starNumber <= _selectedRating ? Icons.star : Icons.star_border, color: DesignTokens.warning, size: 40),
            ),
          ),
        );
      }),
    );
  }

  String _getRatingText() {
    switch (_selectedRating) {
      case 1:
        return 'rating.poor'.tr();
      case 2:
        return 'rating.fair'.tr();
      case 3:
        return 'rating.good'.tr();
      case 4:
        return 'rating.very_good'.tr();
      case 5:
        return 'rating.excellent'.tr();
      default:
        return 'rating.tap_to_rate'.tr();
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) setState(() => _reviewImages.add(bytes));
  }

  Future<void> _submitRating() async {
    setState(() => _isSubmitting = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final viewModel = ref.read(productRatingViewModelProvider.notifier);
    final reviewText = _reviewTextController.text.trim();
    final success = await viewModel.submitRating(
      widget.orderId,
      widget.productId,
      _selectedRating,
      reviewImages: _reviewImages.isNotEmpty ? List.unmodifiable(_reviewImages) : null,
      reviewText: reviewText.isNotEmpty ? reviewText : null,
    );

    if (!mounted) return;

    if (success) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('rating.thank_you'.tr()), backgroundColor: DesignTokens.success));
      widget.onRatingSubmitted?.call();
    } else {
      final error = ref.read(productRatingViewModelProvider).errorMessage ?? 'rating.error_submitting'.tr();
      messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: DesignTokens.error));
      setState(() => _isSubmitting = false);
    }
  }
}

// ─── Flutter Widget Previews ─────────────────────────────────────────────────
// NOTE: .tr() renders as raw keys in preview mode — acceptable.
// NOTE: image_picker (dart:io) will throw on web — photo picker area renders as
//       a disabled placeholder in preview; this is expected and acceptable.

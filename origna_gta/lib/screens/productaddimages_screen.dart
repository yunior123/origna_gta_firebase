// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/utils.dart';

/// Documentation for ProductAddImages
class ProductAddImages extends StatefulWidget {
  final List<ImageModel> imageModels;
  final ValueChanged<List<ImageModel>>? onImagesChanged;

  const ProductAddImages({super.key, required this.imageModels, this.onImagesChanged});

  @override
  State<ProductAddImages> createState() => _ProductAddImagesState();
}

/// Individual image tile with overlay controls
class _ImageTile extends StatelessWidget {
  final ImageModel imageModel;
  final int index;
  final bool isPrimary;
  final VoidCallback onRemove;

  const _ImageTile({required this.imageModel, required this.index, required this.isPrimary, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Image
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: isPrimary ? Border.all(color: DesignTokens.primary, width: 2) : Border.all(color: DesignTokens.outline.withValues(alpha: 0.2)),
            boxShadow: DesignTokens.shadowSm,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isPrimary ? 14 : 15),
            child: Semantics(
              image: true,
              label: isPrimary ? 'product-image-cover' : 'product-image-${index + 1}',
              child: Image.memory(imageModel.bytes, width: 110, height: 110, fit: BoxFit.cover, cacheWidth: 110, cacheHeight: 110),
            ),
          ),
        ),
        // Primary badge
        if (isPrimary)
          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(gradient: DesignTokens.primaryGradient, borderRadius: BorderRadius.circular(8)),
              child: Text(
                'product.cover'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        // Remove button
        Positioned(
          top: 4,
          right: 4,
          child: Semantics(
            button: true,
            label: 'btn-remove-image',
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: DesignTokens.error.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductAddImagesState extends State<ProductAddImages> {
  late List<ImageModel> _imageModels;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image count indicator
        Row(
          children: [
            Text(
              'product.photos_count'.tr(namedArgs: {'count': _imageModels.length.toString()}),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _imageModels.length >= BusinessRules.maxProductImages ? DesignTokens.warning : DesignTokens.textSecondary,
              ),
            ),
            if (_imageModels.length >= BusinessRules.maxProductImages) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle_rounded, size: 16, color: DesignTokens.success),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: Row(
            children: [
              // Reorderable list of images
              if (_imageModels.isNotEmpty)
                Expanded(
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    itemCount: _imageModels.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _imageModels.removeAt(oldIndex);
                        _imageModels.insert(newIndex, item);
                      });
                      widget.onImagesChanged?.call(List.unmodifiable(_imageModels));
                    },
                    proxyDecorator: (child, index, animation) {
                      return Material(color: Colors.transparent, child: child);
                    },
                    itemBuilder: (context, index) {
                      final m = _imageModels[index];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(m.url + index.toString()),
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _ImageTile(
                            imageModel: m,
                            index: index,
                            isPrimary: index == 0,
                            onRemove: () {
                              setState(() => _imageModels.removeAt(index));
                              widget.onImagesChanged?.call(List.unmodifiable(_imageModels));
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              // Add button (fixed at the end)
              if (_imageModels.length < BusinessRules.maxProductImages)
                Padding(
                  padding: EdgeInsets.only(left: _imageModels.isEmpty ? 0 : 4),
                  child: Semantics(
                    button: true,
                    label: 'btn-add-photo',
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: AnimatedContainer(
                        duration: DesignTokens.durationFast,
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: DesignTokens.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.3), width: 1.5, strokeAlign: BorderSide.strokeAlignInside),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(gradient: DesignTokens.primaryGradient, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'product.add_photo'.tr(),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DesignTokens.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void didUpdateWidget(covariant ProductAddImages oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync internal list when parent passes new images (e.g., after edit screen loads saved images)
    if (widget.imageModels != oldWidget.imageModels) {
      setState(() => _imageModels = List<ImageModel>.from(widget.imageModels));
    }
  }

  @override
  void initState() {
    super.initState();
    _imageModels = List<ImageModel>.from(widget.imageModels);
  }

  // FIX [MEDIUM] UX: Single-pick replaced with multi-image select — sellers can pick multiple
  // photos in one tap instead of repeating the picker flow for each image.
  Future<void> _pickImage() async {
    final messenger = ScaffoldMessenger.of(context);

    if (_imageModels.length >= BusinessRules.maxProductImages) {
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('product.max_images'.tr()),
            ],
          ),
          backgroundColor: DesignTokens.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      // Multi-select: allow picking up to remaining slots in a single gallery session
      final remaining = BusinessRules.maxProductImages - _imageModels.length;
      final pickedFiles = await picker.pickMultiImage(limit: remaining);

      if (pickedFiles.isNotEmpty) {
        int addedCount = 0;
        for (final pickedFile in pickedFiles) {
          if (_imageModels.length >= BusinessRules.maxProductImages) break;
          if (pickedFile.path.isEmpty) continue;
          final bytes = await pickedFile.readAsBytes();
          if (bytes.isNotEmpty) {
            _imageModels.add(ImageModel(url: pickedFile.path, bytes: bytes));
            addedCount++;
          }
        }
        if (addedCount > 0) {
          setState(() {});
          widget.onImagesChanged?.call(List.unmodifiable(_imageModels));
        } else {
          messenger.showSnackBar(SnackBar(content: Text('product.empty_image'.tr())));
        }
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('product.pick_image_failed'.tr())));
    }
  }
}

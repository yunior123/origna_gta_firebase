// coverage:ignore-file
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';
import 'package:video_player/video_player.dart';

/// Documentation for ProductAddVideo
class ProductAddVideo extends StatefulWidget {
  final XFile? videoFile;
  final String? existingVideoUrl; // For edit screen
  final void Function(XFile file, int durationSeconds)? onVideoAdded;
  final VoidCallback? onVideoRemoved;

  const ProductAddVideo({super.key, this.videoFile, this.existingVideoUrl, this.onVideoAdded, this.onVideoRemoved});

  @override
  State<ProductAddVideo> createState() => _ProductAddVideoState();
}

class _ProductAddVideoState extends State<ProductAddVideo> {
  VideoPlayerController? _controller;
  bool _isInitializing = false;
  String? _initError;

  @override
  Widget build(BuildContext context) {
    final hasVideo = widget.videoFile != null || widget.existingVideoUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'product.video_count'.tr(namedArgs: {'count': hasVideo ? '1' : '0'}),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: hasVideo ? DesignTokens.success : DesignTokens.textSecondary),
            ),
            if (hasVideo) ...[const SizedBox(width: 6), const Icon(Icons.check_circle_rounded, size: 16, color: DesignTokens.success)],
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: Row(
            children: [
              if (hasVideo)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _VideoTile(
                    controller: _controller,
                    isInitializing: _isInitializing,
                    errorMessage: _initError,
                    onRemove: widget.onVideoRemoved ?? () {},
                  ),
                ),
              // Add button (only show if no video is present)
              if (!hasVideo)
                Semantics(
                  button: true,
                  label: 'btn-add-video',
                  child: GestureDetector(
                    onTap: _pickVideo,
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
                            child: const Icon(Icons.video_library_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'product.add_video'.tr(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DesignTokens.primary),
                          ),
                        ],
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
  void didUpdateWidget(covariant ProductAddVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoFile?.path != oldWidget.videoFile?.path || widget.existingVideoUrl != oldWidget.existingVideoUrl) {
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final oldController = _controller;
    _controller = null;
    oldController?.dispose();

    if (widget.videoFile == null && widget.existingVideoUrl == null) {
      if (mounted) setState(() => _isInitializing = false);
      return;
    }

    if (mounted) {
      setState(() {
        _isInitializing = true;
        _initError = null;
      });
    }

    try {
      if (widget.videoFile != null) {
        if (kIsWeb) {
          _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoFile!.path));
        } else {
          _controller = VideoPlayerController.file(File(widget.videoFile!.path));
        }
      } else if (widget.existingVideoUrl != null) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.existingVideoUrl!));
      }

      await _controller!.initialize();
      // Mute the video for thumbnail preview
      await _controller!.setVolume(0);
    } catch (e) {
      debugPrint('Error initializing video: $e');
      _initError = 'product.video_load_error'.tr();
      _controller = null;
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _pickVideo() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

      if (pickedFile != null) {
        final length = await pickedFile.length();

        // Initialize temporary controller to get duration
        VideoPlayerController tmpController;
        if (kIsWeb) {
          tmpController = VideoPlayerController.networkUrl(Uri.parse(pickedFile.path));
        } else {
          tmpController = VideoPlayerController.file(File(pickedFile.path));
        }

        await tmpController.initialize();
        final durationSeconds = tmpController.value.duration.inSeconds;
        await tmpController.dispose();

        final validation = validateVideoFile(sizeInBytes: length, durationInSeconds: durationSeconds);

        if (validation == VideoValidationError.tooLarge) {
          messenger.showSnackBar(SnackBar(content: Text('product.video_too_large'.tr()), backgroundColor: DesignTokens.error));
          return;
        } else if (validation == VideoValidationError.tooLong) {
          messenger.showSnackBar(SnackBar(content: Text('product.video_too_long'.tr()), backgroundColor: DesignTokens.error));
          return;
        }

        widget.onVideoAdded?.call(pickedFile, durationSeconds);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('product.pick_video_failed'.tr())));
    }
  }
}

class _VideoTile extends StatelessWidget {
  final VideoPlayerController? controller;
  final bool isInitializing;
  final String? errorMessage;
  final VoidCallback onRemove;

  const _VideoTile({this.controller, required this.isInitializing, this.errorMessage, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Video Preview
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DesignTokens.primary, width: 2),
            boxShadow: DesignTokens.shadowSm,
          ),
          child: ClipRRect(borderRadius: BorderRadius.circular(14), child: _buildVideoContent()),
        ),
        // Primary badge
        Positioned(
          bottom: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 12),
                SizedBox(width: 4),
                Text(
                  'Video',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        // Remove button
        Positioned(
          top: 4,
          right: 4,
          child: Semantics(
            button: true,
            label: 'btn-remove-video',
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

  Widget _buildVideoContent() {
    if (isInitializing) {
      return const Center(child: ModernLoadingIndicator());
    }
    if (errorMessage != null || controller == null) {
      return Center(child: Icon(Icons.broken_image_rounded, color: Colors.white.withValues(alpha: 0.5), size: 30));
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(width: controller!.value.size.width, height: controller!.value.size.height, child: VideoPlayer(controller!)),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/utils/glassmorphism.dart';
import 'package:origna_gta/widgets/mascot/shop_mascot.dart';
import 'package:origna_gta/widgets/mascot/canadian_moose.dart';
import 'package:origna_gta/widgets/mascot/mascot_provider.dart';
import 'package:origna_gta/widgets/mascot/moose_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Preview screen to test mascot designs
/// Run with: flutter run -t lib/widgets/mascot/mascot_preview.dart
void main() {
  runApp(
    const ProviderScope(
      child: MaterialApp(
        home: MascotPreviewScreen(),
      ),
    ),
  );
}

/// Documentation for MascotPreviewScreen
class MascotPreviewScreen extends ConsumerStatefulWidget {
  const MascotPreviewScreen({super.key});

  @override
  ConsumerState<MascotPreviewScreen> createState() => _MascotPreviewScreenState();
}

class _MascotPreviewScreenState extends ConsumerState<MascotPreviewScreen> {
  bool _showSparky = true;
  double _size = 80;
  bool _showBubble = true;

  @override
  Widget build(BuildContext context) {
    final mascotController = ref.watch(mascotControllerProvider);
    final mooseController = ref.watch(mooseControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: GlassAppBar(
        title: 'mascot.preview.title'.tr(),
        backgroundColor: DesignTokens.primary,
      ),
      body: Column(
        children: [
          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Mascot:'),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text('Sparky'),
                      selected: _showSparky,
                      onSelected: (v) => setState(() => _showSparky = true),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Moose'),
                      selected: !_showSparky,
                      onSelected: (v) => setState(() => _showSparky = false),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Size:'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Slider(
                        value: _size,
                        min: 60,
                        max: 150,
                        divisions: 9,
                        label: '${_size.round()}',
                        onChanged: (v) => setState(() => _size = v),
                      ),
                    ),
                    Text('${_size.round()}px'),
                  ],
                ),
                Row(
                  children: [
                    const Text('Speech Bubble:'),
                    const SizedBox(width: 16),
                    Switch(
                      value: _showBubble,
                      onChanged: (v) => setState(() => _showBubble = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Preview Area
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DesignTokens.outlineVariant),
              ),
              child: Stack(
                children: [
                  // Grid background
                  CustomPaint(
                    size: Size.infinite,
                    painter: GridPainter(),
                  ),
                  
                  // Center marker
                  Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: DesignTokens.error.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                  
                  // Mascot positioned at bottom right (like in home screen)
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: DesignTokens.error.withValues(alpha: 0.3)),
                      ),
                      child: _showSparky
                          ? ShopMascot(
                              controller: mascotController,
                              size: _size,
                              showSpeechBubble: _showBubble,
                            )
                          : CanadianMoose(
                              controller: mooseController,
                              size: _size,
                              showSpeechBubble: _showBubble,
                            ),
                    ),
                  ),
                  
                  // Size indicator
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Size: ${_size.round()}px | ${_showSparky ? "Sparky" : "Moose"}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: DesignTokens.surface,
            child: const Column(
              children: [
                Text(
                  'How to use this preview:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Toggle between Sparky and Moose'),
                Text('• Adjust size to see how mascots scale'),
                Text('• Toggle speech bubble on/off'),
                Text('• Red border shows widget bounds'),
                Text('• Tap mascot to trigger jump animation'),
                SizedBox(height: 8),
                Text(
                  'Command to run: flutter run -t lib/widgets/mascot/mascot_preview.dart',
                  style: TextStyle(fontSize: 11, color: DesignTokens.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Documentation for GridPainter
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DesignTokens.outlineVariant.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    const gridSize = 20.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

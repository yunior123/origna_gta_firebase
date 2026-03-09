// coverage:ignore-file
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/utils/design_tokens.dart';
import 'package:origna_gta/widgets/animations.dart';
import 'package:origna_gta/widgets/modern_loading_indicator.dart';

import '../features/terms/terms_provider.dart';

/// Parsed section from raw terms text
class _TermsSection {
  final int number;
  final String title;
  final String body;
  final IconData icon;

  const _TermsSection({
    required this.number,
    required this.title,
    required this.body,
    required this.icon,
  });
}

/// Icon mapping per section keyword
IconData _iconForSection(String title) {
  final t = title.toLowerCase();
  if (t.contains('acceptance')) return Icons.handshake_outlined;
  if (t.contains('account') || t.contains('registration')) return Icons.person_add_outlined;
  if (t.contains('purchase') || t.contains('payment')) return Icons.payment_outlined;
  if (t.contains('shipping') || t.contains('delivery')) return Icons.local_shipping_outlined;
  if (t.contains('return') || t.contains('refund')) return Icons.assignment_return_outlined;
  if (t.contains(UserRoleValues.seller)) return Icons.storefront_outlined;
  if (t.contains('prohibited')) return Icons.block_outlined;
  if (t.contains('intellectual') || t.contains('property')) return Icons.copyright_outlined;
  if (t.contains('liability') || t.contains('limitation')) return Icons.shield_outlined;
  if (t.contains('privacy')) return Icons.lock_outlined;
  if (t.contains('change')) return Icons.edit_note_outlined;
  if (t.contains('termination')) return Icons.cancel_outlined;
  if (t.contains('governing') || t.contains('law')) return Icons.gavel_outlined;
  if (t.contains('contact')) return Icons.mail_outlined;
  return Icons.article_outlined;
}

/// Parse raw terms string into structured sections
List<_TermsSection> _parseSections(String raw) {
  final sections = <_TermsSection>[];
  final pattern = RegExp(r'(\d+)\.\s+([A-Z][A-Z &/]+)\n');
  final matches = pattern.allMatches(raw).toList();

  for (var i = 0; i < matches.length; i++) {
    final match = matches[i];
    final number = int.parse(match.group(1)!);
    final title = match.group(2)!.trim();
    final bodyStart = match.end;
    final bodyEnd = i + 1 < matches.length ? matches[i + 1].start : raw.length;
    final body = raw.substring(bodyStart, bodyEnd).trim();
    sections.add(_TermsSection(
      number: number,
      title: title,
      body: body,
      icon: _iconForSection(title),
    ));
  }

  return sections;
}

/// Documentation for TermsScreen
class TermsScreen extends ConsumerWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termsAsync = ref.watch(termsProvider);

    return Scaffold(
      body: termsAsync.when(
        loading: () => _buildLoadingState(),
        error: (err, stack) => _buildErrorState(context),
        data: (content) => _TermsBody(rawContent: content),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [DesignTokens.gradientStart, DesignTokens.gradientMiddle],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.white, DesignTokens.accent],
              ).createShader(bounds),
              child: const ModernLoadingIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
                centered: false,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'legal.loading_terms'.tr(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [DesignTokens.gradientStart, DesignTokens.gradientMiddle],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: DesignTokens.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, size: 48, color: DesignTokens.error),
            ),
            const SizedBox(height: 20),
            Text(
              'legal.unable_to_load'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'legal.check_connection'.tr(),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
            ),
            const SizedBox(height: 28),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
              label: Text('seller.go_back'.tr(), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsBody extends StatefulWidget {
  final String rawContent;

  const _TermsBody({required this.rawContent});

  @override
  State<_TermsBody> createState() => _TermsBodyState();
}

class _TermsBodyState extends State<_TermsBody> {
  late final List<_TermsSection> _sections;
  late final Set<int> _expanded;
  final _scrollController = ScrollController();
  final Map<int, GlobalKey> _sectionKeys = {};

  @override
  void initState() {
    super.initState();
    _sections = _parseSections(widget.rawContent);
    _expanded = {};
    for (final s in _sections) {
      _sectionKeys[s.number] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(int number) {
    final key = _sectionKeys[number];
    if (key?.currentContext != null) {
      setState(() => _expanded.add(number));
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: DesignTokens.durationNormal,
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? DesignTokens.darkSurface : DesignTokens.surface,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        slivers: [
          // Gradient Hero Header
          _buildHeroHeader(context),
          // Quick Nav Pills
          SliverToBoxAdapter(child: _buildQuickNav(isDark)),
          // Sections
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final section = _sections[index];
                  return FadeSlideIn(
                    delay: Duration(milliseconds: 60 * index.clamp(0, 8)),
                    child: _buildSectionCard(section, isDark),
                  );
                },
                childCount: _sections.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      stretch: true,
      backgroundColor: DesignTokens.gradientMiddle,
      leading: IconButton(
        tooltip: 'common.back'.tr(),
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                DesignTokens.gradientStart,
                DesignTokens.gradientMiddle,
                DesignTokens.gradientEnd,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -40,
                right: -30,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: -50,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DesignTokens.accent.withValues(alpha: 0.06),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeSlideIn(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: DesignTokens.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: DesignTokens.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              size: 14,
                              color: DesignTokens.accent.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'legal.legal_agreement'.tr(),
                              style: TextStyle(
                                color: DesignTokens.accent.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 100),
                      child: Text(
                        'legal.terms_conditions_title'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 200),
                      child: Text(
                        '${'legal.last_updated_february_2026'.tr()}  •  ${_sections.length}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickNav(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text(
            'legal.jump_to_section'.tr(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: DesignTokens.textDisabled,
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _sections.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final section = _sections[index];
              return GestureDetector(
                onTap: () => _scrollToSection(section.number),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? DesignTokens.primary.withValues(alpha: 0.12)
                        : DesignTokens.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: DesignTokens.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(section.icon, size: 14, color: DesignTokens.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${section.number}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: DesignTokens.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSectionCard(_TermsSection section, bool isDark) {
    final isExpanded = _expanded.contains(section.number);

    return Padding(
      key: _sectionKeys[section.number],
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expanded.remove(section.number);
              } else {
                _expanded.add(section.number);
              }
            });
          },
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
          child: AnimatedContainer(
            duration: DesignTokens.durationNormal,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? DesignTokens.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(DesignTokens.radius16),
              border: Border.all(
                color: isExpanded
                    ? DesignTokens.primary.withValues(alpha: 0.3)
                    : (isDark ? DesignTokens.darkOutline : DesignTokens.outlineVariant),
                width: isExpanded ? 1.5 : 1,
              ),
              boxShadow: isExpanded
                  ? [
                      BoxShadow(
                        color: DesignTokens.primary.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : DesignTokens.shadowSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section header
                Row(
                  children: [
                    // Number badge
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: isExpanded
                            ? DesignTokens.primaryGradient
                            : null,
                        color: isExpanded
                            ? null
                            : (isDark
                                ? DesignTokens.primary.withValues(alpha: 0.12)
                                : DesignTokens.primary.withValues(alpha: 0.08)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${section.number}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isExpanded ? Colors.white : DesignTokens.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title
                    Expanded(
                      child: Text(
                        _titleCase(section.title),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : DesignTokens.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    // Icon
                    Icon(
                      section.icon,
                      size: 20,
                      color: DesignTokens.textDisabled,
                    ),
                    const SizedBox(width: 8),
                    // Expand indicator
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: DesignTokens.durationNormal,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 22,
                        color: isExpanded
                            ? DesignTokens.primary
                            : DesignTokens.textDisabled,
                      ),
                    ),
                  ],
                ),
                // Expanded content
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                DesignTokens.primary.withValues(alpha: 0.2),
                                DesignTokens.secondary.withValues(alpha: 0.1),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildSectionBody(section.body, isDark),
                      ],
                    ),
                  ),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: DesignTokens.durationNormal,
                  sizeCurve: Curves.easeOutCubic,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionBody(String body, bool isDark) {
    final lines = body.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: DesignTokens.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    trimmed.substring(2),
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.6,
                      color: isDark ? DesignTokens.textSecondary : const Color(0xFF4A4A5A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (trimmed.startsWith('  * ') || trimmed.startsWith('  - ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DesignTokens.secondary.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trimmed.substring(4),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: isDark ? DesignTokens.textSecondary : const Color(0xFF6A6A7A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              trimmed,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.65,
                color: isDark ? DesignTokens.textSecondary : const Color(0xFF4A4A5A),
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  String _titleCase(String input) {
    final lower = input.toLowerCase().split(' ');
    final skip = {'and', 'or', 'of', 'to', 'the', 'in', 'for', '&'};
    return lower.asMap().entries.map((e) {
      if (e.key == 0 || !skip.contains(e.value)) {
        return e.value[0].toUpperCase() + e.value.substring(1);
      }
      return e.value;
    }).join(' ');
  }
}

// ─── Flutter Previews ────────────────────────────────────────────────────────


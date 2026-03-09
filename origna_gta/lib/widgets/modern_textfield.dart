import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';

/// Modern 2100 Text Input Field with glassmorphism
class ModernTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool isPassword;
  final bool isMultiline;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int maxLines;
  final int minLines;
  final int? maxLength;
  final bool showCounter;
  final Key? textFieldKey;
  final String? semanticsLabel;

  const ModernTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.isMultiline = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.minLines = 1,
    this.maxLength,
    this.showCounter = false,
    this.textFieldKey,
    this.semanticsLabel,
  });

  @override
  State<ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<ModernTextField> {
  late FocusNode _focusNode;
  late bool _obscureText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : DesignTokens.textPrimary, letterSpacing: 0.3),
          ),
          const SizedBox(height: DesignTokens.spacing8),
        ],
        Semantics(
          label: widget.semanticsLabel ?? widget.label,
          textField: true,
          container: true,
          child: TextFormField(
            key: widget.textFieldKey,
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            obscureText: _obscureText,
            maxLines: _obscureText ? 1 : widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            validator: widget.validator,
            onChanged: widget.onChanged,
            cursorColor: DesignTokens.primary,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(color: DesignTokens.textDisabled, fontSize: 14),
              filled: true,
              fillColor: isDark ? DesignTokens.darkSurfaceVariant.withValues(alpha: 0.5) : DesignTokens.surfaceVariant.withValues(alpha: 0.7),
              prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon, color: DesignTokens.primary, size: 20) : null,
              suffixIcon: widget.suffixIcon != null
                  ? Semantics(
                      button: true,
                      label: 'common.toggle_password_visibility'.tr(),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: GestureDetector(
                          onTap: widget.onSuffixTap,
                          child: Center(child: Icon(widget.suffixIcon, color: DesignTokens.primary, size: 20)),
                        ),
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radius12),
                borderSide: BorderSide(color: Colors.transparent),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radius12),
                borderSide: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.2), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radius12),
                borderSide: BorderSide(color: DesignTokens.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radius12),
                borderSide: BorderSide(color: DesignTokens.error, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radius12),
                borderSide: BorderSide(color: DesignTokens.error, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing16, vertical: DesignTokens.spacing12),
              counterText: widget.showCounter ? null : '',
            ),
            style: TextStyle(fontSize: 15, color: isDark ? Colors.white : DesignTokens.textPrimary),
          ),
        ),
      ],
    );
  }

  @override
  void didUpdateWidget(ModernTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPassword != widget.isPassword) {
      setState(() {
        _obscureText = widget.isPassword;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _obscureText = widget.isPassword;
  }
}

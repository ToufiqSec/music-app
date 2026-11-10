import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_motion.dart';

/// Exact Search Field from Section 7 of Universal UI Design System: Twilight Calm.
class AppSearchField extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSearchTap;
  final String placeholder;

  const AppSearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.onSearchTap,
    this.placeholder = 'Search songs, artists, albums...',
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.durationBase,
      height: 52,
      decoration: BoxDecoration(
        color: _isFocused
            ? AppColors.surface2
            : AppColors.surface1.withValues(alpha: 0.9),
        borderRadius: AppRadii.borderLarge,
        border: Border.all(
          color: _isFocused ? AppColors.primarySoft : Colors.transparent,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.only(left: 20, right: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
              cursorColor: AppColors.primarySoft,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: widget.placeholder,
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          GestureDetector(
            onTap: widget.onSearchTap,
            child: const Icon(
              Icons.search,
              size: 20,
              color: AppColors.iconIdle,
            ),
          ),
        ],
      ),
    );
  }
}

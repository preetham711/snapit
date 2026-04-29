import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SearchBarWidget extends StatefulWidget {
  final ValueChanged<String>? onChanged;
  final String hint;

  const SearchBarWidget({
    Key? key,
    this.onChanged,
    this.hint = 'Search people...',
  }) : super(key: key);

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  late AnimationController _ctrl;
  late Animation<Color?> _borderColor;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _borderColor = ColorTween(
      begin: AppTheme.border,
      end: AppTheme.primary,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _borderColor,
      builder: (context, child) {
        return Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.bg2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _borderColor.value ?? AppTheme.border,
              width: _focusNode.hasFocus ? 1.5 : 1.0,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: TextField(
            focusNode: _focusNode,
            onChanged: widget.onChanged,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: _focusNode.hasFocus
                    ? AppTheme.primary
                    : AppTheme.textMuted,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
          ),
        );
      },
    );
  }
}

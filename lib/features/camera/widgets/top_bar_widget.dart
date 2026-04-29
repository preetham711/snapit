import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Top bar overlaid on the camera preview.
/// Contains: Flash toggle | Photo count hint | Quick Save pill
class TopBarWidget extends StatelessWidget {
  final bool isFlashOn;
  final bool isQuickSaveEnabled;
  final VoidCallback onFlashToggle;
  final VoidCallback onQuickSaveToggle;
  final VoidCallback onFlipCamera;

  // Backward-compat params
  final bool isFrontCamera;
  final VoidCallback? onFlashTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onQuickSaveTap;
  final VoidCallback? onSwitchCameraTap;

  const TopBarWidget({
    Key? key,
    required this.isFlashOn,
    this.isQuickSaveEnabled = false,
    this.onFlashToggle = _noop,
    this.onQuickSaveToggle = _noop,
    this.onFlipCamera = _noop,
    this.isFrontCamera = false,
    this.onFlashTap,
    this.onSettingsTap,
    this.onQuickSaveTap,
    this.onSwitchCameraTap,
  }) : super(key: key);

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    final flashCb  = onFlashTap  ?? onFlashToggle;
    final quickCb  = onQuickSaveTap ?? onQuickSaveToggle;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            // Flash toggle
            _CamIconBtn(
              onTap: flashCb,
              child: Icon(
                isFlashOn
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
                color: isFlashOn ? Colors.amber : Colors.white,
                size: 22,
              ),
            ),

            const Spacer(),

            // Quick Save pill
            _QuickSavePill(
              isEnabled: isQuickSaveEnabled,
              onTap: quickCb,
            ),

            const Spacer(),

            // Placeholder to balance layout (same width as flash btn)
            const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }
}

// ─── Icon button ──────────────────────────────────────────────────────────────

class _CamIconBtn extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _CamIconBtn({required this.child, required this.onTap});

  @override
  State<_CamIconBtn> createState() => _CamIconBtnState();
}

class _CamIconBtnState extends State<_CamIconBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.82)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.4),
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

// ─── Quick Save pill ──────────────────────────────────────────────────────────

class _QuickSavePill extends StatefulWidget {
  final bool isEnabled;
  final VoidCallback onTap;

  const _QuickSavePill({required this.isEnabled, required this.onTap});

  @override
  State<_QuickSavePill> createState() => _QuickSavePillState();
}

class _QuickSavePillState extends State<_QuickSavePill>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.92)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isEnabled
                ? AppTheme.primary
                : Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.isEnabled
                  ? AppTheme.primary
                  : Colors.white.withOpacity(0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bolt_rounded,
                color: widget.isEnabled ? Colors.white : Colors.white60,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'Quick Save',
                style: TextStyle(
                  color: widget.isEnabled ? Colors.white : Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

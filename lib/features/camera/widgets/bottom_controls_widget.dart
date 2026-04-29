import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:io';

class BottomControlsWidget extends StatefulWidget {
  final String? lastImagePath;
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final bool isFrontCamera;
  final VoidCallback onCaptureTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onLastTap;
  final VoidCallback onSwitchCamera;
  final Function(double) onZoomChanged;

  const BottomControlsWidget({
    Key? key,
    required this.lastImagePath,
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.isFrontCamera,
    required this.onCaptureTap,
    required this.onGalleryTap,
    required this.onLastTap,
    required this.onSwitchCamera,
    required this.onZoomChanged,
  }) : super(key: key);

  @override
  State<BottomControlsWidget> createState() => _BottomControlsWidgetState();
}

class _BottomControlsWidgetState extends State<BottomControlsWidget> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 36, left: 32, right: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SideBtn(
            child: const Icon(Icons.photo_library_outlined,
                color: Colors.white, size: 22),
            onTap: widget.onGalleryTap,
          ),
          _CaptureBtn(
            isPressed: _isPressed,
            onTapDown: () => setState(() => _isPressed = true),
            onTapUp: () {
              setState(() => _isPressed = false);
              widget.onCaptureTap();
            },
            onTapCancel: () => setState(() => _isPressed = false),
          ),
          _SideBtn(
            onTap: widget.onLastTap,
            onLongPress: widget.onSwitchCamera,
            child: widget.lastImagePath != null
                ? ClipOval(
                    child: Image.file(
                      File(widget.lastImagePath!),
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _lastFallback(),
                    ),
                  )
                : _lastFallback(),
          ),
        ],
      ),
    );
  }

  Widget _lastFallback() => Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.primary,
        ),
        child: const Center(
          child: Text('Last',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      );
}

// ─── Side button ──────────────────────────────────────────────────────────────

class _SideBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SideBtn({
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.45),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ─── Capture button ───────────────────────────────────────────────────────────

class _CaptureBtn extends StatefulWidget {
  final bool isPressed;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;

  const _CaptureBtn({
    required this.isPressed,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
  });

  @override
  State<_CaptureBtn> createState() => _CaptureBtnState();
}

class _CaptureBtnState extends State<_CaptureBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => widget.onTapDown(),
      onTapUp: (_) => widget.onTapUp(),
      onTapCancel: widget.onTapCancel,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, child) => Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white
                  .withOpacity(0.15 + _pulseCtrl.value * 0.15),
              width: 2,
            ),
          ),
          child: child,
        ),
        child: AnimatedScale(
          scale: widget.isPressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Container(
            margin: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

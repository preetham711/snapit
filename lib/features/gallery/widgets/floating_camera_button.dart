import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class FloatingCameraButton extends StatefulWidget {
  final VoidCallback onTap;

  const FloatingCameraButton({Key? key, required this.onTap}) : super(key: key);

  @override
  State<FloatingCameraButton> createState() => _FloatingCameraButtonState();
}

class _FloatingCameraButtonState extends State<FloatingCameraButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 130));
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.45),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 10),
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.camera_alt_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

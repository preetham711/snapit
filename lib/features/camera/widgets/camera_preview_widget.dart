import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/camera_bloc.dart';
import '../services/camera_service.dart';

class CameraPreviewWidget extends StatefulWidget {
  final CameraBloc cameraBloc;

  const CameraPreviewWidget({Key? key, required this.cameraBloc})
      : super(key: key);

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _focusAnimController;
  late Animation<double> _focusScaleAnim;
  late Animation<double> _focusOpacityAnim;
  Offset? _focusPosition; // screen position

  @override
  void initState() {
    super.initState();
    _focusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _focusScaleAnim = Tween<double>(begin: 1.4, end: 1.0).animate(
      CurvedAnimation(parent: _focusAnimController, curve: Curves.easeOut),
    );
    _focusOpacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _focusAnimController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _focusAnimController.dispose();
    super.dispose();
  }

  void _onTapFocus(TapUpDetails details, BoxConstraints constraints) {
    final size = constraints.biggest;
    final dx = details.localPosition.dx / size.width;
    final dy = details.localPosition.dy / size.height;

    setState(() => _focusPosition = details.localPosition);
    _focusAnimController.forward(from: 0);

    widget.cameraBloc.add(SetFocusPointEvent(Offset(dx, dy)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraBloc, CameraState>(
      bloc: widget.cameraBloc,
      buildWhen: (prev, curr) =>
          curr is CameraReady || curr is CameraLoading || curr is CameraError,
      builder: (context, state) {
        if (state is CameraReady) {
          final service = CameraService();
          if (!service.isInitialized) return _buildBlack();

          return LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapUp: (d) => _onTapFocus(d, constraints),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Layer 1: Camera preview — RepaintBoundary prevents
                    // overlay rebuilds from touching the preview texture
                    RepaintBoundary(
                      child: _FullScreenCameraPreview(
                        controller: service.controller,
                      ),
                    ),

                    // Layer 2: Focus indicator
                    if (_focusPosition != null)
                      _FocusIndicator(
                        position: _focusPosition!,
                        scaleAnim: _focusScaleAnim,
                        opacityAnim: _focusOpacityAnim,
                      ),
                  ],
                ),
              );
            },
          );
        }
        return _buildBlack();
      },
    );
  }

  Widget _buildBlack() => const ColoredBox(color: Colors.black);
}

// Renders the camera preview filling the screen with BoxFit.cover behavior.
class _FullScreenCameraPreview extends StatelessWidget {
  final CameraController controller;

  const _FullScreenCameraPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return const ColoredBox(color: Colors.black);

    // previewSize is (height, width) on most platforms
    final previewAspect = previewSize.height / previewSize.width;
    final screenAspect = size.width / size.height;

    double scale;
    if (previewAspect > screenAspect) {
      // Preview is taller — fit width, crop height
      scale = previewAspect / screenAspect;
    } else {
      // Preview is wider — fit height, crop width
      scale = screenAspect / previewAspect;
    }

    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: Center(
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

// Animated focus ring shown at tap position.
class _FocusIndicator extends StatelessWidget {
  final Offset position;
  final Animation<double> scaleAnim;
  final Animation<double> opacityAnim;

  const _FocusIndicator({
    required this.position,
    required this.scaleAnim,
    required this.opacityAnim,
  });

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: scaleAnim,
          builder: (_, __) => Opacity(
            opacity: opacityAnim.value,
            child: Transform.scale(
              scale: scaleAnim.value,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.yellow, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

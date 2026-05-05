import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/camera_bloc.dart';
import '../services/camera_service.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/top_bar_widget.dart';
import 'add_details_screen.dart';
import '../../gallery/screens/gallery_screen.dart';

// Standard native camera layout:
//   [Last photo circle]  [Capture button]  [Gallery square]
// No circles strip — only the single latest photo on the left.
// Tap left circle → AddDetailsScreen for that photo.
// Tap right square → Gallery.

class CameraHomeScreen extends StatefulWidget {
  const CameraHomeScreen({Key? key}) : super(key: key);
  @override
  State<CameraHomeScreen> createState() => _CameraHomeScreenState();
}

class _CameraHomeScreenState extends State<CameraHomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late CameraBloc _cameraBloc;
  final CameraService _cameraService = CameraService();

  // Only track the LAST captured image path (standard camera behaviour)
  String? _lastCapturedPath;

  late AnimationController _flashCtrl;
  late Animation<double> _flashOpacity;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;
  late AnimationController _captureCtrl;
  late Animation<double> _captureScale;
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraBloc = CameraBloc()..add(const InitializeCameraEvent());

    _flashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _flashOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut));

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
    _pulseScale = Tween<double>(begin: 1.0, end: 1.5)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(begin: 0.45, end: 0.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));

    _captureCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 80));
    _captureScale = Tween<double>(begin: 1.0, end: 0.86)
        .animate(CurvedAnimation(parent: _captureCtrl, curve: Curves.easeOut));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _cameraBloc.add(const InitializeCameraEvent());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _cameraBloc.add(const PauseCameraEvent());
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraBloc.close();
    _flashCtrl.dispose();
    _pulseCtrl.dispose();
    _captureCtrl.dispose();
    super.dispose();
  }

  // ── Capture — direct, no BLoC ──────────────────────────────────────────────

  Future<void> _onCapture() async {
    HapticFeedback.mediumImpact();
    _captureCtrl.forward().then((_) => _captureCtrl.reverse());

    final path = await _cameraService.captureImage();
    if (path == null) return;

    _triggerFlash();
    if (mounted) setState(() => _lastCapturedPath = path);
  }

  void _triggerFlash() {
    _flashCtrl.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 40), () {
        if (mounted) _flashCtrl.reverse();
      });
    });
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _openAddDetails(String imagePath) {
    _cameraBloc.add(const PauseCameraEvent());
    Navigator.of(context)
        .push(PageRouteBuilder(
          pageBuilder: (_, anim, __) => AddDetailsScreen(imagePath: imagePath),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
          transitionDuration: const Duration(milliseconds: 300),
        ))
        .then((_) => _cameraBloc.add(const InitializeCameraEvent()));
  }

  void _openGallery() {
    _cameraBloc.add(const PauseCameraEvent());
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const GalleryScreen()))
        .then((_) => _cameraBloc.add(const InitializeCameraEvent()));
  }

  void _onSwitchCamera() {
    HapticFeedback.lightImpact();
    _cameraBloc.add(const SwitchCameraEvent());
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cameraBloc,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: BlocBuilder<CameraBloc, CameraState>(
          buildWhen: (prev, curr) =>
              curr is CameraInitial ||
              curr is CameraLoading ||
              curr is CameraReady ||
              curr is CameraError,
          builder: (context, state) {
            if (state is CameraInitial || state is CameraLoading) return _buildLoading();
            if (state is CameraError) return _buildError(state.message);
            return _buildCamera(state);
          },
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 30, spreadRadius: 2)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('logo/logo.png', fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 36),
                    )),
              ),
            ),
            const SizedBox(height: 28),
            const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2)),
            const SizedBox(height: 14),
            const Text('Starting camera...', style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)),
                  child: const Icon(Icons.camera_alt_outlined, color: Colors.white38, size: 32),
                ),
                const SizedBox(height: 20),
                const Text('Camera unavailable',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: () => _cameraBloc.add(const InitializeCameraEvent()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                    child: const Text('Retry',
                        style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCamera(CameraState state) {
    final ready = state is CameraReady ? state : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Preview — double-tap flip, pinch zoom
        GestureDetector(
          onDoubleTap: _onSwitchCamera,
          onScaleStart: (_) { _baseZoom = ready?.currentZoom ?? 1.0; },
          onScaleUpdate: (d) {
            if (ready == null || d.pointerCount < 2) return;
            _cameraBloc.add(SetZoomEvent(
                (_baseZoom * d.scale).clamp(ready.minZoom, ready.maxZoom)));
          },
          child: CameraPreviewWidget(cameraBloc: _cameraBloc),
        ),

        // Top gradient
        Positioned(top: 0, left: 0, right: 0,
          child: IgnorePointer(child: Container(height: 180,
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.65), Colors.transparent]))))),

        // Bottom gradient
        Positioned(bottom: 0, left: 0, right: 0,
          child: IgnorePointer(child: Container(height: 260,
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.bottomCenter, end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.92), Colors.transparent]))))),

        // Shutter flash
        AnimatedBuilder(
          animation: _flashOpacity,
          builder: (_, __) => IgnorePointer(
            child: Opacity(opacity: _flashOpacity.value, child: const ColoredBox(color: Colors.white)))),

        // Top bar
        if (ready != null)
          Positioned(top: 0, left: 0, right: 0,
            child: TopBarWidget(
              isFlashOn: ready.isFlashOn,
              isQuickSaveEnabled: ready.isQuickSaveEnabled,
              onFlashToggle: () => _cameraBloc.add(const ToggleFlashEvent()),
              onQuickSaveToggle: () => _cameraBloc.add(const ToggleQuickSaveEvent()),
              onFlipCamera: _onSwitchCamera,
            )),

        // Zoom badge
        if (ready != null && ready.currentZoom > 1.05)
          Positioned(top: 110, left: 0, right: 0,
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${ready.currentZoom.toStringAsFixed(1)}x',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))))),

        // Bottom controls row — standard native camera layout
        Positioned(bottom: 0, left: 0, right: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // LEFT: last captured photo thumbnail (rounded square, like native camera)
                  _LastPhotoThumb(
                    imagePath: _lastCapturedPath,
                    onTap: _lastCapturedPath != null
                        ? () => _openAddDetails(_lastCapturedPath!)
                        : _openGallery,
                  ),

                  // CENTER: capture button
                  _CaptureButton(
                    pulseScale: _pulseScale,
                    pulseOpacity: _pulseOpacity,
                    captureScale: _captureScale,
                    captureCtrl: _captureCtrl,
                    onCapture: _onCapture,
                  ),

                  // RIGHT: gallery
                  _GalleryButton(onTap: _openGallery),
                ],
              ),
            ),
          )),
      ],
    );
  }
}

// ─── Last photo thumbnail (left button) ──────────────────────────────────────
// Shows the most recently captured photo as a rounded square.
// Matches native Android/iOS camera behaviour.

class _LastPhotoThumb extends StatefulWidget {
  final String? imagePath;
  final VoidCallback onTap;
  const _LastPhotoThumb({this.imagePath, required this.onTap});

  @override
  State<_LastPhotoThumb> createState() => _LastPhotoThumbState();
}

class _LastPhotoThumbState extends State<_LastPhotoThumb>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.imagePath != null
                  ? Colors.white.withOpacity(0.85)
                  : Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            color: Colors.black.withOpacity(0.3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: widget.imagePath != null
                ? Image.file(File(widget.imagePath!), fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.photo_library_outlined, color: Colors.white54, size: 24))
                : const Icon(Icons.photo_library_outlined, color: Colors.white38, size: 24),
          ),
        ),
      ),
    );
  }
}

// ─── Capture button ───────────────────────────────────────────────────────────

class _CaptureButton extends StatelessWidget {
  final Animation<double> pulseScale;
  final Animation<double> pulseOpacity;
  final Animation<double> captureScale;
  final AnimationController captureCtrl;
  final Future<void> Function() onCapture;

  const _CaptureButton({
    required this.pulseScale,
    required this.pulseOpacity,
    required this.captureScale,
    required this.captureCtrl,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => captureCtrl.forward(),
      onTapUp: (_) { captureCtrl.reverse(); onCapture(); },
      onTapCancel: () => captureCtrl.reverse(),
      child: ScaleTransition(
        scale: captureScale,
        child: SizedBox(
          width: 84, height: 84,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: pulseScale,
                builder: (_, __) => Transform.scale(
                  scale: pulseScale.value,
                  child: Opacity(opacity: pulseOpacity.value,
                      child: Container(width: 84, height: 84,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5)))))),
              Container(width: 76, height: 76,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3.5))),
              Container(width: 62, height: 62,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Gallery button (right) ───────────────────────────────────────────────────

class _GalleryButton extends StatefulWidget {
  final VoidCallback onTap;
  const _GalleryButton({required this.onTap});

  @override
  State<_GalleryButton> createState() => _GalleryButtonState();
}

class _GalleryButtonState extends State<_GalleryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
          ),
          child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

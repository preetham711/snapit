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

// ─────────────────────────────────────────────────────────────────────────────
// Capture architecture:
//   CameraService.captureImage() called DIRECTLY from UI — no BLoC hop.
//   _isCapturing guard lives in CameraService (single source of truth).
//   BLoC only handles: init, flash, zoom, switch, pause.
//   Captured images stored in local _capturedImages (persists across rebuilds).
// ─────────────────────────────────────────────────────────────────────────────

class CameraHomeScreen extends StatefulWidget {
  const CameraHomeScreen({Key? key}) : super(key: key);
  @override
  State<CameraHomeScreen> createState() => _CameraHomeScreenState();
}

class _CameraHomeScreenState extends State<CameraHomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late CameraBloc _cameraBloc;
  final CameraService _cameraService = CameraService(); // direct access for capture
  final List<String> _capturedImages = [];

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
    _flashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _flashOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
    _pulseScale = Tween<double>(begin: 1.0, end: 1.5).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(begin: 0.45, end: 0.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
    _captureCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 80));
    _captureScale = Tween<double>(begin: 1.0, end: 0.86).animate(CurvedAnimation(parent: _captureCtrl, curve: Curves.easeOut));
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

  // ── CAPTURE — direct call to CameraService, bypasses BLoC ───────────────
  // This eliminates the async event-queue latency and makes capture instant.
  // The _isCapturing guard inside CameraService prevents double-taps.

  Future<void> _onCapture() async {
    // Immediate haptic + visual feedback BEFORE the async capture
    HapticFeedback.mediumImpact();
    _captureCtrl.forward().then((_) => _captureCtrl.reverse());

    // Direct call — no BLoC event, no queue, no state machine overhead
    final path = await _cameraService.captureImage();

    if (path == null) {
      // Already capturing, not initialized, or error — silent fail
      debugPrint('[Camera] capture skipped or failed');
      return;
    }

    // Flash animation after successful capture
    _triggerFlash();

    // Update local list → triggers setState → circles strip updates
    if (mounted) {
      setState(() => _capturedImages.add(path));
    }
  }

  void _triggerFlash() {
    _flashCtrl.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 40), () { if (mounted) _flashCtrl.reverse(); });
    });
  }

  void _openAddDetails(String imagePath) {
    _cameraBloc.add(const PauseCameraEvent());
    Navigator.of(context).push(PageRouteBuilder(
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
    )).then((_) => _cameraBloc.add(const InitializeCameraEvent()));
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

  void _showImageSelectionSheet() {
    if (_capturedImages.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ImageSelectionSheet(
        images: _capturedImages,
        onSelected: (path) { Navigator.of(context).pop(); _openAddDetails(path); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cameraBloc,
      child: Scaffold(
        backgroundColor: Colors.black,
        // BLoC handles init/flash/zoom/switch only — capture is direct
        body: BlocBuilder<CameraBloc, CameraState>(
          buildWhen: (prev, curr) =>
              curr is CameraInitial || curr is CameraLoading || curr is CameraReady || curr is CameraError,
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
    final lastImage = _capturedImages.isNotEmpty ? _capturedImages.last : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview with gesture detection (double-tap flip, pinch zoom)
        // Wrapped separately so gestures here do NOT block the controls below
        GestureDetector(
          onDoubleTap: _onSwitchCamera,
          onScaleStart: (_) { _baseZoom = ready?.currentZoom ?? 1.0; },
          onScaleUpdate: (d) {
            if (ready == null || d.pointerCount < 2) return;
            _cameraBloc.add(SetZoomEvent((_baseZoom * d.scale).clamp(ready.minZoom, ready.maxZoom)));
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
          child: IgnorePointer(child: Container(height: 320,
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

        // Bottom controls — NOT inside any gesture detector
        Positioned(bottom: 0, left: 0, right: 0,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_capturedImages.isNotEmpty) ...[
                  _CirclesStrip(images: _capturedImages, onTap: _openAddDetails),
                  const SizedBox(height: 14),
                ] else
                  const SizedBox(height: 8),
                if (_capturedImages.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text('Tap to capture  -  Double-tap to flip',
                        style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 12))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _LastImageCircle(
                        imagePath: lastImage,
                        onTap: _capturedImages.isEmpty ? _openGallery : _showImageSelectionSheet,
                      ),
                      // Capture button — direct GestureDetector, no parent interference
                      _DirectCaptureButton(
                        pulseScale: _pulseScale,
                        pulseOpacity: _pulseOpacity,
                        captureScale: _captureScale,
                        onCapture: _onCapture,
                        captureCtrl: _captureCtrl,
                      ),
                      _GallerySquare(onTap: _openGallery),
                    ],
                  ),
                ),
              ],
            ),
          )),

        // Photo count badge
        if (_capturedImages.isNotEmpty)
          Positioned(top: 0, right: 0,
            child: SafeArea(child: Padding(
              padding: const EdgeInsets.only(right: 14, top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20), boxShadow: AppTheme.primaryGlow),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text('${_capturedImages.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ))),
      ],
    );
  }
}

class _ImageSelectionSheet extends StatelessWidget {
  final List<String> images;
  final void Function(String) onSelected;
  const _ImageSelectionSheet({required this.images, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65, minChildSize: 0.4, maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Row(
                children: [
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select a Photo',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('Tap any photo to add details',
                          style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  )),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(width: 32, height: 32,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white12),
                        child: const Icon(Icons.close_rounded, color: Colors.white54, size: 18))),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 16),
            Expanded(
              child: GridView.builder(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
                itemCount: images.length,
                itemBuilder: (_, i) {
                  final path = images[images.length - 1 - i];
                  final isNewest = i == 0;
                  return GestureDetector(
                    onTap: () => onSelected(path),
                    child: Stack(fit: StackFit.expand, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(File(path), fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: Colors.white12,
                                child: const Icon(Icons.image_outlined, color: Colors.white24, size: 28)))),
                      if (isNewest) Positioned.fill(child: Container(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.primary, width: 2.5)))),
                      if (isNewest) Positioned(top: 6, right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(6)),
                            child: const Text('New',
                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)))),
                    ]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CirclesStrip extends StatelessWidget {
  final List<String> images;
  final void Function(String) onTap;
  const _CirclesStrip({required this.images, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal, reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: images.length,
        itemBuilder: (_, i) => _CircleThumb(
          key: ValueKey(images[i]),
          imagePath: images[i],
          isNewest: i == images.length - 1,
          onTap: () => onTap(images[i]),
        ),
      ),
    );
  }
}

class _CircleThumb extends StatefulWidget {
  final String imagePath;
  final bool isNewest;
  final VoidCallback onTap;
  const _CircleThumb({Key? key, required this.imagePath, required this.isNewest, required this.onTap}) : super(key: key);

  @override
  State<_CircleThumb> createState() => _CircleThumbState();
}

class _CircleThumbState extends State<_CircleThumb> with TickerProviderStateMixin {
  late AnimationController _enter;
  late Animation<double> _enterFade, _enterScale;
  late AnimationController _press;
  late Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _enterFade = CurvedAnimation(parent: _enter, curve: Curves.easeOut);
    _enterScale = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutBack));
    _enter.forward();
    _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _pressScale = Tween<double>(begin: 1.0, end: 0.84)
        .animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() { _enter.dispose(); _press.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: FadeTransition(
        opacity: _enterFade,
        child: ScaleTransition(
          scale: _enterScale,
          child: GestureDetector(
            onTapDown: (_) => _press.forward(),
            onTapUp: (_) { _press.reverse(); widget.onTap(); },
            onTapCancel: () => _press.reverse(),
            child: ScaleTransition(
              scale: _pressScale,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.isNewest ? AppTheme.primary : Colors.white.withOpacity(0.55),
                        width: widget.isNewest ? 2.5 : 1.5,
                      ),
                      boxShadow: [BoxShadow(
                        color: widget.isNewest ? AppTheme.primary.withOpacity(0.4) : Colors.black.withOpacity(0.3),
                        blurRadius: widget.isNewest ? 12 : 6,
                      )],
                    ),
                    child: ClipOval(child: Image.file(File(widget.imagePath), fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: Colors.white12,
                            child: const Icon(Icons.image_outlined, color: Colors.white38, size: 20)))),
                  ),
                  if (widget.isNewest)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(6),
                          boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.5), blurRadius: 4)]),
                      child: const Text('Tap',
                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LastImageCircle extends StatefulWidget {
  final String? imagePath;
  final VoidCallback onTap;
  const _LastImageCircle({this.imagePath, required this.onTap});

  @override
  State<_LastImageCircle> createState() => _LastImageCircleState();
}

class _LastImageCircleState extends State<_LastImageCircle> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.85).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.imagePath != null ? Colors.white.withOpacity(0.8) : Colors.white.withOpacity(0.3),
              width: 2,
            ),
            color: Colors.white.withOpacity(0.1),
          ),
          child: widget.imagePath != null
              ? ClipOval(child: Image.file(File(widget.imagePath!), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.photo_library_outlined, color: Colors.white54, size: 22)))
              : const Icon(Icons.photo_library_outlined, color: Colors.white54, size: 22),
        ),
      ),
    );
  }
}

class _CaptureBtn extends StatelessWidget {
  final Animation<double> pulseScale, pulseOpacity;
  final GestureTapDownCallback onTapDown;
  final GestureTapUpCallback onTapUp;
  final VoidCallback onTapCancel;

  const _CaptureBtn({
    required this.pulseScale, required this.pulseOpacity,
    required this.onTapDown, required this.onTapUp, required this.onTapCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: onTapDown, onTapUp: onTapUp, onTapCancel: onTapCancel,
      child: SizedBox(
        width: 88, height: 88,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: pulseScale,
              builder: (_, __) => Transform.scale(
                scale: pulseScale.value,
                child: Opacity(opacity: pulseOpacity.value,
                    child: Container(width: 88, height: 88,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5)))))),
            Container(width: 80, height: 80,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3.5))),
            Container(width: 64, height: 64,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _GallerySquare extends StatefulWidget {
  final VoidCallback onTap;
  const _GallerySquare({required this.onTap});

  @override
  State<_GallerySquare> createState() => _GallerySquareState();
}

class _GallerySquareState extends State<_GallerySquare> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.85).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
          ),
          child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}



// _DirectCaptureButton — standalone widget with its own GestureDetector.
// Uses HitTestBehavior.opaque so taps always register regardless of parent.
// onCapture is async — the button fires and forgets (no await in onTapUp).
class _DirectCaptureButton extends StatelessWidget {
  final Animation<double> pulseScale;
  final Animation<double> pulseOpacity;
  final Animation<double> captureScale;
  final Future<void> Function() onCapture; // async callback
  final AnimationController captureCtrl;

  const _DirectCaptureButton({
    required this.pulseScale,
    required this.pulseOpacity,
    required this.captureScale,
    required this.onCapture,
    required this.captureCtrl,
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
          width: 88, height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: pulseScale,
                builder: (_, __) => Transform.scale(
                  scale: pulseScale.value,
                  child: Opacity(opacity: pulseOpacity.value,
                      child: Container(width: 88, height: 88,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5)))))),
              Container(width: 80, height: 80,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3.5))),
              Container(width: 64, height: 64,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

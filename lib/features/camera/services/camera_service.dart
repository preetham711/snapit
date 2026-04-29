import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// CameraService — singleton hardware abstraction.
///
/// Key design decisions:
/// - Always fully dispose before reinitializing (avoids "used after disposed")
/// - pausePreview / resumePreview are safe no-ops if controller is gone
/// - initializeCamera always creates a fresh CameraController
class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  CameraController? _controller;
  bool _isInitialized = false;
  bool _isFlashOn = false;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  CameraLensDirection _lensDirection = CameraLensDirection.back;

  bool get isInitialized => _isInitialized;
  bool get isFlashOn => _isFlashOn;
  double get currentZoom => _currentZoom;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  CameraLensDirection get currentLensDirection => _lensDirection;

  CameraController get controller {
    if (_controller == null || !_isInitialized) {
      throw StateError('Camera not initialized');
    }
    return _controller!;
  }

  // ── Initialize ─────────────────────────────────────────────────────────────

  Future<void> initializeCamera({
    CameraLensDirection lensDirection = CameraLensDirection.back,
  }) async {
    // Always dispose first to avoid "used after disposed" errors
    await _safeDispose();

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No cameras available');

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == lensDirection,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      await _controller!.setFlashMode(FlashMode.off);

      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _currentZoom = _minZoom;
      _lensDirection = lensDirection;
      _isFlashOn = false;
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      debugPrint('[CameraService] initializeCamera error: $e');
      rethrow;
    }
  }

  // ── Switch camera ──────────────────────────────────────────────────────────

  Future<void> switchCamera() async {
    final newDir = _lensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    await initializeCamera(lensDirection: newDir);
  }

  // ── Flash ──────────────────────────────────────────────────────────────────

  Future<void> toggleFlash() async {
    if (!_isInitialized || _controller == null) return;
    _isFlashOn = !_isFlashOn;
    try {
      await _controller!
          .setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    } catch (e) {
      debugPrint('[CameraService] toggleFlash error: $e');
      _isFlashOn = !_isFlashOn; // revert
    }
  }

  // ── Zoom ───────────────────────────────────────────────────────────────────

  Future<void> setZoom(double zoom) async {
    if (!_isInitialized || _controller == null) return;
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    try {
      await _controller!.setZoomLevel(clamped);
      _currentZoom = clamped;
    } catch (e) {
      debugPrint('[CameraService] setZoom error: $e');
    }
  }

  // ── Focus / exposure ───────────────────────────────────────────────────────

  Future<void> setFocusAndExposure(Offset point) async {
    if (!_isInitialized || _controller == null) return;
    try {
      if (_controller!.value.focusPointSupported) {
        await _controller!.setFocusPoint(point);
      }
      if (_controller!.value.exposurePointSupported) {
        await _controller!.setExposurePoint(point);
      }
    } catch (e) {
      debugPrint('[CameraService] setFocusAndExposure error: $e');
    }
  }

  // ── Capture ────────────────────────────────────────────────────────────────

  Future<XFile> takePicture() async {
    if (!_isInitialized || _controller == null) {
      throw StateError('Camera not ready');
    }
    return _controller!.takePicture();
  }

  // ── Pause / Resume ─────────────────────────────────────────────────────────
  // These are intentionally no-ops — we use full dispose/reinit instead,
  // which is more reliable across Android OEM camera implementations.

  Future<void> pausePreview() async {
    // No-op: full dispose/reinit on navigation is safer
  }

  Future<void> resumePreview() async {
    // No-op: caller should send InitializeCameraEvent instead
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _safeDispose();
  }

  void reset() {
    _isFlashOn = false;
    _currentZoom = _minZoom;
    _isInitialized = false;
  }

  Future<void> _safeDispose() async {
    if (_controller != null) {
      try {
        if (_controller!.value.isInitialized) {
          await _controller!.dispose();
        }
      } catch (e) {
        debugPrint('[CameraService] _safeDispose error (ignored): $e');
      } finally {
        _controller = null;
        _isInitialized = false;
      }
    }
  }
}

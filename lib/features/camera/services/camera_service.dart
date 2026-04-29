import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// CameraService — singleton hardware abstraction.
///
/// Design:
/// - Single CameraController instance, always disposed before reinit
/// - _isCapturing flag prevents concurrent capture calls
/// - captureImage() is the single entry point for taking photos
///   — it handles the full pipeline: takePicture → copy to docs dir → return path
/// - All methods are safe to call even when not initialized (no-ops / throws)
class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false; // guard against concurrent captures
  bool _isFlashOn = false;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  CameraLensDirection _lensDirection = CameraLensDirection.back;

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isInitialized => _isInitialized;
  bool get isCapturing => _isCapturing;
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
    await _safeDispose();
    _isCapturing = false;

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
      _isFlashOn = !_isFlashOn; // revert on failure
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

  /// Captures a photo and saves it to the app documents directory.
  ///
  /// Returns the saved file path, or null if:
  ///   - camera is not initialized
  ///   - a capture is already in progress
  ///   - an error occurs
  ///
  /// This is the ONLY method that should be called for capture.
  /// It handles the full pipeline atomically with the _isCapturing guard.
  Future<String?> captureImage() async {
    // Guard: not initialized
    if (!_isInitialized || _controller == null) {
      debugPrint('[CameraService] captureImage: camera not ready');
      return null;
    }

    // Guard: already capturing (prevents double-tap issues)
    if (_isCapturing) {
      debugPrint('[CameraService] captureImage: already capturing, skipped');
      return null;
    }

    _isCapturing = true;
    try {
      // Take the picture
      final xFile = await _controller!.takePicture();

      // Copy to permanent location with timestamp name
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyy_MM_dd_HH_mm_ss').format(DateTime.now());
      final destPath = '${directory.path}/IMG_$timestamp.jpg';

      await File(xFile.path).copy(destPath);

      debugPrint('[CameraService] captureImage: saved to $destPath');
      return destPath;
    } catch (e) {
      debugPrint('[CameraService] captureImage error: $e');
      return null;
    } finally {
      _isCapturing = false;
    }
  }

  /// Legacy method — kept for BLoC compatibility.
  /// Prefer captureImage() for direct use.
  Future<XFile> takePicture() async {
    if (!_isInitialized || _controller == null) {
      throw StateError('Camera not ready');
    }
    return _controller!.takePicture();
  }

  // ── Pause / Resume ─────────────────────────────────────────────────────────

  Future<void> pausePreview() async {
    // No-op: full dispose/reinit on navigation is more reliable
  }

  Future<void> resumePreview() async {
    // No-op: caller sends InitializeCameraEvent instead
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _safeDispose();
  }

  void reset() {
    _isFlashOn = false;
    _currentZoom = _minZoom;
    _isInitialized = false;
    _isCapturing = false;
  }

  Future<void> _safeDispose() async {
    _isCapturing = false;
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

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../services/camera_service.dart';

part 'camera_event.dart';
part 'camera_state.dart';

class CameraBloc extends Bloc<CameraEvent, CameraState> {
  final CameraService _cameraService = CameraService();
  String? _lastImagePath;

  CameraBloc() : super(const CameraInitial()) {
    on<InitializeCameraEvent>(_onInitializeCamera);
    on<CapturePhotoEvent>(_onCapturePhoto);
    on<ToggleFlashEvent>(_onToggleFlash);
    on<SetZoomEvent>(_onSetZoom);
    on<SwitchCameraEvent>(_onSwitchCamera);
    on<ToggleQuickSaveEvent>(_onToggleQuickSave);
    on<ResetCameraEvent>(_onResetCamera);
    on<SetFocusPointEvent>(_onSetFocusPoint);
    on<PauseCameraEvent>(_onPauseCamera);
    on<ResumeCameraEvent>(_onResumeCamera);
  }

  Future<void> _onInitializeCamera(
    InitializeCameraEvent event,
    Emitter<CameraState> emit,
  ) async {
    // Preserve captured images from current session across reinits
    final prevImages = state is CameraReady
        ? (state as CameraReady).capturedImages
        : <String>[];

    emit(const CameraLoading());
    try {
      await _cameraService.initializeCamera();
      emit(_readyState().copyWith(capturedImages: prevImages));
    } catch (e) {
      emit(CameraError('Failed to initialize camera: $e'));
    }
  }

  Future<void> _onCapturePhoto(
    CapturePhotoEvent event,
    Emitter<CameraState> emit,
  ) async {
    if (state is! CameraReady) return;
    final currentState = state as CameraReady;

    emit(const CameraCapturing());
    try {
      final xFile = await _cameraService.takePicture();
      final directory = await getApplicationDocumentsDirectory();
      final timestamp =
          DateFormat('yyyy_MM_dd_HH_mm_ss').format(DateTime.now());
      final imagePath = '${directory.path}/IMG_$timestamp.jpg';

      await File(xFile.path).copy(imagePath);
      _lastImagePath = imagePath;

      // Add to captured images list
      final updatedImages = [...currentState.capturedImages, imagePath];

      // Emit ready with updated lastImagePath + capturedImages
      emit(currentState.copyWith(
        lastImagePath: imagePath,
        capturedImages: updatedImages,
        clearFocusPoint: true,
      ));
      // Then emit captured event so UI can react (flash)
      emit(PhotoCaptured(imagePath, quickSave: currentState.isQuickSaveEnabled));
    } catch (e) {
      emit(CameraError('Failed to capture photo: $e'));
      emit(currentState);
    }
  }

  Future<void> _onToggleFlash(
    ToggleFlashEvent event,
    Emitter<CameraState> emit,
  ) async {
    if (state is! CameraReady) return;
    try {
      await _cameraService.toggleFlash();
      emit((state as CameraReady)
          .copyWith(isFlashOn: _cameraService.isFlashOn));
    } catch (e) {
      emit(CameraError('Failed to toggle flash: $e'));
    }
  }

  Future<void> _onSetZoom(
    SetZoomEvent event,
    Emitter<CameraState> emit,
  ) async {
    if (state is! CameraReady) return;
    try {
      await _cameraService.setZoom(event.zoom);
      emit((state as CameraReady)
          .copyWith(currentZoom: _cameraService.currentZoom));
    } catch (_) {}
  }

  Future<void> _onSwitchCamera(
    SwitchCameraEvent event,
    Emitter<CameraState> emit,
  ) async {
    if (state is! CameraReady) return;
    final currentState = state as CameraReady;
    emit(const CameraLoading());
    try {
      await _cameraService.switchCamera();
      emit(CameraReady(
        isFlashOn: _cameraService.isFlashOn,
        currentZoom: _cameraService.currentZoom,
        minZoom: _cameraService.minZoom,
        maxZoom: _cameraService.maxZoom,
        isQuickSaveEnabled: currentState.isQuickSaveEnabled,
        isFrontCamera: !currentState.isFrontCamera,
        lastImagePath: _lastImagePath,
        capturedImages: currentState.capturedImages, // preserve session images
      ));
    } catch (e) {
      emit(CameraError('Failed to switch camera: $e'));
    }
  }

  Future<void> _onToggleQuickSave(
    ToggleQuickSaveEvent event,
    Emitter<CameraState> emit,
  ) async {
    if (state is! CameraReady) return;
    final s = state as CameraReady;
    emit(s.copyWith(isQuickSaveEnabled: !s.isQuickSaveEnabled));
  }

  Future<void> _onResetCamera(
    ResetCameraEvent event,
    Emitter<CameraState> emit,
  ) async {
    try {
      await _cameraService.dispose();
      _cameraService.reset();
      _lastImagePath = null;
      emit(const CameraInitial());
    } catch (e) {
      emit(CameraError('Failed to reset camera: $e'));
    }
  }

  Future<void> _onSetFocusPoint(
    SetFocusPointEvent event,
    Emitter<CameraState> emit,
  ) async {
    if (state is! CameraReady) return;
    await _cameraService.setFocusAndExposure(event.point);
    emit((state as CameraReady).copyWith(focusPoint: event.point));
  }

  Future<void> _onPauseCamera(
    PauseCameraEvent event,
    Emitter<CameraState> emit,
  ) async {
    // Fully dispose the camera when navigating away.
    // This prevents "used after disposed" errors on resume.
    await _cameraService.dispose();
  }

  Future<void> _onResumeCamera(
    ResumeCameraEvent event,
    Emitter<CameraState> emit,
  ) async {
    // Only reinitialize if not already ready
    if (_cameraService.isInitialized) return;

    // Save captured images before emitting loading state
    final prevImages = state is CameraReady
        ? (state as CameraReady).capturedImages
        : <String>[];

    emit(const CameraLoading());
    try {
      await _cameraService.initializeCamera(
        lensDirection: _cameraService.currentLensDirection,
      );
      emit(_readyState().copyWith(capturedImages: prevImages));
    } catch (e) {
      emit(CameraError('Failed to resume camera: $e'));
    }
  }

  CameraReady _readyState() => CameraReady(
        isFlashOn: _cameraService.isFlashOn,
        currentZoom: _cameraService.currentZoom,
        minZoom: _cameraService.minZoom,
        maxZoom: _cameraService.maxZoom,
        isQuickSaveEnabled: false,
        isFrontCamera:
            _cameraService.currentLensDirection == CameraLensDirection.front,
        lastImagePath: _lastImagePath,
      );

  @override
  Future<void> close() async {
    await _cameraService.dispose();
    return super.close();
  }
}

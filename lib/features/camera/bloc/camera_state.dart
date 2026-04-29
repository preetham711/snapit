part of 'camera_bloc.dart';

abstract class CameraState extends Equatable {
  const CameraState();

  @override
  List<Object?> get props => [];
}

class CameraInitial extends CameraState {
  const CameraInitial();
}

class CameraLoading extends CameraState {
  const CameraLoading();
}

class CameraReady extends CameraState {
  final bool isFlashOn;
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final bool isQuickSaveEnabled;
  final bool isFrontCamera;
  final String? lastImagePath;
  final List<String> capturedImages; // all images taken this session
  final Offset? focusPoint;

  const CameraReady({
    required this.isFlashOn,
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.isQuickSaveEnabled,
    required this.isFrontCamera,
    this.lastImagePath,
    this.capturedImages = const [],
    this.focusPoint,
  });

  CameraReady copyWith({
    bool? isFlashOn,
    double? currentZoom,
    double? minZoom,
    double? maxZoom,
    bool? isQuickSaveEnabled,
    bool? isFrontCamera,
    String? lastImagePath,
    List<String>? capturedImages,
    Offset? focusPoint,
    bool clearFocusPoint = false,
  }) {
    return CameraReady(
      isFlashOn: isFlashOn ?? this.isFlashOn,
      currentZoom: currentZoom ?? this.currentZoom,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      isQuickSaveEnabled: isQuickSaveEnabled ?? this.isQuickSaveEnabled,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      lastImagePath: lastImagePath ?? this.lastImagePath,
      capturedImages: capturedImages ?? this.capturedImages,
      focusPoint: clearFocusPoint ? null : (focusPoint ?? this.focusPoint),
    );
  }

  @override
  List<Object?> get props => [
        isFlashOn,
        currentZoom,
        minZoom,
        maxZoom,
        isQuickSaveEnabled,
        isFrontCamera,
        lastImagePath,
        capturedImages,
        focusPoint,
      ];
}

class CameraCapturing extends CameraState {
  const CameraCapturing();
}

class PhotoCaptured extends CameraState {
  final String imagePath;
  final bool quickSave;

  const PhotoCaptured(this.imagePath, {this.quickSave = false});

  @override
  List<Object?> get props => [imagePath, quickSave];
}

class CameraError extends CameraState {
  final String message;

  const CameraError(this.message);

  @override
  List<Object?> get props => [message];
}

part of 'camera_bloc.dart';

abstract class CameraEvent extends Equatable {
  const CameraEvent();

  @override
  List<Object?> get props => [];
}

class InitializeCameraEvent extends CameraEvent {
  const InitializeCameraEvent();
}

class CapturePhotoEvent extends CameraEvent {
  const CapturePhotoEvent();
}

class ToggleFlashEvent extends CameraEvent {
  const ToggleFlashEvent();
}

class SetZoomEvent extends CameraEvent {
  final double zoom;
  const SetZoomEvent(this.zoom);

  @override
  List<Object?> get props => [zoom];
}

class SwitchCameraEvent extends CameraEvent {
  const SwitchCameraEvent();
}

class ToggleQuickSaveEvent extends CameraEvent {
  const ToggleQuickSaveEvent();
}

class ResetCameraEvent extends CameraEvent {
  const ResetCameraEvent();
}

class SetFocusPointEvent extends CameraEvent {
  final Offset point;
  const SetFocusPointEvent(this.point);

  @override
  List<Object?> get props => [point];
}

class PauseCameraEvent extends CameraEvent {
  const PauseCameraEvent();
}

class ResumeCameraEvent extends CameraEvent {
  const ResumeCameraEvent();
}

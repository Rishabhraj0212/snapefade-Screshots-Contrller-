import 'dart:typed_data';
import '../entities/screenshot_entity.dart';
import '../repositories/screenshot_repository.dart';

class GetAllScreenshotsUseCase {
  final ScreenshotRepository repository;
  GetAllScreenshotsUseCase(this.repository);

  Future<List<ScreenshotEntity>> call() => repository.getAllScreenshots();
}

class CancelScheduledDeletionUseCase {
  final ScreenshotRepository repository;
  CancelScheduledDeletionUseCase(this.repository);

  Future<void> call(String id) => repository.cancelScheduledDeletion(id);
}

class IsMonitoringEnabledUseCase {
  final ScreenshotRepository repository;
  IsMonitoringEnabledUseCase(this.repository);

  Future<bool> call() => repository.isMonitoringEnabled();
}

class SetMonitoringEnabledUseCase {
  final ScreenshotRepository repository;
  SetMonitoringEnabledUseCase(this.repository);

  Future<void> call(bool enabled) => repository.setMonitoringEnabled(enabled);
}

class GetDefaultDurationUseCase {
  final ScreenshotRepository repository;
  GetDefaultDurationUseCase(this.repository);

  Future<Duration?> call() => repository.getDefaultDuration();
}

class SetDefaultDurationUseCase {
  final ScreenshotRepository repository;
  SetDefaultDurationUseCase(this.repository);

  Future<void> call(Duration? duration) => repository.setDefaultDuration(duration);
}

class CanScheduleExactAlarmsUseCase {
  final ScreenshotRepository repository;
  CanScheduleExactAlarmsUseCase(this.repository);

  Future<bool> call() => repository.canScheduleExactAlarms();
}

class GetThumbnailUseCase {
  final ScreenshotRepository repository;
  GetThumbnailUseCase(this.repository);

  Future<Uint8List?> call(String id) => repository.getThumbnail(id);
}

class GetPreviewUseCase {
  final ScreenshotRepository repository;
  GetPreviewUseCase(this.repository);

  Future<Uint8List?> call(String id) => repository.getPreview(id);
}

class ExtendScheduledDeletionUseCase {
  final ScreenshotRepository repository;
  ExtendScheduledDeletionUseCase(this.repository);

  Future<bool> call(String id, Duration additional) =>
      repository.extendScheduledDeletion(id, additional);
}

import 'dart:typed_data';
import '../entities/screenshot_entity.dart';

abstract class ScreenshotRepository {
  Future<List<ScreenshotEntity>> getAllScreenshots();
  Future<void> cancelScheduledDeletion(String id);
  Future<bool> isMonitoringEnabled();
  Future<void> setMonitoringEnabled(bool enabled);
  Future<Duration?> getDefaultDuration();
  Future<void> setDefaultDuration(Duration? duration);
  Future<bool> canScheduleExactAlarms();
  Future<Uint8List?> getThumbnail(String id);
  Future<Uint8List?> getPreview(String id);
  Future<bool> extendScheduledDeletion(String id, Duration additional);
  Stream<void> get changes;
}

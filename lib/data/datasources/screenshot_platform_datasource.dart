import 'dart:typed_data';
import '../../core/platform/screenshot_platform_channel.dart';
import '../../domain/entities/screenshot_entity.dart';

abstract class ScreenshotPlatformDataSource {
  Future<List<ScreenshotEntity>> getAll();
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

class ScreenshotPlatformDataSourceImpl implements ScreenshotPlatformDataSource {
  final ScreenshotPlatformChannel _channel;

  ScreenshotPlatformDataSourceImpl(this._channel);

  @override
  Future<List<ScreenshotEntity>> getAll() async {
    final raw = await _channel.getManagedScreenshots();
    return raw.map(ScreenshotEntity.fromPlatformMap).toList();
  }

  @override
  Future<void> cancelScheduledDeletion(String id) => _channel.cancelScheduledDeletion(id);

  @override
  Future<bool> isMonitoringEnabled() => _channel.isMonitoringEnabled();

  @override
  Future<void> setMonitoringEnabled(bool enabled) =>
      enabled ? _channel.startMonitoring() : _channel.stopMonitoring();

  @override
  Future<Duration?> getDefaultDuration() => _channel.getDefaultDuration();

  @override
  Future<void> setDefaultDuration(Duration? duration) => _channel.setDefaultDuration(duration);

  @override
  Future<bool> canScheduleExactAlarms() => _channel.canScheduleExactAlarms();

  @override
  Future<Uint8List?> getThumbnail(String id) => _channel.getThumbnail(id);

  @override
  Future<Uint8List?> getPreview(String id) => _channel.getPreview(id);

  @override
  Future<bool> extendScheduledDeletion(String id, Duration additional) =>
      _channel.extendScheduledDeletion(id, additional);

  @override
  Stream<void> get changes => _channel.changes;
}

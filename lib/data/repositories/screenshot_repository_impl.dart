import 'dart:typed_data';
import '../../domain/entities/screenshot_entity.dart';
import '../../domain/repositories/screenshot_repository.dart';
import '../datasources/screenshot_platform_datasource.dart';

class ScreenshotRepositoryImpl implements ScreenshotRepository {
  final ScreenshotPlatformDataSource _dataSource;

  ScreenshotRepositoryImpl(this._dataSource);

  @override
  Future<List<ScreenshotEntity>> getAllScreenshots() => _dataSource.getAll();

  @override
  Future<void> cancelScheduledDeletion(String id) => _dataSource.cancelScheduledDeletion(id);

  @override
  Future<bool> isMonitoringEnabled() => _dataSource.isMonitoringEnabled();

  @override
  Future<void> setMonitoringEnabled(bool enabled) => _dataSource.setMonitoringEnabled(enabled);

  @override
  Future<Duration?> getDefaultDuration() => _dataSource.getDefaultDuration();

  @override
  Future<void> setDefaultDuration(Duration? duration) => _dataSource.setDefaultDuration(duration);

  @override
  Future<bool> canScheduleExactAlarms() => _dataSource.canScheduleExactAlarms();

  @override
  Future<Uint8List?> getThumbnail(String id) => _dataSource.getThumbnail(id);

  @override
  Future<Uint8List?> getPreview(String id) => _dataSource.getPreview(id);

  @override
  Future<bool> extendScheduledDeletion(String id, Duration additional) =>
      _dataSource.extendScheduledDeletion(id, additional);

  @override
  Stream<void> get changes => _dataSource.changes;
}

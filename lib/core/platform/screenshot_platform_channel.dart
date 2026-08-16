import 'package:flutter/services.dart';

/// Thin wrapper over the native MethodChannel/EventChannel. Native (Kotlin) owns
/// detection, the choice prompt, and deletion scheduling entirely on its own -
/// this channel only exists so the Flutter UI can display and manage what native
/// already tracks. Nothing here is required for detection/scheduling/deletion to work.
class ScreenshotPlatformChannel {
  static const MethodChannel _methodChannel = MethodChannel('secure_screenshot/monitor');
  static const EventChannel _eventChannel = EventChannel('secure_screenshot/monitor/events');

  Future<void> startMonitoring() => _methodChannel.invokeMethod('startMonitoring');

  Future<void> stopMonitoring() => _methodChannel.invokeMethod('stopMonitoring');

  Future<bool> isMonitoringEnabled() async {
    final enabled = await _methodChannel.invokeMethod<bool>('isMonitoringEnabled');
    return enabled ?? false;
  }

  Future<List<Map<Object?, Object?>>> getManagedScreenshots() async {
    final raw = await _methodChannel.invokeMethod<List<Object?>>('getManagedScreenshots');
    return (raw ?? const []).cast<Map<Object?, Object?>>();
  }

  Future<void> cancelScheduledDeletion(String id) =>
      _methodChannel.invokeMethod('cancelScheduledDeletion', {'id': id});

  Future<Duration?> getDefaultDuration() async {
    final millis = await _methodChannel.invokeMethod<int>('getDefaultDurationMillis');
    return millis == null ? null : Duration(milliseconds: millis);
  }

  Future<void> setDefaultDuration(Duration? duration) =>
      _methodChannel.invokeMethod('setDefaultDurationMillis', {'millis': duration?.inMilliseconds});

  Future<bool> canScheduleExactAlarms() async {
    final canSchedule = await _methodChannel.invokeMethod<bool>('canScheduleExactAlarms');
    return canSchedule ?? true;
  }

  /// Decoded fresh from MediaStore on every call - never cached to disk on either side.
  Future<Uint8List?> getThumbnail(String id) =>
      _methodChannel.invokeMethod<Uint8List>('getThumbnail', {'id': id});

  /// Larger decode than [getThumbnail], for the full-screen preview.
  Future<Uint8List?> getPreview(String id) =>
      _methodChannel.invokeMethod<Uint8List>('getPreview', {'id': id});

  /// Pushes a scheduled deletion's fire time back by [additional]. Returns false
  /// (rather than throwing) if native refused - either the item resolved out from
  /// under us, or it's within the no-extend cutoff right before the alarm fires.
  Future<bool> extendScheduledDeletion(String id, Duration additional) async {
    try {
      await _methodChannel.invokeMethod('extendScheduledDeletion', {
        'id': id,
        'additionalMillis': additional.inMilliseconds,
      });
      return true;
    } on PlatformException catch (e) {
      if (e.code == 'too_late' || e.code == 'not_scheduled') return false;
      rethrow;
    }
  }

  /// Fires whenever native detects, schedules, or deletes something. UI should
  /// treat this as "go re-fetch the list", not as carrying data itself.
  Stream<void> get changes => _eventChannel.receiveBroadcastStream().map((_) {});
}

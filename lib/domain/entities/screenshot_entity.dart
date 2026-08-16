import 'package:equatable/equatable.dart';

/// Mirrors the status column native (ManagedScreenshotStore) tracks for each
/// detected screenshot. Native is the source of truth; this is a read model.
enum ScreenshotStatus {
  pendingChoice,
  scheduled,
  kept,
  deleted,
  needsConfirmation;

  static ScreenshotStatus fromNative(String value) {
    switch (value) {
      case 'PENDING_CHOICE':
        return ScreenshotStatus.pendingChoice;
      case 'SCHEDULED':
        return ScreenshotStatus.scheduled;
      case 'KEPT':
        return ScreenshotStatus.kept;
      case 'DELETED':
        return ScreenshotStatus.deleted;
      case 'NEEDS_CONFIRMATION':
        return ScreenshotStatus.needsConfirmation;
      default:
        throw ArgumentError('Unknown screenshot status: $value');
    }
  }
}

class ScreenshotEntity extends Equatable {
  final String id;
  final String mediaUri;
  final String displayName;
  final DateTime dateAdded;
  final ScreenshotStatus status;
  final DateTime? deleteAt;

  const ScreenshotEntity({
    required this.id,
    required this.mediaUri,
    required this.displayName,
    required this.dateAdded,
    required this.status,
    this.deleteAt,
  });

  factory ScreenshotEntity.fromPlatformMap(Map<Object?, Object?> map) {
    final deleteAtMillis = map['deleteAtMillis'] as int?;
    return ScreenshotEntity(
      id: map['id'] as String,
      mediaUri: map['mediaUri'] as String,
      displayName: map['displayName'] as String,
      dateAdded: DateTime.fromMillisecondsSinceEpoch(map['dateAddedMillis'] as int),
      status: ScreenshotStatus.fromNative(map['status'] as String),
      deleteAt: deleteAtMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(deleteAtMillis)
          : null,
    );
  }

  Duration? get timeRemaining {
    if (deleteAt == null) return null;
    final remaining = deleteAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  List<Object?> get props => [id, mediaUri, displayName, dateAdded, status, deleteAt];
}

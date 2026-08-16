import 'package:permission_handler/permission_handler.dart';

/// Single source of truth for which permissions the app cares about, their
/// label, and why they matter - shared by the first-run onboarding flow and
/// the ongoing checklist on the dashboard so the two never drift apart.
class PermissionSpec {
  final Permission permission;
  final String label;
  final String description;

  const PermissionSpec(this.permission, this.label, this.description);
}

const kMonitoringPermissions = <PermissionSpec>[
  PermissionSpec(
    Permission.systemAlertWindow,
    'Display over other apps',
    'Lets the keep/delete prompt pop up instantly on screen the moment you take a screenshot.',
  ),
  PermissionSpec(
    Permission.manageExternalStorage,
    'All files access',
    'Lets scheduled deletions happen silently, with no confirmation dialog when the timer runs out.',
  ),
  PermissionSpec(
    Permission.notification,
    'Notifications',
    'Used to show that background monitoring is active.',
  ),
  PermissionSpec(
    Permission.photos,
    'Photo access',
    'Lets the app see new screenshots, including ones taken inside other apps.',
  ),
  PermissionSpec(
    Permission.scheduleExactAlarm,
    'Exact alarms',
    'Keeps "delete after 1 minute" accurate instead of running late.',
  ),
  PermissionSpec(
    Permission.ignoreBatteryOptimizations,
    'Battery optimization',
    'Stops aggressive phones from killing the background monitor.',
  ),
];

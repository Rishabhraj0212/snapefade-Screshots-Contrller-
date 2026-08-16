import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/permissions/permission_specs.dart';

/// Ongoing status card for the handful of permissions/toggles that determine how
/// well detection, the instant prompt, and on-time deletion actually work - see
/// [kMonitoringPermissions] for what each one is for. Collapses to a single "all
/// set" summary once everything is granted so it doesn't clutter the dashboard.
class PermissionChecklist extends StatefulWidget {
  const PermissionChecklist({super.key});

  @override
  State<PermissionChecklist> createState() => _PermissionChecklistState();
}

class _PermissionChecklistState extends State<PermissionChecklist> with WidgetsBindingObserver {
  Map<Permission, PermissionStatus> _statuses = {};
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  bool _isOk(PermissionStatus status) => status.isGranted || status == PermissionStatus.limited;

  Future<void> _refresh() async {
    final statuses = <Permission, PermissionStatus>{};
    for (final spec in kMonitoringPermissions) {
      statuses[spec.permission] = await spec.permission.status;
    }
    if (!mounted) return;
    setState(() {
      _statuses = statuses;
      _loading = false;
    });
  }

  Future<void> _request(Permission permission) async {
    final status = _statuses[permission];
    if (status != null && status.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      await permission.request();
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final missing = kMonitoringPermissions
        .where((spec) => !_isOk(_statuses[spec.permission] ?? PermissionStatus.denied))
        .toList();
    final allGranted = missing.isEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              onTap: allGranted ? null : () => setState(() => _expanded = !_expanded),
              leading: Icon(
                allGranted ? Icons.verified_rounded : Icons.privacy_tip_rounded,
                color: allGranted ? const Color(0xFF10B981) : scheme.primary,
              ),
              title: Text(
                allGranted ? 'All permissions granted' : 'Permissions need attention',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                allGranted
                    ? 'Everything is set up correctly'
                    : '${missing.length} of ${kMonitoringPermissions.length} need your input',
              ),
              trailing: allGranted
                  ? null
                  : Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
            ),
            if (_expanded && !allGranted) ...[
              const Divider(height: 1, indent: 16, endIndent: 16),
              ...kMonitoringPermissions.map((spec) {
                final status = _statuses[spec.permission] ?? PermissionStatus.denied;
                final ok = _isOk(status);
                return ListTile(
                  leading: Icon(
                    ok ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: ok
                        ? const Color(0xFF10B981)
                        : (status == PermissionStatus.limited ? const Color(0xFFF59E0B) : scheme.error),
                  ),
                  title: Text(spec.label),
                  subtitle: Text(status == PermissionStatus.limited
                      ? 'Limited - some screenshots may be missed'
                      : (ok ? 'Granted' : spec.description)),
                  trailing: ok ? null : TextButton(
                    onPressed: () => _request(spec.permission),
                    child: const Text('Fix'),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

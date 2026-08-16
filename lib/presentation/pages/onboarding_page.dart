import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/permissions/permission_specs.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingPage({super.key, required this.onFinished});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  Map<Permission, PermissionStatus> _statuses = {};
  bool _loading = true;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _refresh();
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

  bool get _allGranted =>
      kMonitoringPermissions.every((spec) => _isOk(_statuses[spec.permission] ?? PermissionStatus.denied));

  PermissionSpec? get _nextMissing => kMonitoringPermissions
      .where((spec) => !_isOk(_statuses[spec.permission] ?? PermissionStatus.denied))
      .firstOrNull;

  Future<void> _grantNext() async {
    final next = _nextMissing;
    if (next == null) return;
    setState(() => _requesting = true);
    final current = _statuses[next.permission];
    if (current != null && current.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      await next.permission.request();
    }
    await _refresh();
    if (mounted) setState(() => _requesting = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [scheme.primary, scheme.tertiary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(Icons.auto_delete_rounded, color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'SnapFade',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Every screenshot you take, anywhere on your phone, gets a '
                          'quick keep-or-auto-delete prompt. A few one-time permissions '
                          'make that possible:',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                        ),
                        const SizedBox(height: 28),
                        ...kMonitoringPermissions.map((spec) {
                          final status = _statuses[spec.permission] ?? PermissionStatus.denied;
                          final ok = _isOk(status);
                          final isNext = !_loading && !_requesting && spec == _nextMissing;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isNext
                                  ? scheme.primaryContainer.withValues(alpha: 0.5)
                                  : scheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(16),
                              border: isNext ? Border.all(color: scheme.primary, width: 1.5) : null,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  ok ? Icons.check_circle_rounded : Icons.circle_outlined,
                                  color: ok ? const Color(0xFF10B981) : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(spec.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(
                                        spec.description,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _requesting
                                ? null
                                : (_allGranted ? widget.onFinished : _grantNext),
                            child: _requesting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(_allGranted ? 'Get started' : 'Grant "${_nextMissing?.label}"'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: widget.onFinished,
                          child: const Text("I'll do this later"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

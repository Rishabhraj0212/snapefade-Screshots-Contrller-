import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/di/injection_container.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/screenshot_entity.dart';
import '../../domain/usecases/screenshot_usecases.dart';
import '../blocs/screenshot_bloc.dart';
import '../widgets/permission_checklist.dart';
import '../widgets/screenshot_detail_sheet.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    context.read<ScreenshotBloc>().add(LoadScreenshots());
    // Only drives the on-screen countdown label; the actual deletion timing is
    // owned entirely by native AlarmManager and keeps working with this app closed.
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SnapFade'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<ScreenshotBloc, ScreenshotState>(
        builder: (context, state) {
          if (state is ScreenshotError) {
            return _CenteredMessage(message: 'Something went wrong: ${state.message}');
          }
          if (state is! ScreenshotLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async => context.read<ScreenshotBloc>().add(LoadScreenshots()),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _MonitoringHeroCard(
                  enabled: state.monitoringEnabled,
                  onChanged: (enabled) =>
                      context.read<ScreenshotBloc>().add(SetMonitoringEnabled(enabled)),
                ),
                const SizedBox(height: 16),
                _StatsRow(screenshots: state.screenshots),
                const SizedBox(height: 16),
                const PermissionChecklist(),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Pending',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (state.screenshots.isEmpty)
                  const _EmptyScreenshots()
                else
                  ...state.screenshots.map(
                    (s) => Padding(
                      key: ValueKey(s.id),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ScreenshotTile(screenshot: s),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MonitoringHeroCard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _MonitoringHeroCard({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: enabled
              ? [scheme.primary, scheme.tertiary]
              : [scheme.surfaceContainerHigh, scheme.surfaceContainerHigh],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: enabled ? 0.2 : 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              enabled ? Icons.shield_rounded : Icons.shield_outlined,
              color: enabled ? Colors.white : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled ? 'Protection is on' : 'Protection is off',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: enabled ? Colors.white : scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled
                      ? 'Watching for new screenshots device-wide'
                      : 'New screenshots won\'t trigger a prompt',
                  style: TextStyle(
                    color: enabled ? Colors.white.withValues(alpha: 0.85) : scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<ScreenshotEntity> screenshots;
  const _StatsRow({required this.screenshots});

  @override
  Widget build(BuildContext context) {
    // Kept/deleted screenshots aren't tracked once resolved - see remove() in
    // ManagedScreenshotStore.kt - so the only counts worth showing are what's
    // still in flight.
    final awaitingChoice = screenshots.where((s) => s.status == ScreenshotStatus.pendingChoice).length;
    final scheduled = screenshots.where((s) => s.status == ScreenshotStatus.scheduled).length;
    final needsAttention = screenshots.where((s) => s.status == ScreenshotStatus.needsConfirmation).length;

    return Row(
      children: [
        Expanded(child: _StatCard(value: scheduled, status: ScreenshotStatus.scheduled)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(value: awaitingChoice, status: ScreenshotStatus.pendingChoice)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(value: needsAttention, status: ScreenshotStatus.needsConfirmation)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final int value;
  final ScreenshotStatus status;
  const _StatCard({required this.value, required this.status});

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(style.icon, color: style.color, size: 20),
            const SizedBox(height: 6),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text(style.label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _EmptyScreenshots extends StatelessWidget {
  const _EmptyScreenshots();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          children: [
            Icon(Icons.task_alt_rounded, size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Nothing pending', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Kept and deleted screenshots aren\'t tracked here - only\n'
              'ones still awaiting a choice or scheduled for deletion',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenshotTile extends StatefulWidget {
  final ScreenshotEntity screenshot;
  const _ScreenshotTile({required this.screenshot});

  @override
  State<_ScreenshotTile> createState() => _ScreenshotTileState();
}

class _ScreenshotTileState extends State<_ScreenshotTile> {
  Uint8List? _thumbnail;

  @override
  void initState() {
    super.initState();
    if (widget.screenshot.status != ScreenshotStatus.deleted) {
      sl<GetThumbnailUseCase>()(widget.screenshot.id).then((bytes) {
        if (mounted) setState(() => _thumbnail = bytes);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenshot = widget.screenshot;
    final style = StatusStyle.of(screenshot.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showScreenshotDetailSheet(context, screenshot.id),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 48,
                height: 48,
                child: _thumbnail != null
                    ? Image.memory(_thumbnail!, fit: BoxFit.cover)
                    : Container(
                        color: style.color.withValues(alpha: 0.12),
                        child: Icon(style.icon, color: style.color, size: 20),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    screenshot.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: style.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          style.label,
                          style: TextStyle(color: style.color, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _detail(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (screenshot.status == ScreenshotStatus.scheduled)
              TextButton(
                onPressed: () =>
                    context.read<ScreenshotBloc>().add(CancelScheduledDeletion(screenshot.id)),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _detail() {
    final screenshot = widget.screenshot;
    switch (screenshot.status) {
      case ScreenshotStatus.pendingChoice:
        return DateFormat('MMM d, HH:mm').format(screenshot.dateAdded);
      case ScreenshotStatus.scheduled:
        return 'in ${_formatDuration(screenshot.timeRemaining ?? Duration.zero)}';
      case ScreenshotStatus.kept:
      case ScreenshotStatus.deleted:
        return DateFormat('MMM d, HH:mm').format(screenshot.dateAdded);
      case ScreenshotStatus.needsConfirmation:
        return 'Grant "All files access" in Settings';
    }
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }
}

class _CenteredMessage extends StatelessWidget {
  final String message;
  const _CenteredMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

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
import 'hms_duration_picker.dart';

/// Below this remaining time, extending is hidden entirely - matches the native
/// refusal in MainActivity.kt (EXTEND_CUTOFF_MILLIS) so the UI never offers an
/// action the platform is about to reject anyway.
const _extendCutoff = Duration(seconds: 15);

void showScreenshotDetailSheet(BuildContext context, String screenshotId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ScreenshotDetailSheet(screenshotId: screenshotId),
  );
}

class ScreenshotDetailSheet extends StatefulWidget {
  final String screenshotId;
  const ScreenshotDetailSheet({super.key, required this.screenshotId});

  @override
  State<ScreenshotDetailSheet> createState() => _ScreenshotDetailSheetState();
}

class _ScreenshotDetailSheetState extends State<ScreenshotDetailSheet> {
  Uint8List? _preview;
  bool _extending = false;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    sl<GetPreviewUseCase>()(widget.screenshotId).then((bytes) {
      if (mounted) setState(() => _preview = bytes);
    });
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _extend(Duration additional) async {
    setState(() => _extending = true);
    final ok = await sl<ExtendScheduledDeletionUseCase>()(widget.screenshotId, additional);
    if (!mounted) return;
    setState(() => _extending = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Too close to deletion time to extend')),
      );
    }
  }

  Future<void> _pickCustomExtension() async {
    final picked = await showHmsDurationPicker(context, initial: const Duration(minutes: 5));
    if (picked != null) await _extend(picked);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScreenshotBloc, ScreenshotState>(
      builder: (context, state) {
        final screenshot = state is ScreenshotLoaded
            ? state.screenshots.where((s) => s.id == widget.screenshotId).firstOrNull
            : null;

        if (screenshot == null) {
          // Resolved (kept/deleted) or otherwise gone while the sheet was open -
          // there's nothing left to preview or extend, so just close.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
          });
          return const SizedBox(height: 200);
        }

        return _SheetContent(
          screenshot: screenshot,
          preview: _preview,
          extending: _extending,
          onExtend: _extend,
          onCustomExtend: _pickCustomExtension,
          onKeep: () {
            context.read<ScreenshotBloc>().add(CancelScheduledDeletion(screenshot.id));
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}

class _SheetContent extends StatelessWidget {
  final ScreenshotEntity screenshot;
  final Uint8List? preview;
  final bool extending;
  final ValueChanged<Duration> onExtend;
  final VoidCallback onCustomExtend;
  final VoidCallback onKeep;

  const _SheetContent({
    required this.screenshot,
    required this.preview,
    required this.extending,
    required this.onExtend,
    required this.onCustomExtend,
    required this.onKeep,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = StatusStyle.of(screenshot.status);
    final remaining = screenshot.timeRemaining;
    final canExtend = screenshot.status == ScreenshotStatus.scheduled &&
        remaining != null &&
        remaining > _extendCutoff;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: preview != null
                    ? Image.memory(preview!, fit: BoxFit.cover)
                    : Container(
                        color: style.color.withValues(alpha: 0.12),
                        child: Center(
                          child: Icon(style.icon, color: style.color, size: 40),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              screenshot.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Captured ${DateFormat('MMM d, HH:mm').format(screenshot.dateAdded)}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(style.icon, color: style.color, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusText(),
                      style: TextStyle(color: style.color, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            if (screenshot.status == ScreenshotStatus.scheduled) ...[
              const SizedBox(height: 20),
              if (canExtend) ...[
                Text(
                  'Extend deletion time',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ExtendButton(
                        label: '+1 min',
                        onPressed: extending ? null : () => onExtend(const Duration(minutes: 1)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ExtendButton(
                        label: '+3 min',
                        onPressed: extending ? null : () => onExtend(const Duration(minutes: 3)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ExtendButton(
                        label: 'Custom',
                        onPressed: extending ? null : onCustomExtend,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(onPressed: onKeep, child: const Text('Keep instead')),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: scheme.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Too close to the scheduled time to extend or keep',
                          style: TextStyle(color: scheme.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusText() {
    switch (screenshot.status) {
      case ScreenshotStatus.pendingChoice:
        return 'Waiting for your choice in the on-screen prompt';
      case ScreenshotStatus.scheduled:
        final remaining = screenshot.timeRemaining ?? Duration.zero;
        return 'Deletes in ${_formatDuration(remaining)}';
      case ScreenshotStatus.needsConfirmation:
        return 'Couldn\'t auto-delete - grant "All files access" in Settings';
      case ScreenshotStatus.kept:
      case ScreenshotStatus.deleted:
        return StatusStyle.of(screenshot.status).label;
    }
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }
}

class _ExtendButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const _ExtendButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

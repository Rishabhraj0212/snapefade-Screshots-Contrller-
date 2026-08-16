import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Hours / Minutes / Seconds duration picker with a live "deletes at" preview,
/// used for setting the default auto-delete duration in Settings. The in-the-moment
/// prompt shown right after a screenshot is detected has its own native (Kotlin)
/// equivalent so it opens instantly without waiting on the Flutter engine.
Future<Duration?> showHmsDurationPicker(
  BuildContext context, {
  Duration initial = const Duration(minutes: 5),
}) {
  return showDialog<Duration>(
    context: context,
    builder: (context) => _HmsDurationDialog(initial: initial),
  );
}

class _HmsDurationDialog extends StatefulWidget {
  final Duration initial;
  const _HmsDurationDialog({required this.initial});

  @override
  State<_HmsDurationDialog> createState() => _HmsDurationDialogState();
}

class _HmsDurationDialogState extends State<_HmsDurationDialog> {
  late int _hours;
  late int _minutes;
  late int _seconds;

  @override
  void initState() {
    super.initState();
    final total = widget.initial.inSeconds;
    _hours = total ~/ 3600;
    _minutes = (total % 3600) ~/ 60;
    _seconds = total % 60;
  }

  Duration get _duration =>
      Duration(hours: _hours, minutes: _minutes, seconds: _seconds);

  @override
  Widget build(BuildContext context) {
    final deletesAt = DateTime.now().add(_duration);
    final isValid = _duration.inSeconds > 0;

    return AlertDialog(
      title: const Text('Custom duration'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _unitPicker('Hours', _hours, 23, (v) => setState(() => _hours = v)),
              _unitPicker('Minutes', _minutes, 59, (v) => setState(() => _minutes = v)),
              _unitPicker('Seconds', _seconds, 59, (v) => setState(() => _seconds = v)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isValid
                ? 'Deletes at ${DateFormat('h:mm:ss a').format(deletesAt)}'
                : 'Pick a duration above 0 seconds',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isValid ? () => Navigator.pop(context, _duration) : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  Widget _unitPicker(String label, int value, int max, ValueChanged<int> onChanged) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          DropdownButton<int>(
            value: value,
            isExpanded: true,
            items: List.generate(
              max + 1,
              (i) => DropdownMenuItem(value: i, child: Center(child: Text('$i'))),
            ),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

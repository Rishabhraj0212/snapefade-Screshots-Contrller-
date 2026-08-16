import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection_container.dart';
import '../../domain/usecases/screenshot_usecases.dart';
import '../blocs/screenshot_bloc.dart';
import '../widgets/hms_duration_picker.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Duration? _defaultDuration;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final duration = await sl<GetDefaultDurationUseCase>()();
    if (!mounted) return;
    setState(() {
      _defaultDuration = duration;
      _loading = false;
    });
  }

  Future<void> _setDefault(Duration? duration) async {
    await sl<SetDefaultDurationUseCase>()(duration);
    if (!mounted) return;
    setState(() => _defaultDuration = duration);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Card(
                  child: BlocBuilder<ScreenshotBloc, ScreenshotState>(
                    builder: (context, state) {
                      final enabled = state is ScreenshotLoaded && state.monitoringEnabled;
                      return SwitchListTile(
                        title: const Text('Monitor screenshots', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Watch for new screenshots device-wide'),
                        value: enabled,
                        onChanged: (value) =>
                            context.read<ScreenshotBloc>().add(SetMonitoringEnabled(value)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    'Default action',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Used automatically if you don\'t respond to the on-screen prompt '
                    'within 30 seconds.',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
                ),
                Card(
                  child: Column(
                    children: [
                      _DefaultOptionTile(
                        label: 'Keep permanently',
                        icon: Icons.check_circle_outline_rounded,
                        selected: _defaultDuration == null,
                        onTap: () => _setDefault(null),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _DefaultOptionTile(
                        label: 'Delete after 1 minute',
                        icon: Icons.timer_outlined,
                        selected: _defaultDuration == const Duration(minutes: 1),
                        onTap: () => _setDefault(const Duration(minutes: 1)),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _DefaultOptionTile(
                        label: 'Delete after 3 minutes',
                        icon: Icons.timer_outlined,
                        selected: _defaultDuration == const Duration(minutes: 3),
                        onTap: () => _setDefault(const Duration(minutes: 3)),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        leading: Icon(
                          Icons.tune_rounded,
                          color: _isCustomDuration() ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                        title: const Text('Custom'),
                        subtitle: Text(
                          _isCustomDuration()
                              ? 'Currently ${_defaultDuration!.inMinutes}m ${_defaultDuration!.inSeconds.remainder(60)}s'
                              : 'Pick a specific default duration',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          final picked = await showHmsDurationPicker(
                            context,
                            initial: _defaultDuration ?? const Duration(minutes: 5),
                          );
                          if (picked != null) await _setDefault(picked);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  bool _isCustomDuration() {
    final d = _defaultDuration;
    if (d == null) return false;
    return d != const Duration(minutes: 1) && d != const Duration(minutes: 3);
  }
}

class _DefaultOptionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DefaultOptionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      leading: Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant),
      title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
      trailing: selected ? Icon(Icons.check_circle_rounded, color: scheme.primary) : null,
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/di/injection_container.dart' as di;
import 'core/security/security_service.dart';
import 'core/theme/app_theme.dart';
import 'domain/repositories/screenshot_repository.dart';
import 'domain/usecases/screenshot_usecases.dart';
import 'presentation/blocs/screenshot_bloc.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/onboarding_page.dart';

const _onboardingDoneKey = 'has_completed_onboarding';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Screenshot detection, the choice prompt, and deletion scheduling all run
  // natively (Kotlin) and independently of this Flutter engine - see
  // ScreenshotDetectionService.kt. Nothing needs to be started from Dart for
  // monitoring to work; this app is only the dashboard/settings UI for it.
  await di.initDI();

  final securityService = di.sl<SecurityService>();
  final isSecure = await securityService.isDeviceSecure();

  runApp(MyApp(isSecure: isSecure));
}

class MyApp extends StatelessWidget {
  final bool isSecure;
  const MyApp({super.key, required this.isSecure});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ScreenshotBloc(
        getAllUseCase: di.sl(),
        cancelUseCase: di.sl(),
        isMonitoringEnabledUseCase: di.sl(),
        setMonitoringEnabledUseCase: di.sl(),
        repository: di.sl<ScreenshotRepository>(),
      ),
      child: MaterialApp(
        title: 'SnapFade',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: isSecure
            ? const _AppEntryGate()
            : const Scaffold(
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Device security check failed. This app cannot run on rooted/jailbroken devices.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red, fontSize: 18),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Shows the one-time permission onboarding on first launch (or until the user
/// finishes/skips it), then the dashboard from then on.
class _AppEntryGate extends StatefulWidget {
  const _AppEntryGate();

  @override
  State<_AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<_AppEntryGate> {
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_onboardingDoneKey) ?? false;
    if (!mounted) return;
    setState(() => _showOnboarding = !done);
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingDoneKey, true);
    await di.sl<SetMonitoringEnabledUseCase>()(true);
    if (!mounted) return;
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _showOnboarding!
        ? OnboardingPage(onFinished: _finishOnboarding)
        : const HomePage();
  }
}

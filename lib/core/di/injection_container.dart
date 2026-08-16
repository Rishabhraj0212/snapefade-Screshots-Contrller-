import 'package:get_it/get_it.dart';
import '../../data/datasources/screenshot_platform_datasource.dart';
import '../../data/repositories/screenshot_repository_impl.dart';
import '../../domain/repositories/screenshot_repository.dart';
import '../../domain/usecases/screenshot_usecases.dart';
import '../platform/screenshot_platform_channel.dart';
import '../security/security_service.dart';

final sl = GetIt.instance;

Future<void> initDI() async {
  if (sl.isRegistered<ScreenshotRepository>()) return;

  // Platform
  sl.registerLazySingleton(() => ScreenshotPlatformChannel());

  // Data sources
  sl.registerLazySingleton<ScreenshotPlatformDataSource>(
    () => ScreenshotPlatformDataSourceImpl(sl()),
  );

  // Repository
  sl.registerLazySingleton<ScreenshotRepository>(
    () => ScreenshotRepositoryImpl(sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetAllScreenshotsUseCase(sl()));
  sl.registerLazySingleton(() => CancelScheduledDeletionUseCase(sl()));
  sl.registerLazySingleton(() => IsMonitoringEnabledUseCase(sl()));
  sl.registerLazySingleton(() => SetMonitoringEnabledUseCase(sl()));
  sl.registerLazySingleton(() => GetDefaultDurationUseCase(sl()));
  sl.registerLazySingleton(() => SetDefaultDurationUseCase(sl()));
  sl.registerLazySingleton(() => CanScheduleExactAlarmsUseCase(sl()));
  sl.registerLazySingleton(() => GetThumbnailUseCase(sl()));
  sl.registerLazySingleton(() => GetPreviewUseCase(sl()));
  sl.registerLazySingleton(() => ExtendScheduledDeletionUseCase(sl()));

  // Security
  sl.registerLazySingleton(() => SecurityService());
}

import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/screenshot_entity.dart';
import '../../domain/repositories/screenshot_repository.dart';
import '../../domain/usecases/screenshot_usecases.dart';

abstract class ScreenshotEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadScreenshots extends ScreenshotEvent {}

class CancelScheduledDeletion extends ScreenshotEvent {
  final String id;
  CancelScheduledDeletion(this.id);
  @override
  List<Object?> get props => [id];
}

class SetMonitoringEnabled extends ScreenshotEvent {
  final bool enabled;
  SetMonitoringEnabled(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

abstract class ScreenshotState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ScreenshotInitial extends ScreenshotState {}

class ScreenshotLoading extends ScreenshotState {}

class ScreenshotLoaded extends ScreenshotState {
  final List<ScreenshotEntity> screenshots;
  final bool monitoringEnabled;
  ScreenshotLoaded(this.screenshots, this.monitoringEnabled);
  @override
  List<Object?> get props => [screenshots, monitoringEnabled];
}

class ScreenshotError extends ScreenshotState {
  final String message;
  ScreenshotError(this.message);
  @override
  List<Object?> get props => [message];
}

class ScreenshotBloc extends Bloc<ScreenshotEvent, ScreenshotState> {
  final GetAllScreenshotsUseCase _getAllUseCase;
  final CancelScheduledDeletionUseCase _cancelUseCase;
  final IsMonitoringEnabledUseCase _isMonitoringEnabledUseCase;
  final SetMonitoringEnabledUseCase _setMonitoringEnabledUseCase;
  final ScreenshotRepository _repository;
  StreamSubscription<void>? _changesSubscription;

  ScreenshotBloc({
    required GetAllScreenshotsUseCase getAllUseCase,
    required CancelScheduledDeletionUseCase cancelUseCase,
    required IsMonitoringEnabledUseCase isMonitoringEnabledUseCase,
    required SetMonitoringEnabledUseCase setMonitoringEnabledUseCase,
    required ScreenshotRepository repository,
  }) : _getAllUseCase = getAllUseCase,
       _cancelUseCase = cancelUseCase,
       _isMonitoringEnabledUseCase = isMonitoringEnabledUseCase,
       _setMonitoringEnabledUseCase = setMonitoringEnabledUseCase,
       _repository = repository,
       super(ScreenshotInitial()) {
    on<LoadScreenshots>(_onLoadScreenshots);
    on<CancelScheduledDeletion>(_onCancelScheduledDeletion);
    on<SetMonitoringEnabled>(_onSetMonitoringEnabled);

    // Native pushes an event any time it detects/schedules/deletes something,
    // so the list stays live while the app is in the foreground.
    _changesSubscription = _repository.changes.listen((_) => add(LoadScreenshots()));
  }

  Future<void> _onLoadScreenshots(
    LoadScreenshots event,
    Emitter<ScreenshotState> emit,
  ) async {
    if (state is! ScreenshotLoaded) emit(ScreenshotLoading());
    try {
      final results = await Future.wait([
        _getAllUseCase(),
        _isMonitoringEnabledUseCase(),
      ]);
      emit(ScreenshotLoaded(
        results[0] as List<ScreenshotEntity>,
        results[1] as bool,
      ));
    } catch (e) {
      emit(ScreenshotError(e.toString()));
    }
  }

  Future<void> _onCancelScheduledDeletion(
    CancelScheduledDeletion event,
    Emitter<ScreenshotState> emit,
  ) async {
    try {
      await _cancelUseCase(event.id);
      add(LoadScreenshots());
    } catch (e) {
      emit(ScreenshotError(e.toString()));
    }
  }

  Future<void> _onSetMonitoringEnabled(
    SetMonitoringEnabled event,
    Emitter<ScreenshotState> emit,
  ) async {
    try {
      await _setMonitoringEnabledUseCase(event.enabled);
      add(LoadScreenshots());
    } catch (e) {
      emit(ScreenshotError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _changesSubscription?.cancel();
    return super.close();
  }
}

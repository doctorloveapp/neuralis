/// Neuralis — Audio Engine / Presentation
/// AudioNotifier — Riverpod 3.x AsyncNotifier per il motore audio.
///
/// Posizione: lib/features/audio_engine/presentation/audio_notifier.dart
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../domain/entities/audio_entity.dart';
import '../domain/repositories/audio_capture_repository.dart';
import 'audio_state.dart';

/// AsyncNotifier che gestisce lo stato del motore audio.
///
/// Flusso dati (ARCHITECTURE.md §6):
///   Kotlin → EventChannel → [AudioCaptureRepository.fftStream]
///   → [AudioNotifier] → [AudioState.currentFFT]
///   → WavefrontPainter legge tramite ref.watch(audioNotifierProvider)
class AudioNotifier extends AsyncNotifier<AudioState> {
  StreamSubscription<dynamic>? _fftSub;
  StreamSubscription<dynamic>? _drmSub;

  AudioCaptureRepository get _repo =>
      ref.read(audioCaptureRepositoryProvider);

  @override
  Future<AudioState> build() async {
    ref.onDispose(_cancelSubscriptions);
    _setupStreams();
    return AudioState.initial();
  }

  // ─────────────────────────────────────────────────────────────────────
  // Stream subscriptions
  // ─────────────────────────────────────────────────────────────────────

  void _setupStreams() {
    _fftSub = _repo.fftStream.listen(
      (fftData) {
        final current = state.asData?.value;
        if (current != null) {
          state = AsyncData(current.copyWith(currentFFT: fftData));
        }
      },
      onError: (Object err) => state = AsyncError(err, StackTrace.current),
    );

    _drmSub = _repo.drmEventStream.listen(
      (event) {
        final current = state.asData?.value;
        if (current != null) {
          // Il layer nativo ha già commutato a EXTERNAL.
          // Sincronizziamo lo stato Dart.
          state = AsyncData(current.copyWith(
            isDrmBlocked: true,
            lastDrmEvent: event,
            mode: AudioCaptureMode.external,
          ));
        }
      },
      onError: (_) {}, // non critico
    );
  }

  void _cancelSubscriptions() {
    _fftSub?.cancel();
    _drmSub?.cancel();
    _fftSub = null;
    _drmSub = null;
  }

  // ─────────────────────────────────────────────────────────────────────
  // Comandi pubblici
  // ─────────────────────────────────────────────────────────────────────

  Future<void> startCapture(AudioCaptureMode mode) async {
    state = const AsyncLoading();
    try {
      await _repo.startCapture(mode);
      state = AsyncData(AudioState.initial().copyWith(
        mode: mode,
        isCapturing: true,
      ));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> stopCapture() async {
    await _repo.stopCapture();
    final current = state.asData?.value ?? AudioState.initial();
    state = AsyncData(current.copyWith(isCapturing: false));
  }

  Future<void> setMode(AudioCaptureMode mode) async {
    await _repo.setMode(mode);
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(current.copyWith(mode: mode, isDrmBlocked: false));
    }
  }

  /// Resetta il flag DRM (es. quando l'utente richiede manualmente
  /// il ritorno alla modalità INTERNAL dopo un failover).
  void clearDrmBlock() {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(current.copyWith(isDrmBlocked: false));
    }
  }
}

/// Neuralis — Audio Engine / Presentation
/// Stato immutabile dell'AudioNotifier.
///
/// Posizione: lib/features/audio_engine/presentation/audio_state.dart
library;

import '../domain/entities/audio_entity.dart';
import '../domain/entities/fft_data.dart';

/// Stato immutabile del motore audio, gestito da [AudioNotifier].
class AudioState {
  const AudioState({
    required this.mode,
    required this.currentFFT,
    required this.isCapturing,
    required this.isDrmBlocked,
    this.lastDrmEvent,
    this.errorMessage,
  });

  /// Modalità di cattura attiva.
  final AudioCaptureMode mode;

  /// Ultimo frame FFT ricevuto dal layer nativo (32 bande normalizzate).
  final FFTData currentFFT;

  /// True se la cattura è attiva e i dati FFT vengono ricevuti.
  final bool isCapturing;

  /// True se il motore Anti-DRM ha rilevato un blocco DRM.
  /// Quando true, la UI mostra [LcarsWarningBanner] con il messaggio i18n
  /// `drmWarningBanner` e la modalità è già commutata a [AudioCaptureMode.external].
  final bool isDrmBlocked;

  /// Ultimo evento DRM ricevuto (per diagnostica e timestamp).
  final DrmBlockedEvent? lastDrmEvent;

  /// Messaggio di errore dal layer nativo. Null se tutto OK.
  final String? errorMessage;

  /// Stato iniziale: nessuna cattura, FFT silenzioso, modalità internal.
  factory AudioState.initial() => AudioState(
        mode: AudioCaptureMode.internal,
        currentFFT: FFTData.silence(),
        isCapturing: false,
        isDrmBlocked: false,
      );

  AudioState copyWith({
    AudioCaptureMode? mode,
    FFTData? currentFFT,
    bool? isCapturing,
    bool? isDrmBlocked,
    DrmBlockedEvent? lastDrmEvent,
    String? errorMessage,
  }) =>
      AudioState(
        mode: mode ?? this.mode,
        currentFFT: currentFFT ?? this.currentFFT,
        isCapturing: isCapturing ?? this.isCapturing,
        isDrmBlocked: isDrmBlocked ?? this.isDrmBlocked,
        lastDrmEvent: lastDrmEvent ?? this.lastDrmEvent,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioState &&
          mode == other.mode &&
          isCapturing == other.isCapturing &&
          isDrmBlocked == other.isDrmBlocked &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      Object.hash(mode, isCapturing, isDrmBlocked, errorMessage);

  @override
  String toString() =>
      'AudioState(mode: $mode, capturing: $isCapturing, drm: $isDrmBlocked)';
}

/// Neuralis — Audio Engine / Data / Repositories
/// Implementazione concreta di AudioCaptureRepository.
///
/// Posizione: lib/features/audio_engine/data/repositories/audio_capture_repository_impl.dart
library;

import 'package:flutter/services.dart';

import '../../domain/entities/audio_entity.dart';
import '../../domain/entities/fft_data.dart';
import '../../domain/repositories/audio_capture_repository.dart';

/// Implementazione concreta di [AudioCaptureRepository].
///
/// Incapsula tutta la comunicazione con il layer nativo Kotlin:
///   - [MethodChannel('neuralis/audio')] → comandi (start, stop, setMode)
///   - [EventChannel('neuralis/audio_stream')] → stream FFT + eventi DRM
///
/// Il layer Domain non sa che esistono MethodChannel/EventChannel.
class AudioCaptureRepositoryImpl implements AudioCaptureRepository {
  AudioCaptureRepositoryImpl();

  static const _methodChannel = MethodChannel('neuralis/audio');
  static const _eventChannel  = EventChannel('neuralis/audio_stream');

  /// Stream broadcast grezzo dall'EventChannel.
  /// Un unico stream condiviso tra [fftStream] e [drmEventStream].
  late final Stream<dynamic> _rawStream =
      _eventChannel.receiveBroadcastStream();

  // ─────────────────────────────────────────────────────────────────────
  // AudioCaptureRepository — comandi
  // ─────────────────────────────────────────────────────────────────────

  @override
  Future<void> startCapture(AudioCaptureMode mode) async {
    await _methodChannel.invokeMethod<void>('start', {'mode': mode.name});
  }

  @override
  Future<void> stopCapture() async {
    await _methodChannel.invokeMethod<void>('stop');
  }

  @override
  Future<void> setMode(AudioCaptureMode mode) async {
    await _methodChannel.invokeMethod<void>('setMode', {'mode': mode.name});
  }

  // ─────────────────────────────────────────────────────────────────────
  // AudioCaptureRepository — stream
  // ─────────────────────────────────────────────────────────────────────

  /// Stream di frame FFT (FloatArray(32) da Kotlin → FFTData in Dart).
  @override
  Stream<FFTData> get fftStream => _rawStream
      .where((data) => data is List)
      .map((data) => FFTData.fromNative(data as List<dynamic>));

  /// Stream degli eventi DRM_BLOCKED emessi dal motore Anti-DRM.
  ///
  /// Quando ricevuto, [AudioNotifier] forza la modalità EXTERNAL e
  /// aggiorna lo stato per mostrare [LcarsWarningBanner].
  @override
  Stream<DrmBlockedEvent> get drmEventStream => _rawStream
      .where((data) =>
          data is Map && data['event'] == 'DRM_BLOCKED')
      .map((data) => DrmBlockedEvent.fromNative(
            data as Map<dynamic, dynamic>,
          ));
}

/// Neuralis — Audio Engine / Domain / Entities
/// Dati FFT e evento DRM per il layer Domain.
///
/// Posizione: lib/features/audio_engine/domain/entities/fft_data.dart
library;

// ---------------------------------------------------------------------------
// FFTData — dati FFT elaborati dal layer nativo
// ---------------------------------------------------------------------------

/// Rappresenta un frame di dati FFT elaborato dal motore nativo Kotlin.
///
/// Il layer nativo (NativeAudioCapture.kt) esegue la pipeline completa:
///   1. Hanning Window sul buffer grezzo (1024 campioni)
///   2. FFT
///   3. Raggruppamento in 32 bande logaritmiche
///   4. Normalizzazione in [0.0, 1.0] rispetto al picco storico
///
/// Questi 32 valori vengono poi inviati come uniform `uAudioFrequency[32]`
/// al fragment shader GLSL tramite [WavefrontUniforms].
class FFTData {
  const FFTData({required this.bands});

  /// 32 bande di frequenza normalizzate nell'intervallo [0.0, 1.0].
  ///
  /// Indici per zone di frequenza:
  ///   - [0..7]   → frequenze basse (bass) — displace righe centrali shader
  ///   - [8..15]  → medio-basse — displace zona intermedia shader
  ///   - [16..23] → medio-alte — displace zona esterna shader
  ///   - [24..31] → alte (treble) — displace bordi estremi shader
  final List<double> bands;

  /// Numero di bande — sempre 32 per contratto con il layer nativo.
  static const int bandCount = 32;

  /// Crea un [FFTData] silenzioso (tutte le bande a 0.0).
  /// Usato come valore iniziale prima dell'avvio della cattura.
  factory FFTData.silence() =>
      FFTData(bands: List.filled(bandCount, 0.0, growable: false));

  /// Crea un [FFTData] dal payload grezzo ricevuto via EventChannel.
  ///
  /// Il payload è un `List<dynamic>` Kotlin → Dart, cast a `List<double>`.
  /// Valida che la lunghezza sia esattamente [bandCount].
  factory FFTData.fromNative(List<dynamic> raw) {
    assert(
      raw.length == bandCount,
      'FFTData.fromNative: attesi $bandCount elementi, ricevuti ${raw.length}',
    );
    return FFTData(
      bands: raw.map((e) => (e as num).toDouble().clamp(0.0, 1.0)).toList(
            growable: false,
          ),
    );
  }

  /// Valore medio dell'energia su tutte le 32 bande.
  double get averageEnergy {
    if (bands.isEmpty) return 0.0;
    return bands.reduce((a, b) => a + b) / bands.length;
  }

  /// Energia media delle bande basse (0–7) — usata dal [BassPad].
  double get bassEnergy {
    if (bands.length < 8) return 0.0;
    return bands.sublist(0, 8).reduce((a, b) => a + b) / 8;
  }

  /// Valore di picco su tutte le bande.
  double get peakEnergy => bands.isEmpty ? 0.0 : bands.reduce((a, b) => a > b ? a : b);

  @override
  String toString() =>
      'FFTData(avg: ${averageEnergy.toStringAsFixed(3)}, peak: ${peakEnergy.toStringAsFixed(3)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FFTData &&
          runtimeType == other.runtimeType &&
          _listsEqual(bands, other.bands);

  @override
  int get hashCode => Object.hashAll(bands);

  static bool _listsEqual(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------------------
// DrmBlockedEvent — evento emesso dal motore Anti-DRM
// ---------------------------------------------------------------------------

/// Evento emesso via EventChannel quando il motore Anti-DRM rileva
/// che l'audio interno è stato bloccato dalla protezione DRM.
///
/// Il monitoraggio RMS in Kotlin rileva quando:
///   `rms_media < SOGLIA_SILENZIO (0.001) per più di 3 secondi`
///
/// A questo punto:
///   1. La modalità viene commutata automaticamente a [AudioCaptureMode.external]
///   2. Viene emesso questo evento
///   3. Il [AudioNotifier] espone l'evento allo state
///   4. L'UI mostra [LcarsWarningBanner] con il messaggio DRM
///
/// ⚠️ NOTA: il silenzio DRM non è mai matematicamente zero —
/// è rumore sotto soglia. Usare rms_media < SOGLIA, non rms == 0.
class DrmBlockedEvent {
  const DrmBlockedEvent({
    required this.timestamp,
    this.rmsAtTrigger,
  });

  /// Timestamp del momento in cui il failover è stato attivato.
  final DateTime timestamp;

  /// Valore RMS medio che ha triggerato il failover (opzionale, per diagnostica).
  final double? rmsAtTrigger;

  /// Crea un [DrmBlockedEvent] dal payload ricevuto via EventChannel.
  ///
  /// Payload atteso: `{"event": "DRM_BLOCKED", "rms": <double?>}`
  factory DrmBlockedEvent.fromNative(Map<dynamic, dynamic> payload) {
    return DrmBlockedEvent(
      timestamp: DateTime.now(),
      rmsAtTrigger: payload['rms'] != null
          ? (payload['rms'] as num).toDouble()
          : null,
    );
  }

  @override
  String toString() =>
      'DrmBlockedEvent(at: $timestamp, rms: $rmsAtTrigger)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrmBlockedEvent &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp;

  @override
  int get hashCode => timestamp.hashCode;
}

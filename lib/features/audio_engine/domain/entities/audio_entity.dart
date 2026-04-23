/// Neuralis — Audio Engine / Domain / Entities
/// Entità di dominio per la cattura audio.
///
/// Posizione: lib/features/audio_engine/domain/entities/audio_entity.dart
library;

// ---------------------------------------------------------------------------
// AudioCaptureMode — modalità di cattura audio
// ---------------------------------------------------------------------------

/// Modalità di cattura audio supportate dal motore nativo.
///
/// Corrisponde ai valori stringa passati via MethodChannel('neuralis/audio')
/// nel parametro `mode` del metodo `start` e `setMode`.
enum AudioCaptureMode {
  /// Cattura l'audio di sistema tramite AudioPlaybackCapture + MediaProjection.
  /// Richiede il permesso MediaProjection.
  /// Soggetta a blocco DRM — il motore Anti-DRM monitora l'RMS e
  /// attiva il fallback automatico verso [external] se necessario.
  internal,

  /// Cattura l'audio ambientale tramite microfono (AudioRecord + MIC).
  /// Richiede il permesso RECORD_AUDIO.
  /// Attivata automaticamente come fallback DRM o manualmente dall'utente.
  external,

  /// Cattura simultanea di [internal] e [external].
  /// I due segnali vengono sommati con peso configurabile lato nativo.
  /// Soggetta a monitoraggio DRM come [internal].
  hybrid,
}

// ---------------------------------------------------------------------------
// AudioEntity — entità di dominio che rappresenta lo stato del motore audio
// ---------------------------------------------------------------------------

/// Entità che rappresenta lo stato corrente del motore di cattura audio.
///
/// Immutabile. Creata e aggiornata dal layer Presentation tramite
/// [AudioNotifier]. Il layer Domain non sa come viene popolata —
/// conosce solo questa struttura.
class AudioEntity {
  const AudioEntity({
    required this.mode,
    required this.isCapturing,
    required this.isMuted,
    this.errorMessage,
  });

  /// Modalità di cattura attiva al momento.
  final AudioCaptureMode mode;

  /// True se la cattura audio è attiva e il buffer viene elaborato.
  final bool isCapturing;

  /// True se il motore è in modalità silenziosa (nessun dato inviato allo shader).
  final bool isMuted;

  /// Messaggio di errore opzionale dal layer nativo (es. permesso revocato).
  /// Null se non ci sono errori attivi.
  final String? errorMessage;

  /// Restituisce true se lo stato è operativo e senza errori.
  bool get isHealthy => isCapturing && !isMuted && errorMessage == null;

  /// Stato iniziale: nessuna cattura attiva, modalità internal come default.
  factory AudioEntity.initial() => const AudioEntity(
        mode: AudioCaptureMode.internal,
        isCapturing: false,
        isMuted: false,
      );

  /// Crea una copia con i valori specificati sostituiti.
  AudioEntity copyWith({
    AudioCaptureMode? mode,
    bool? isCapturing,
    bool? isMuted,
    String? errorMessage,
  }) {
    return AudioEntity(
      mode: mode ?? this.mode,
      isCapturing: isCapturing ?? this.isCapturing,
      isMuted: isMuted ?? this.isMuted,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() =>
      'AudioEntity(mode: $mode, isCapturing: $isCapturing, isMuted: $isMuted, error: $errorMessage)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioEntity &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          isCapturing == other.isCapturing &&
          isMuted == other.isMuted &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(mode, isCapturing, isMuted, errorMessage);
}

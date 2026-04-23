/// Neuralis — Audio Engine / Domain / Repositories
/// Contratto astratto per la cattura audio nativa.
///
/// Posizione: lib/features/audio_engine/domain/repositories/audio_capture_repository.dart
library;

import '../entities/audio_entity.dart';
import '../entities/fft_data.dart';

// ---------------------------------------------------------------------------
// AudioCaptureRepository — contratto astratto (Domain Layer)
// ---------------------------------------------------------------------------

/// Contratto astratto per la comunicazione con il motore di cattura audio nativo.
///
/// Il layer Domain conosce solo questa interfaccia.
/// L'implementazione concreta (NativeAudioCaptureService) nel layer Data
/// incapsula tutta la comunicazione MethodChannel/EventChannel.
///
/// Channel contracts (definiti in ARCHITECTURE.md §7):
///   - MethodChannel('neuralis/audio') → comandi discreti (start, stop, setMode)
///   - EventChannel('neuralis/audio_stream') → stream continuo FFT + eventi DRM
abstract class AudioCaptureRepository {
  /// Avvia la cattura audio nella modalità specificata.
  ///
  /// Se la cattura è già attiva, commuta alla nuova modalità atomicamente.
  /// [mode] determina la sorgente audio (Internal, External, Hybrid).
  ///
  /// Lancia un'eccezione se i permessi necessari non sono stati concessi.
  Future<void> startCapture(AudioCaptureMode mode);

  /// Ferma la cattura audio e libera le risorse AudioRecord native.
  ///
  /// Dopo questa chiamata, [fftStream] non emetterà più dati
  /// finché [startCapture] non viene chiamato di nuovo.
  Future<void> stopCapture();

  /// Cambia la modalità di cattura al volo senza interruzione del flusso.
  ///
  /// Equivale a chiamare stop → start con la nuova modalità, ma eseguito
  /// atomicamente lato nativo per evitare gap nel flusso FFT.
  Future<void> setMode(AudioCaptureMode mode);

  /// Stream continuo dei dati FFT elaborati dal motore nativo.
  ///
  /// Emette un [FFTData] per ogni buffer audio elaborato.
  /// Frequenza di emissione: dipendente dal buffer size nativo (~60 fps target).
  ///
  /// Il stream è broadcast: più listener possono sottoscriversi.
  /// Deve essere cancellato nel dispose del [AudioNotifier].
  Stream<FFTData> get fftStream;

  /// Stream degli eventi di blocco DRM.
  ///
  /// Emette un [DrmBlockedEvent] quando il motore Anti-DRM rileva
  /// silenzio sotto soglia per più di 3 secondi in modalità Internal/Hybrid.
  /// L'implementazione concreta ha già eseguito il failover a External
  /// prima di emettere questo evento.
  ///
  /// Il stream è broadcast. Ascoltato da [AudioNotifier] per aggiornare
  /// [AudioEntity] e triggerare il [LcarsWarningBanner].
  Stream<DrmBlockedEvent> get drmEventStream;
}

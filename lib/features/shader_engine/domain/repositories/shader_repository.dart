/// Neuralis — Shader Engine / Domain / Repositories
/// Contratto astratto per il caricamento e controllo dello shader GLSL.
///
/// Posizione: lib/features/shader_engine/domain/repositories/shader_repository.dart
library;

import '../entities/shader_params.dart';
import '../entities/wavefront_uniforms.dart';

// ---------------------------------------------------------------------------
// ShaderRepository — contratto astratto (Domain Layer) — ZERO dart:ui
// ---------------------------------------------------------------------------

/// Contratto astratto per la gestione del ciclo di vita del fragment shader.
///
/// ⚠️ CLEAN ARCHITECTURE RIGOROSA: questa interfaccia non importa `dart:ui`.
/// L'oggetto `FragmentShader` (dart:ui) è incapsulato esclusivamente
/// nell'implementazione concreta nel layer Data (ShaderRepositoryImpl).
/// Il Domain conosce solo operazioni di alto livello.
///
/// Flusso di utilizzo obbligatorio (ARCHITECTURE.md §4):
///   1. Chiama [loadShader()] durante lo splash screen (WARM-UP CRITICO)
///   2. Verifica [isLoaded] prima di navigare all'overlay
///   3. Chiama [updateUniforms()] ad ogni frame dal WavefrontPainter
///   4. Chiama [dispose()] nella dispose chain dell'AppLifecycleObserver
///
/// ⚠️ MAI chiamare [loadShader()] on-demand o al primo frame di rendering.
/// Causa jank visibile all'utente.
abstract class ShaderRepository {
  /// Esegue il warm-up dello shader GLSL.
  ///
  /// Carica il file `assets/shaders/wavefront.frag` e compila il programma.
  /// Da chiamare durante lo splash screen, prima di navigare all'overlay.
  ///
  /// [params] → parametri di configurazione strutturali della griglia GLSL.
  /// Se null, usa [ShaderParams.defaults()].
  ///
  /// Lancia un'eccezione se l'asset non è trovato o la compilazione fallisce.
  Future<void> loadShader({ShaderParams? params});

  /// True se [loadShader()] è stato completato con successo.
  ///
  /// Il layer Presentation deve verificare questo flag prima di
  /// tentare qualsiasi operazione di rendering.
  bool get isLoaded;

  /// Aggiorna gli uniforms GLSL con i valori del frame corrente.
  ///
  /// Chiamato ad ogni tick di rendering dal WavefrontPainter.
  /// L'implementazione concreta traduce [WavefrontUniforms] in
  /// chiamate `FragmentShader.setFloat(index, value)` secondo
  /// l'ordine degli indici definito in ARCHITECTURE.md §6:
  ///
  ///   Index 0      → uTime
  ///   Index 1–2    → uResolution (x, y)
  ///   Index 3–34   → uAudioFrequency[0..31]
  ///   Index 35–36  → uBending (x, y)
  ///
  /// Non-throwing: errori di rendering non devono crashare l'app.
  void updateUniforms(WavefrontUniforms uniforms);

  /// Rilascia le risorse GPU occupate dal FragmentShader.
  ///
  /// ⚠️ Ordine dispose obbligatorio (ARCHITECTURE.md §6):
  /// Questo metodo è il SECONDO nella chain, dopo interactionController.dispose()
  /// e prima di audioCaptureService.stop().
  void dispose();
}

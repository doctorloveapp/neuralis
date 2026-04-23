/// Neuralis — Shader Engine / Domain / Entities
/// Uniforms dinamici del fragment shader GLSL, aggiornati ogni frame.
///
/// Posizione: lib/features/shader_engine/domain/entities/wavefront_uniforms.dart
library;

import 'dart:ui' show Offset;

import '../../../audio_engine/domain/entities/fft_data.dart';

// ---------------------------------------------------------------------------
// WavefrontUniforms — uniforms GLSL aggiornati ogni frame
// ---------------------------------------------------------------------------

/// Raccolta di tutti gli uniforms passati al fragment shader `wavefront.frag`
/// ad ogni frame di rendering.
///
/// Corrisponde 1:1 agli uniforms definiti nello shader GLSL:
///   - `uniform float uTime`                → [time]
///   - `uniform vec2  uResolution`          → [resolution]
///   - `uniform float uAudioFrequency[32]`  → [audioFrequency] (da [FFTData])
///   - `uniform vec2  uBending`             → [bending]
///
/// Ordine di scrittura in WavefrontPainter.paint() (ARCHITECTURE.md §6):
///   Index 0      → uTime
///   Index 1–2    → uResolution (x, y)
///   Index 3–34   → uAudioFrequency[0..31]
///   Index 35–36  → uBending (x, y)
///
/// NOTA: [dart:ui.Offset] è l'unica dipendenza dart:ui ammessa qui
/// poiché rappresenta un concetto matematico puro (coppia di double),
/// non un'entità di rendering. Il [FragmentShader] rimane incapsulato
/// esclusivamente nel layer Data.
class WavefrontUniforms {
  const WavefrontUniforms({
    required this.time,
    required this.resolution,
    required this.audioFrequency,
    required this.bending,
  });

  /// Secondi trascorsi dall'avvio dell'app (uTime).
  /// Usato dallo shader per la rotazione animata della griglia 3D.
  final double time;

  /// Dimensioni del canvas in pixel (uResolution).
  /// Aggiornato quando il canvas viene ridimensionato.
  final Offset resolution;

  /// 32 bande FFT normalizzate [0.0, 1.0] (uAudioFrequency[32]).
  /// Derivate da [FFTData.bands], con bassGain applicato alle bande 0–7.
  ///
  /// Deve avere esattamente [FFTData.bandCount] = 32 elementi.
  final List<double> audioFrequency;

  /// Vettore di bending dal NavPad (uBending).
  /// Entrambi gli assi in [-1.0, 1.0].
  /// Attiva l'aberrazione cromatica quando length > ShaderParams.bendingThreshold.
  final Offset bending;

  /// Uniforms di silenzio — usati come valore iniziale prima della cattura audio.
  factory WavefrontUniforms.initial() => WavefrontUniforms(
        time: 0.0,
        resolution: const Offset(1080, 1920), // placeholder — aggiornato al primo frame
        audioFrequency: List.filled(FFTData.bandCount, 0.0, growable: false),
        bending: Offset.zero,
      );

  /// Crea gli uniforms applicando il [bassGain] alle bande basse (0–7).
  ///
  /// [fftData] → dati FFT grezzi dal repository audio.
  /// [bassGain] → moltiplicatore dal [BassPad], range [0.5, 3.0].
  /// Valori clampati a [0.0, 1.0] dopo l'applicazione del gain.
  factory WavefrontUniforms.fromFFT({
    required double time,
    required Offset resolution,
    required FFTData fftData,
    required Offset bending,
    double bassGain = 1.0,
  }) {
    final bands = List<double>.from(fftData.bands);
    // Applica bassGain alle bande 0–7 (frequenze basse) e clampa in [0.0, 1.0]
    for (int i = 0; i < 8 && i < bands.length; i++) {
      bands[i] = (bands[i] * bassGain).clamp(0.0, 1.0);
    }
    return WavefrontUniforms(
      time: time,
      resolution: resolution,
      audioFrequency: bands,
      bending: bending,
    );
  }

  /// Crea una copia con i valori specificati sostituiti.
  WavefrontUniforms copyWith({
    double? time,
    Offset? resolution,
    List<double>? audioFrequency,
    Offset? bending,
  }) {
    return WavefrontUniforms(
      time: time ?? this.time,
      resolution: resolution ?? this.resolution,
      audioFrequency: audioFrequency ?? this.audioFrequency,
      bending: bending ?? this.bending,
    );
  }

  @override
  String toString() =>
      'WavefrontUniforms(t: ${time.toStringAsFixed(2)}s, '
      'res: ${resolution.dx.toInt()}x${resolution.dy.toInt()}, '
      'bend: (${bending.dx.toStringAsFixed(2)}, ${bending.dy.toStringAsFixed(2)}))';
}

/// Neuralis — Shader Engine / Domain / Entities
/// Uniforms dinamici del fragment shader GLSL, aggiornati ogni frame.
///
/// Posizione: lib/features/shader_engine/domain/entities/wavefront_uniforms.dart
library;

import 'dart:ui' show Color, Offset;

import '../../../audio_engine/domain/entities/fft_data.dart';
import '../../../preset/domain/entities/neuralis_preset.dart';

// ---------------------------------------------------------------------------
// WavefrontUniforms — uniforms GLSL aggiornati ogni frame
// ---------------------------------------------------------------------------

/// Raccolta di tutti gli uniforms passati al fragment shader `wavefront.frag`.
///
/// Layout indici (ARCHITECTURE.md §6):
///   Index 0      → uTime
///   Index 1–2    → uResolution (x, y)
///   Index 3–34   → uAudioBand0..7 (8×vec4 = 32 float)
///   Index 35–36  → uBending (x, y)
///   Index 37–39  → uColorBase (r, g, b)
///   Index 40–42  → uColorMid  (r, g, b)
///   Index 43–45  → uColorPeak (r, g, b)
///   Index 46     → uFov
///   Index 47     → uMeshW
///   Index 48     → uLineWeight
///   Index 49     → uWaveSpeed
///   Index 50     → uCamDist
class WavefrontUniforms {
  const WavefrontUniforms({
    required this.time,
    required this.resolution,
    required this.audioFrequency,
    required this.bending,
    required this.colorBase,
    required this.colorMid,
    required this.colorPeak,
    required this.fov,
    required this.meshW,
    required this.lineWeight,
    required this.waveSpeed,
    required this.camDist,
  });

  final double       time;
  final Offset       resolution;
  final List<double> audioFrequency;  // 32 bande FFT normalizzate
  final Offset       bending;

  // ── Parametri preset ──────────────────────────────────────────────────────
  final Color  colorBase;
  final Color  colorMid;
  final Color  colorPeak;
  final double fov;
  final double meshW;
  final double lineWeight;
  final double waveSpeed;
  final double camDist;   // distanza camera — index 50

  /// Uniforms iniziali con preset SYNTHWAVE di default.
  factory WavefrontUniforms.initial() {
    final def = PresetLibrary.of(NeuralisPreset.synthwave);
    return WavefrontUniforms(
      time:           0.0,
      resolution:     const Offset(1080, 1920),
      audioFrequency: List.filled(FFTData.bandCount, 0.0, growable: false),
      bending:        Offset.zero,
      colorBase:      def.colorBase,
      colorMid:       def.colorMid,
      colorPeak:      def.colorPeak,
      fov:            def.fov,
      meshW:          def.meshW,
      lineWeight:     def.lineWeight,
      waveSpeed:      def.waveSpeed,
      camDist:        def.camDist,
    );
  }

  WavefrontUniforms copyWith({
    double?       time,
    Offset?       resolution,
    List<double>? audioFrequency,
    Offset?       bending,
    Color?        colorBase,
    Color?        colorMid,
    Color?        colorPeak,
    double?       fov,
    double?       meshW,
    double?       lineWeight,
    double?       waveSpeed,
    double?       camDist,
  }) =>
      WavefrontUniforms(
        time:           time           ?? this.time,
        resolution:     resolution     ?? this.resolution,
        audioFrequency: audioFrequency ?? this.audioFrequency,
        bending:        bending        ?? this.bending,
        colorBase:      colorBase      ?? this.colorBase,
        colorMid:       colorMid       ?? this.colorMid,
        colorPeak:      colorPeak      ?? this.colorPeak,
        fov:            fov            ?? this.fov,
        meshW:          meshW          ?? this.meshW,
        lineWeight:     lineWeight     ?? this.lineWeight,
        waveSpeed:      waveSpeed      ?? this.waveSpeed,
        camDist:        camDist        ?? this.camDist,
      );

  /// Copia con i parametri di un [PresetData].
  WavefrontUniforms withPreset(PresetData preset) => copyWith(
        colorBase:  preset.colorBase,
        colorMid:   preset.colorMid,
        colorPeak:  preset.colorPeak,
        fov:        preset.fov,
        meshW:      preset.meshW,
        lineWeight: preset.lineWeight,
        waveSpeed:  preset.waveSpeed,
        camDist:    preset.camDist,
      );

  @override
  String toString() =>
      'WavefrontUniforms(t: ${time.toStringAsFixed(2)}s, '
      'bend: (${bending.dx.toStringAsFixed(2)}, ${bending.dy.toStringAsFixed(2)}))';
}

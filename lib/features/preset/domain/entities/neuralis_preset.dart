/// Neuralis — Preset / Domain / Entities
/// NeuralisPreset: enum + PresetData + PresetLibrary (specifiche da preset.md v2)
///
/// Posizione: lib/features/preset/domain/entities/neuralis_preset.dart
library;

import 'dart:ui' show Color;

// ─────────────────────────────────────────────────────────────────────────────
enum NeuralisPreset {
  synthwave,   // SYNTHWAVE OVERDRIVE
  quantum,     // QUANTUM ANOMALY
  cyber,       // CYBER-NEURO
  nebula,      // NEBULA CORE
  hyperspace,  // HYPERSPACE JUMP
}

// ─────────────────────────────────────────────────────────────────────────────
class PresetData {
  const PresetData({
    required this.preset,
    required this.name,
    required this.shortName,
    required this.colorBase,
    required this.colorMid,
    required this.colorPeak,
    required this.fov,
    required this.meshW,
    required this.lineWeight,
    required this.waveSpeed,
    required this.camDist,
    required this.maxBassGain,
    required this.bassRiseSpeed,
    required this.bassDecaySpeed,
    required this.bendingDecaySpeed,
    required this.bassBands,
    required this.navSensitivity,
  });

  final NeuralisPreset preset;
  final String         name;
  final String         shortName;

  // ── Colori shader ─────────────────────────────────────────────────────────
  final Color  colorBase;
  final Color  colorMid;
  final Color  colorPeak;

  // ── Geometria shader ──────────────────────────────────────────────────────
  final double fov;
  final double meshW;
  final double lineWeight;
  final double waveSpeed;
  final double camDist;      // distanza camera (SICUREZZA: > MESH_D + 0.3)

  // ── Fisica pad ────────────────────────────────────────────────────────────
  final double maxBassGain;
  final double bassRiseSpeed;
  final double bassDecaySpeed;
  final double bendingDecaySpeed;
  final int    bassBands;       // quante bande FFT amplificate (1..32)
  final double navSensitivity;  // moltiplicatore swipe NavPad (1.0..10.0)

  static List<double> colorToVec3(Color c) => [c.r, c.g, c.b];
}

// ─────────────────────────────────────────────────────────────────────────────
class PresetLibrary {
  PresetLibrary._();

  // ── 1. SYNTHWAVE OVERDRIVE ─────────────────────────────────────────────────
  // Retrofuturismo psichedelico: Hot Pink/Cyan, FOV distorto, neon vibe.
  static const _synthwave = PresetData(
    preset:      NeuralisPreset.synthwave,
    name:        'SYNTHWAVE OVERDRIVE',
    shortName:   'SYNTH',
    colorBase:   Color(0xFF1A0026), // vec3(0.10, 0.00, 0.15) viola nerastro
    colorMid:    Color(0xFFFF0D99), // vec3(1.00, 0.05, 0.60) hot pink/magenta
    colorPeak:   Color(0xFF00E6FF), // vec3(0.00, 0.90, 1.00) neon cyan
    fov:         1.10,
    meshW:       1.10,   // mesh vastissima, sborda in orizzontale
    lineWeight:  0.006,
    waveSpeed:   1.2,
    camDist:     2.5,
    maxBassGain: 10.0,
    bassRiseSpeed:      7.0,
    bassDecaySpeed:     8.0,   // rilascio secco e ritmato
    bendingDecaySpeed:  3.5,
    bassBands:   8,
    navSensitivity: 5.4,
  );

  // ── 2. QUANTUM ANOMALY ─────────────────────────────────────────────────────
  // Psichedelia liquida organica: Verde/Lime, movimenti fluidi, bass swell.
  static const _quantum = PresetData(
    preset:      NeuralisPreset.quantum,
    name:        'QUANTUM ANOMALY',
    shortName:   'QUANTUM',
    colorBase:   Color(0xFF00261A), // vec3(0.00, 0.15, 0.10) verde palude
    colorMid:    Color(0xFF00FF80), // vec3(0.00, 1.00, 0.50) spring green
    colorPeak:   Color(0xFFF2FFCC), // vec3(0.95, 1.00, 0.80) bianco perlaceo
    fov:         0.85,
    meshW:       0.70,
    lineWeight:  0.004,
    waveSpeed:   0.40,   // ondeggiamento lento liquido
    camDist:     2.8,
    maxBassGain: 6.0,
    bassRiseSpeed:      3.0,
    bassDecaySpeed:     1.5,   // swell lentissimo
    bendingDecaySpeed:  1.5,
    bassBands:   8,
    navSensitivity: 4.0,
  );

  // ── 3. CYBER-NEURO ─────────────────────────────────────────────────────────
  // Matrix hacker: verde fosforo, wireframe sottile, statico in idle, snap bass.
  static const _cyber = PresetData(
    preset:      NeuralisPreset.cyber,
    name:        'CYBER-NEURO',
    shortName:   'CYBER',
    colorBase:   Color(0xFF050505), // vec3(0.02, 0.02, 0.02) nero quasi totale
    colorMid:    Color(0xFF1A8026), // vec3(0.10, 0.50, 0.15) verde monitor
    colorPeak:   Color(0xFF66FF33), // vec3(0.40, 1.00, 0.20) verde fosforo
    fov:         0.45,   // quasi ortografico
    meshW:       0.50,
    lineWeight:  0.002,
    waveSpeed:   0.0,    // STATICO in idle (0.0 = sin(0 + z) = costante)
    camDist:     2.5,
    maxBassGain: 4.0,
    bassRiseSpeed:      12.0,  // snap istantaneo
    bassDecaySpeed:     9.0,
    bendingDecaySpeed:  6.0,
    bassBands:   4,      // isola solo kick drum puro
    navSensitivity: 5.4,
  );

  // ── 4. NEBULA CORE ─────────────────────────────────────────────────────────
  // Deep space float: Viola/Sole, camera lontana, colline morbide.
  static const _nebula = PresetData(
    preset:      NeuralisPreset.nebula,
    name:        'NEBULA CORE',
    shortName:   'NEBULA',
    colorBase:   Color(0xFF0D0D40), // vec3(0.05, 0.05, 0.25) blu cosmico
    colorMid:    Color(0xFF661ACC), // vec3(0.40, 0.10, 0.80) viola galattico
    colorPeak:   Color(0xFFFF804D), // vec3(1.00, 0.50, 0.30) arancio sole
    fov:         0.70,
    meshW:       0.85,
    lineWeight:  0.005,
    waveSpeed:   0.45,
    camDist:     3.5,   // camera lontanissima
    maxBassGain: 3.0,   // molto pacato
    bassRiseSpeed:      2.5,
    bassDecaySpeed:     1.5,
    bendingDecaySpeed:  1.8,
    bassBands:   8,
    navSensitivity: 2.0,  // swipe completo per notare l'effetto
  );

  // ── 5. HYPERSPACE JUMP ─────────────────────────────────────────────────────
  // Maximum impact & speed: Nero/AzzurroElettrico/Rosso, velocità estrema.
  static const _hyperspace = PresetData(
    preset:      NeuralisPreset.hyperspace,
    name:        'HYPERSPACE JUMP',
    shortName:   'HYPER',
    colorBase:   Color(0xFF000000), // nero assoluto
    colorMid:    Color(0xFF00CCFF), // vec3(0.00, 0.80, 1.00) azzurro elettrico
    colorPeak:   Color(0xFFFF0033), // vec3(1.00, 0.00, 0.20) rosso Red Alert
    fov:         0.90,
    meshW:       0.90,
    lineWeight:  0.006,
    waveSpeed:   2.8,   // iper-veloce
    camDist:     2.0,   // camera vicinissima — immersione totale
    maxBassGain: 12.0,
    bassRiseSpeed:      10.0,
    bassDecaySpeed:     6.0,
    bendingDecaySpeed:  8.0,   // ritorno istantaneo
    bassBands:   12,    // sub-bass + medi per lead synth
    navSensitivity: 6.0,
  );

  static const List<PresetData> all = [
    _synthwave, _quantum, _cyber, _nebula, _hyperspace,
  ];

  static PresetData of(NeuralisPreset p) =>
      all.firstWhere((d) => d.preset == p);
}

/// Neuralis — Shader Engine / Domain / Entities
/// Parametri di configurazione dello shader GLSL.
///
/// Posizione: lib/features/shader_engine/domain/entities/shader_params.dart
library;

// ---------------------------------------------------------------------------
// ShaderParams — parametri di configurazione del motore shader
// ---------------------------------------------------------------------------

/// Parametri di configurazione statici del motore Neural Wavefront.
///
/// Distingue dai parametri dinamici per frame ([WavefrontUniforms]):
/// questi sono impostati una volta e definiscono il comportamento
/// strutturale dello shader (dimensioni griglia, scale, soglie).
///
/// Passati all'implementazione concreta di [ShaderRepository]
/// al momento di [ShaderRepository.loadShader()].
class ShaderParams {
  const ShaderParams({
    this.gridSize = defaultGridSize,
    this.displacementScale = defaultDisplacementScale,
    this.rotationSpeed = defaultRotationSpeed,
    this.chromaStrengthMultiplier = defaultChromaStrengthMultiplier,
    this.bendingThreshold = defaultBendingThreshold,
  });

  /// Dimensione N della griglia wireframe 3D procedurale (NxN linee).
  /// Valore consigliato: 16 (trade-off qualità/performance su mobile).
  final int gridSize;

  /// Fattore di scala del displacement sull'asse Y della griglia.
  /// Moltiplica il valore FFT per determinare l'ampiezza della deformazione.
  final double displacementScale;

  /// Velocità di rotazione sull'asse Y in rad/s (effetto floating).
  /// Valore consigliato: 0.3 rad/s.
  final double rotationSpeed;

  /// Moltiplicatore per l'intensità dell'aberrazione cromatica.
  /// L'intensità effettiva = length(uBending) * chromaStrengthMultiplier.
  final double chromaStrengthMultiplier;

  /// Soglia di attivazione dell'aberrazione cromatica.
  /// Attiva quando length(uBending) > [bendingThreshold].
  /// Corrisponde alla costante 0.1 definita in ARCHITECTURE.md.
  final double bendingThreshold;

  // Valori di default coerenti con le specifiche GLSL in NEURALIS_MASTER_PROMPT_V1.2.md
  static const int defaultGridSize = 16;
  static const double defaultDisplacementScale = 0.3;
  static const double defaultRotationSpeed = 0.3;
  static const double defaultChromaStrengthMultiplier = 0.02;
  static const double defaultBendingThreshold = 0.1;

  /// Parametri di default — valori consigliati da ARCHITECTURE.md.
  factory ShaderParams.defaults() => const ShaderParams();

  /// Crea una copia con i valori specificati sostituiti.
  ShaderParams copyWith({
    int? gridSize,
    double? displacementScale,
    double? rotationSpeed,
    double? chromaStrengthMultiplier,
    double? bendingThreshold,
  }) {
    return ShaderParams(
      gridSize: gridSize ?? this.gridSize,
      displacementScale: displacementScale ?? this.displacementScale,
      rotationSpeed: rotationSpeed ?? this.rotationSpeed,
      chromaStrengthMultiplier:
          chromaStrengthMultiplier ?? this.chromaStrengthMultiplier,
      bendingThreshold: bendingThreshold ?? this.bendingThreshold,
    );
  }

  @override
  String toString() =>
      'ShaderParams(grid: $gridSize, displacement: $displacementScale, '
      'rotation: $rotationSpeed rad/s, chromaMul: $chromaStrengthMultiplier, '
      'bendingThreshold: $bendingThreshold)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShaderParams &&
          runtimeType == other.runtimeType &&
          gridSize == other.gridSize &&
          displacementScale == other.displacementScale &&
          rotationSpeed == other.rotationSpeed &&
          chromaStrengthMultiplier == other.chromaStrengthMultiplier &&
          bendingThreshold == other.bendingThreshold;

  @override
  int get hashCode => Object.hash(
        gridSize,
        displacementScale,
        rotationSpeed,
        chromaStrengthMultiplier,
        bendingThreshold,
      );
}

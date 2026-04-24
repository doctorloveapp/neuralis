/// Neuralis — Overlay UI / Presentation / States
/// Stato immutabile dell'overlay di sistema.
///
/// Posizione: lib/features/overlay_ui/presentation/states/overlay_state.dart
library;

/// Stato immutabile dell'overlay di sistema, gestito da [OverlayNotifier].
class OverlayState {
  const OverlayState({
    required this.isVisible,
    required this.opacity,
    required this.isLocked,
  });

  /// True se l'overlay è attualmente mostrato tramite WindowManager.
  final bool isVisible;

  /// Opacità corrente [0.0, 1.0].
  final double opacity;

  /// True → l'overlay non può essere riposizionato dall'utente.
  final bool isLocked;

  /// Stato iniziale: nascosto, opacità piena, bloccato.
  factory OverlayState.initial() => const OverlayState(
        isVisible: false,
        opacity:   1.0,
        isLocked:  true,
      );

  OverlayState copyWith({
    bool?   isVisible,
    double? opacity,
    bool?   isLocked,
  }) =>
      OverlayState(
        isVisible: isVisible ?? this.isVisible,
        opacity:   (opacity  ?? this.opacity).clamp(0.0, 1.0),
        isLocked:  isLocked  ?? this.isLocked,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OverlayState &&
          isVisible == other.isVisible &&
          opacity == other.opacity &&
          isLocked == other.isLocked;

  @override
  int get hashCode => Object.hash(isVisible, opacity, isLocked);
}

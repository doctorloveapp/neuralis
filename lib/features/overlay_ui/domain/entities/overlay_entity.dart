/// Neuralis — Overlay UI / Domain / Entities
/// Entità di dominio che rappresenta lo stato dell'overlay di sistema.
///
/// Posizione: lib/features/overlay_ui/domain/entities/overlay_entity.dart
library;

// ---------------------------------------------------------------------------
// OverlayEntity — stato dell'overlay di sistema
// ---------------------------------------------------------------------------

/// Entità che rappresenta lo stato corrente dell'overlay Neuralis.
///
/// Immutabile. Gestita dal [OverlayNotifier] nel layer Presentation.
/// Il layer nativo (OverlayManager.kt + WindowManager) riflette
/// sempre lo stato descritto da questa entità.
class OverlayEntity {
  const OverlayEntity({
    required this.isVisible,
    required this.opacity,
    required this.isLocked,
  });

  /// True se l'overlay è attualmente visibile sullo schermo.
  ///
  /// Quando false, la View è rimossa dal WindowManager ma il servizio
  /// NeuralisForegroundService rimane attivo in background.
  final bool isVisible;

  /// Opacità dell'overlay nell'intervallo [0.0, 1.0].
  ///
  /// - 0.0 → completamente trasparente (invisibile ma interagibile)
  /// - 1.0 → completamente opaco
  /// Default: 1.0 (piena visibilità)
  ///
  // TODO(future): esporre controllo opacità nel pannello impostazioni LCARS
  final double opacity;

  /// Se true, l'overlay è bloccato nella posizione corrente.
  ///
  /// Quando false, l'utente può trascinare il pannello tattico LCARS
  /// in una posizione diversa dello schermo (funzionalità futura).
  ///
  /// Default: true (posizione fissa — comportamento iniziale).
  // TODO(future): implementare drag-to-reposition quando isLocked == false
  final bool isLocked;

  /// Stato iniziale: overlay nascosto, opacità piena, posizione bloccata.
  factory OverlayEntity.initial() => const OverlayEntity(
        isVisible: false,
        opacity: 1.0,
        isLocked: true,
      );

  /// Crea una copia con i valori specificati sostituiti.
  OverlayEntity copyWith({
    bool? isVisible,
    double? opacity,
    bool? isLocked,
  }) {
    assert(
      opacity == null || (opacity >= 0.0 && opacity <= 1.0),
      'OverlayEntity.copyWith: opacity deve essere in [0.0, 1.0], ricevuto $opacity',
    );
    return OverlayEntity(
      isVisible: isVisible ?? this.isVisible,
      opacity: opacity ?? this.opacity,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  @override
  String toString() =>
      'OverlayEntity(isVisible: $isVisible, opacity: $opacity, isLocked: $isLocked)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OverlayEntity &&
          runtimeType == other.runtimeType &&
          isVisible == other.isVisible &&
          opacity == other.opacity &&
          isLocked == other.isLocked;

  @override
  int get hashCode => Object.hash(isVisible, opacity, isLocked);
}

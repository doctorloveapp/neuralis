/// Neuralis — Overlay UI / Domain / Repositories
/// Contratto astratto per la gestione dell'overlay di sistema.
///
/// Posizione: lib/features/overlay_ui/domain/repositories/overlay_repository.dart
library;

import '../entities/overlay_entity.dart';

// ---------------------------------------------------------------------------
// OverlayRepository — contratto astratto (Domain Layer)
// ---------------------------------------------------------------------------

/// Contratto astratto per il controllo dell'overlay di sistema Neuralis.
///
/// Il layer Domain conosce solo questa interfaccia.
/// L'implementazione concreta (NativeOverlayService) nel layer Data
/// incapsula la comunicazione tramite MethodChannel('neuralis/overlay')
/// con il layer nativo Kotlin (OverlayManager.kt + WindowManager).
///
/// Channel contract (ARCHITECTURE.md §7.3):
///   - MethodChannel('neuralis/overlay') → show, hide, isVisible
abstract class OverlayRepository {
  /// Rende visibile l'overlay di sistema sullo schermo.
  ///
  /// Lato nativo, aggiunge la View al WindowManager con i parametri
  /// SYSTEM_ALERT_WINDOW. Richiede che il permesso overlay sia granted.
  ///
  /// Lancia un'eccezione se il permesso SYSTEM_ALERT_WINDOW non è granted.
  Future<void> showOverlay();

  /// Nasconde l'overlay di sistema rimuovendo la View dal WindowManager.
  ///
  /// Il NeuralisForegroundService rimane attivo in background.
  /// La cattura audio continua (se avviata) per consentire
  /// il ripristino veloce dell'overlay.
  Future<void> hideOverlay();

  /// Restituisce true se l'overlay è attualmente visibile sullo schermo.
  Future<bool> isOverlayVisible();

  /// Aggiorna l'opacità dell'overlay al valore specificato.
  ///
  /// [opacity] deve essere nell'intervallo [0.0, 1.0].
  /// Corrisponde all'attributo `alpha` della View nel WindowManager.
  // TODO(future): esporre nel pannello impostazioni LCARS
  Future<void> setOpacity(double opacity);

  /// Aggiorna la stato di blocco/sblocco della posizione dell'overlay.
  ///
  /// Quando [locked] è false, l'utente può trascinare il pannello LCARS.
  // TODO(future): implementare drag-to-reposition con WindowManager.updateViewLayout
  Future<void> setLocked(bool locked);

  /// Restituisce lo stato completo corrente dell'overlay come [OverlayEntity].
  Future<OverlayEntity> getOverlayState();
}

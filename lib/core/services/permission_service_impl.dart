/// Neuralis — Core Services / Data Layer
/// Implementazione concreta di PermissionService.
///
/// Posizione: lib/core/services/permission_service_impl.dart
library;

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'permission_service.dart';

// ---------------------------------------------------------------------------
// PermissionServiceImpl — implementazione concreta (layer Data / Core)
// ---------------------------------------------------------------------------

/// Implementazione concreta di [PermissionService].
///
/// Strategia ibrida:
///   - **RECORD_AUDIO** → gestito da `permission_handler` (runtime permission standard)
///   - **SYSTEM_ALERT_WINDOW** → gestito via MethodChannel('neuralis/permissions')
///     perché non è un runtime permission: richiede ACTION_MANAGE_OVERLAY_PERMISSION
///     e non può essere concesso tramite `permission_handler`.
///   - **MEDIA_PROJECTION** → gestito via MethodChannel('neuralis/permissions')
///     perché richiede un Activity Result asincrono (flow 7 passi).
///   - **openAppSettings** → MethodChannel per i permessi permanentemente negati.
///
/// Iniettata tramite Riverpod nel layer Presentation.
/// Il Domain non conosce né `permission_handler` né MethodChannel.
class PermissionServiceImpl implements PermissionService {
  PermissionServiceImpl();

  static const _permissionsChannel =
      MethodChannel('neuralis/permissions');

  // ─────────────────────────────────────────────────────────────────────
  // PermissionService interface implementation
  // ─────────────────────────────────────────────────────────────────────

  /// Richiede il permesso SYSTEM_ALERT_WINDOW.
  ///
  /// Delega a Kotlin via MethodChannel('requestOverlay'):
  /// apre ACTION_MANAGE_OVERLAY_PERMISSION e poi controlla lo stato.
  /// Il risultato è una verifica post-navigazione (l'utente torna all'app).
  @override
  Future<PermissionStatus> requestOverlayPermission() async {
    try {
      // Apre la schermata di sistema per il permesso overlay.
      // Non è asincrono — l'utente naviga nelle impostazioni e torna.
      await _permissionsChannel.invokeMethod<void>('requestOverlay');
      // Controlla lo stato aggiornato dopo il ritorno dall'impostazione.
      return checkOverlayPermission();
    } on PlatformException {
      return PermissionStatus.denied;
    }
  }

  /// Richiede il permesso RECORD_AUDIO tramite `permission_handler`.
  @override
  Future<PermissionStatus> requestAudioPermission() async {
    final status = await ph.Permission.microphone.request();
    return _mapPhStatus(status);
  }

  /// Avvia il flow completo MediaProjection (passi 2–5 del flow in 7 passi).
  ///
  /// Delega a Kotlin via MethodChannel('requestMediaProjection').
  /// La chiamata è asincrona — si risolve quando l'utente risponde al dialogo.
  /// Kotlin risponde "granted" o "denied".
  ///
  /// I passi 6 e 7 (AudioRecord + INTERNAL_AUDIO_READY) avvengono nel
  /// NeuralisForegroundService e vengono notificati via EventChannel.
  @override
  Future<PermissionStatus> requestMediaProjection() async {
    try {
      final result = await _permissionsChannel
          .invokeMethod<String>('requestMediaProjection');
      return result == 'granted'
          ? PermissionStatus.granted
          : PermissionStatus.denied;
    } on PlatformException {
      return PermissionStatus.denied;
    }
  }

  /// Controlla lo stato aggregato di tutti i permessi Neuralis.
  @override
  Future<PermissionsState> checkAllPermissions() async {
    final overlay = await checkOverlayPermission();
    final audio = await _checkAudioPermission();
    // MediaProjection non ha uno stato persistente interrogabile —
    // viene concesso on-demand tramite dialogo. Usiamo `unknown` come
    // default finché non viene richiesto esplicitamente.
    const mediaProjection = PermissionStatus.unknown;

    return PermissionsState(
      overlay: overlay,
      audio: audio,
      mediaProjection: mediaProjection,
    );
  }

  /// Apre le impostazioni dell'app Android.
  /// Da invocare quando [PermissionsState.hasPermanentlyDenied] è true.
  @override
  Future<void> openAppSettings() async {
    try {
      await _permissionsChannel.invokeMethod<void>('openAppSettings');
    } on PlatformException catch (_) {
      // Fallback: usa permission_handler che ha il suo openAppSettings
      await ph.openAppSettings();
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Helpers privati
  // ─────────────────────────────────────────────────────────────────────

  /// Controlla lo stato del permesso SYSTEM_ALERT_WINDOW via MethodChannel.
  Future<PermissionStatus> checkOverlayPermission() async {
    try {
      final canDraw = await _permissionsChannel
          .invokeMethod<bool>('checkOverlay') ?? false;
      return canDraw ? PermissionStatus.granted : PermissionStatus.denied;
    } on PlatformException catch (_) {
      return PermissionStatus.unknown;
    }
  }

  /// Controlla lo stato del permesso RECORD_AUDIO tramite `permission_handler`.
  Future<PermissionStatus> _checkAudioPermission() async {
    final status = await ph.Permission.microphone.status;
    return _mapPhStatus(status);
  }

  /// Mappa [ph.PermissionStatus] → [PermissionStatus] di Neuralis.
  PermissionStatus _mapPhStatus(ph.PermissionStatus status) {
    return switch (status) {
      ph.PermissionStatus.granted         => PermissionStatus.granted,
      ph.PermissionStatus.denied          => PermissionStatus.denied,
      ph.PermissionStatus.permanentlyDenied ||
      ph.PermissionStatus.restricted      => PermissionStatus.permanentlyDenied,
      _                                   => PermissionStatus.unknown,
    };
  }
}

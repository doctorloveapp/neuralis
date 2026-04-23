/// Neuralis — Core Services
/// Gestione centralizzata dei permessi Android con stato granulare.
///
/// Posizione: lib/core/services/permission_service.dart
library;

// ---------------------------------------------------------------------------
// PermissionStatus — stato granulare di un singolo permesso
// ---------------------------------------------------------------------------

/// Stato granulare di un singolo permesso Android.
///
/// [permanentlyDenied] attiva il flusso LCARS
/// "SYSTEM CRITICAL — MANUAL INTERVENTION REQUIRED"
/// che guida l'utente nelle impostazioni di sistema.
enum PermissionStatus {
  /// Stato iniziale: il permesso non è mai stato richiesto.
  unknown,

  /// Il permesso è stato concesso dall'utente.
  granted,

  /// Il permesso è stato negato, ma può essere richiesto di nuovo.
  denied,

  /// Il permesso è stato negato permanentemente (opzione "Non chiedere più").
  /// Richiede navigazione manuale verso le impostazioni Android.
  permanentlyDenied,
}

// ---------------------------------------------------------------------------
// PermissionsState — stato aggregato di tutti i permessi di sistema
// ---------------------------------------------------------------------------

/// Stato aggregato di tutti i permessi richiesti da Neuralis.
///
/// Usato da [PermissionService.checkAllPermissions()] per esporre
/// un'istantanea coerente dell'intera situazione permessi.
class PermissionsState {
  const PermissionsState({
    required this.overlay,
    required this.audio,
    required this.mediaProjection,
  });

  /// Permesso SYSTEM_ALERT_WINDOW — richiesto per l'overlay di sistema.
  final PermissionStatus overlay;

  /// Permesso RECORD_AUDIO — richiesto per la cattura microfono (modalità External/Hybrid).
  final PermissionStatus audio;

  /// Permesso MediaProjection — richiesto per la cattura audio interna (modalità Internal/Hybrid).
  final PermissionStatus mediaProjection;

  /// Restituisce true se tutti i permessi critici sono [PermissionStatus.granted].
  bool get allGranted =>
      overlay == PermissionStatus.granted &&
      audio == PermissionStatus.granted &&
      mediaProjection == PermissionStatus.granted;

  /// Restituisce true se almeno un permesso è [PermissionStatus.permanentlyDenied].
  /// Attiva il flusso LCARS "SYSTEM CRITICAL — MANUAL INTERVENTION REQUIRED".
  bool get hasPermanentlyDenied =>
      overlay == PermissionStatus.permanentlyDenied ||
      audio == PermissionStatus.permanentlyDenied ||
      mediaProjection == PermissionStatus.permanentlyDenied;

  /// Crea una copia con i valori specificati sostituiti.
  PermissionsState copyWith({
    PermissionStatus? overlay,
    PermissionStatus? audio,
    PermissionStatus? mediaProjection,
  }) {
    return PermissionsState(
      overlay: overlay ?? this.overlay,
      audio: audio ?? this.audio,
      mediaProjection: mediaProjection ?? this.mediaProjection,
    );
  }

  /// Stato iniziale: tutti i permessi sono [PermissionStatus.unknown].
  factory PermissionsState.initial() => const PermissionsState(
        overlay: PermissionStatus.unknown,
        audio: PermissionStatus.unknown,
        mediaProjection: PermissionStatus.unknown,
      );

  @override
  String toString() =>
      'PermissionsState(overlay: $overlay, audio: $audio, mediaProjection: $mediaProjection)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionsState &&
          runtimeType == other.runtimeType &&
          overlay == other.overlay &&
          audio == other.audio &&
          mediaProjection == other.mediaProjection;

  @override
  int get hashCode => Object.hash(overlay, audio, mediaProjection);
}

// ---------------------------------------------------------------------------
// PermissionService — contratto astratto
// ---------------------------------------------------------------------------

/// Contratto astratto per la gestione dei permessi Android.
///
/// L'implementazione concreta è fornita dal layer Data e iniettata
/// tramite Riverpod. Il layer Domain non conosce i dettagli implementativi
/// di `permission_handler` o delle chiamate MethodChannel native.
///
/// Flusso di utilizzo consigliato:
/// 1. Chiama [checkAllPermissions()] all'avvio per conoscere lo stato corrente.
/// 2. Per ogni permesso [PermissionStatus.denied], chiama il metodo specifico.
/// 3. Se [PermissionsState.hasPermanentlyDenied] è true, mostra il banner
///    LCARS "SYSTEM CRITICAL — MANUAL INTERVENTION REQUIRED".
abstract class PermissionService {
  /// Richiede il permesso SYSTEM_ALERT_WINDOW (overlay di sistema).
  ///
  /// Su Android, questo apre l'activity ACTION_MANAGE_OVERLAY_PERMISSION.
  /// Restituisce il [PermissionStatus] aggiornato dopo la richiesta.
  Future<PermissionStatus> requestOverlayPermission();

  /// Richiede il permesso RECORD_AUDIO (microfono).
  ///
  /// Restituisce il [PermissionStatus] aggiornato dopo la richiesta.
  Future<PermissionStatus> requestAudioPermission();

  /// Avvia il flusso completo di MediaProjection (cattura audio interno).
  ///
  /// ⚠️ CRITICO: questo non è un semplice runtime permission.
  /// Apre il dialogo di sistema MediaProjectionManager e richiede
  /// un'Activity Result. L'implementazione concreta gestisce
  /// il flusso in 7 passi definito in ARCHITECTURE.md.
  ///
  /// Restituisce il [PermissionStatus] aggiornato dopo il dialogo.
  Future<PermissionStatus> requestMediaProjection();

  /// Restituisce lo stato aggregato corrente di tutti i permessi Neuralis.
  ///
  /// Non richiede permessi — legge solo lo stato attuale.
  /// Da chiamare all'avvio dell'app e dopo ogni ritorno dalla app settings.
  Future<PermissionsState> checkAllPermissions();

  /// Apre le impostazioni dell'app Android per permettere all'utente
  /// di concedere manualmente i permessi negati permanentemente.
  ///
  /// Da invocare quando [PermissionsState.hasPermanentlyDenied] è true
  /// e l'utente conferma il banner LCARS "SYSTEM CRITICAL".
  Future<void> openAppSettings();
}

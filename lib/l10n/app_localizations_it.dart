// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Neuralis';

  @override
  String get systemActive => 'Neuralis — Sistema Attivo';

  @override
  String get systemInitialized => 'SISTEMA INIZIALIZZATO';

  @override
  String get statusOnline => 'ONLINE';

  @override
  String get statusWarning => 'ATTENZIONE';

  @override
  String get padBass => 'BASS';

  @override
  String get padNav => 'NAV';

  @override
  String get shaderLoadFailed => 'CALIBRAZIONE SENSORI FALLITA';

  @override
  String get permissionOverlayTitle => 'OVERLAY DI SISTEMA';

  @override
  String get permissionOverlayDescription =>
      'Necessario per visualizzare il Neural Wavefront sopra le altre applicazioni.';

  @override
  String get permissionOverlayButton => 'CONCEDI ACCESSO OVERLAY';

  @override
  String get permissionAudioTitle => 'CATTURA AUDIO';

  @override
  String get permissionAudioDescription =>
      'Necessario per catturare il suono ambientale tramite microfono (modalità Esterna e Ibrida).';

  @override
  String get permissionAudioButton => 'CONCEDI ACCESSO AUDIO';

  @override
  String get permissionMediaProjectionTitle => 'CATTURA AUDIO INTERNO';

  @override
  String get permissionMediaProjectionDescription =>
      'Necessario per catturare l\'audio di sistema dalle app di streaming (modalità Interna e Ibrida).';

  @override
  String get permissionMediaProjectionButton => 'ATTIVA CATTURA INTERNA';

  @override
  String get permissionStatusGranted => 'CONCESSO';

  @override
  String get permissionStatusDenied => 'NEGATO';

  @override
  String get permissionStatusUnknown => 'IN ATTESA';

  @override
  String get permissionStatusPermanentlyDenied => 'BLOCCATO';

  @override
  String get permissionCriticalTitle => 'SISTEMA CRITICO';

  @override
  String get permissionCriticalBody => 'INTERVENTO MANUALE RICHIESTO';

  @override
  String get permissionCriticalAction => 'APRI IMPOSTAZIONI SISTEMA';

  @override
  String get drmWarningBanner =>
      '⚠ AUDIO INTERNO BLOCCATO — ATTIVAZIONE SENSORE MIC AMBIENTALE';

  @override
  String get audioModeInternal => 'INTERNO';

  @override
  String get audioModeExternal => 'ESTERNO';

  @override
  String get audioModeHybrid => 'IBRIDO';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Neuralis';

  @override
  String get systemActive => 'Neuralis — System Active';

  @override
  String get systemInitialized => 'SYSTEM INITIALIZED';

  @override
  String get statusOnline => 'ONLINE';

  @override
  String get statusWarning => 'WARNING';

  @override
  String get padBass => 'BASS';

  @override
  String get padNav => 'NAV';

  @override
  String get shaderLoadFailed => 'SENSOR CALIBRATION FAILED';

  @override
  String get permissionOverlayTitle => 'SYSTEM ALERT WINDOW';

  @override
  String get permissionOverlayDescription =>
      'Required to display the Neural Wavefront overlay on top of other applications.';

  @override
  String get permissionOverlayButton => 'GRANT OVERLAY ACCESS';

  @override
  String get permissionAudioTitle => 'AUDIO CAPTURE';

  @override
  String get permissionAudioDescription =>
      'Required to capture ambient sound via microphone (External and Hybrid modes).';

  @override
  String get permissionAudioButton => 'GRANT AUDIO ACCESS';

  @override
  String get permissionMediaProjectionTitle => 'INTERNAL AUDIO CAPTURE';

  @override
  String get permissionMediaProjectionDescription =>
      'Required to capture system audio from streaming apps (Internal and Hybrid modes).';

  @override
  String get permissionMediaProjectionButton => 'ACTIVATE INTERNAL CAPTURE';

  @override
  String get permissionStatusGranted => 'GRANTED';

  @override
  String get permissionStatusDenied => 'DENIED';

  @override
  String get permissionStatusUnknown => 'PENDING';

  @override
  String get permissionStatusPermanentlyDenied => 'BLOCKED';

  @override
  String get permissionCriticalTitle => 'SYSTEM CRITICAL';

  @override
  String get permissionCriticalBody => 'MANUAL INTERVENTION REQUIRED';

  @override
  String get permissionCriticalAction => 'OPEN SYSTEM SETTINGS';

  @override
  String get drmWarningBanner =>
      '⚠ INTERNAL AUDIO BLOCKED — ACTIVATING AMBIENT MIC SENSOR';

  @override
  String get audioModeInternal => 'INTERNAL';

  @override
  String get audioModeExternal => 'EXTERNAL';

  @override
  String get audioModeHybrid => 'HYBRID';
}

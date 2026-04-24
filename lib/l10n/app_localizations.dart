import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Neuralis'**
  String get appTitle;

  /// Foreground service notification title
  ///
  /// In en, this message translates to:
  /// **'Neuralis — System Active'**
  String get systemActive;

  /// Placeholder screen status label
  ///
  /// In en, this message translates to:
  /// **'SYSTEM INITIALIZED'**
  String get systemInitialized;

  /// System status indicator — active
  ///
  /// In en, this message translates to:
  /// **'ONLINE'**
  String get statusOnline;

  /// System status indicator — DRM warning
  ///
  /// In en, this message translates to:
  /// **'WARNING'**
  String get statusWarning;

  /// Label for the bass interaction pad
  ///
  /// In en, this message translates to:
  /// **'BASS'**
  String get padBass;

  /// Label for the navigation interaction pad
  ///
  /// In en, this message translates to:
  /// **'NAV'**
  String get padNav;

  /// Error shown when the GLSL shader fails to load
  ///
  /// In en, this message translates to:
  /// **'SENSOR CALIBRATION FAILED'**
  String get shaderLoadFailed;

  /// Title for the overlay permission request section
  ///
  /// In en, this message translates to:
  /// **'SYSTEM ALERT WINDOW'**
  String get permissionOverlayTitle;

  /// Body text explaining why overlay permission is needed
  ///
  /// In en, this message translates to:
  /// **'Required to display the Neural Wavefront overlay on top of other applications.'**
  String get permissionOverlayDescription;

  /// Button label to open overlay permission settings
  ///
  /// In en, this message translates to:
  /// **'GRANT OVERLAY ACCESS'**
  String get permissionOverlayButton;

  /// Title for the microphone permission request section
  ///
  /// In en, this message translates to:
  /// **'AUDIO CAPTURE'**
  String get permissionAudioTitle;

  /// Body text explaining why microphone permission is needed
  ///
  /// In en, this message translates to:
  /// **'Required to capture ambient sound via microphone (External and Hybrid modes).'**
  String get permissionAudioDescription;

  /// Button label to request microphone permission
  ///
  /// In en, this message translates to:
  /// **'GRANT AUDIO ACCESS'**
  String get permissionAudioButton;

  /// Title for the MediaProjection permission request section
  ///
  /// In en, this message translates to:
  /// **'INTERNAL AUDIO CAPTURE'**
  String get permissionMediaProjectionTitle;

  /// Body text explaining why MediaProjection permission is needed
  ///
  /// In en, this message translates to:
  /// **'Required to capture system audio from streaming apps (Internal and Hybrid modes).'**
  String get permissionMediaProjectionDescription;

  /// Button label to start MediaProjection flow
  ///
  /// In en, this message translates to:
  /// **'ACTIVATE INTERNAL CAPTURE'**
  String get permissionMediaProjectionButton;

  /// Label when a permission is granted
  ///
  /// In en, this message translates to:
  /// **'GRANTED'**
  String get permissionStatusGranted;

  /// Label when a permission is denied
  ///
  /// In en, this message translates to:
  /// **'DENIED'**
  String get permissionStatusDenied;

  /// Label when a permission status is unknown
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get permissionStatusUnknown;

  /// Label when a permission is permanently denied
  ///
  /// In en, this message translates to:
  /// **'BLOCKED'**
  String get permissionStatusPermanentlyDenied;

  /// Title of the LCARS critical banner for permanently denied permissions
  ///
  /// In en, this message translates to:
  /// **'SYSTEM CRITICAL'**
  String get permissionCriticalTitle;

  /// Body of the LCARS critical banner for permanently denied permissions
  ///
  /// In en, this message translates to:
  /// **'MANUAL INTERVENTION REQUIRED'**
  String get permissionCriticalBody;

  /// Button label to open app settings when permission is permanently denied
  ///
  /// In en, this message translates to:
  /// **'OPEN SYSTEM SETTINGS'**
  String get permissionCriticalAction;

  /// LCARS warning banner shown when DRM failover is triggered
  ///
  /// In en, this message translates to:
  /// **'⚠ INTERNAL AUDIO BLOCKED — ACTIVATING AMBIENT MIC SENSOR'**
  String get drmWarningBanner;

  /// Label for internal audio capture mode
  ///
  /// In en, this message translates to:
  /// **'INTERNAL'**
  String get audioModeInternal;

  /// Label for external (microphone) audio capture mode
  ///
  /// In en, this message translates to:
  /// **'EXTERNAL'**
  String get audioModeExternal;

  /// Label for hybrid audio capture mode
  ///
  /// In en, this message translates to:
  /// **'HYBRID'**
  String get audioModeHybrid;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

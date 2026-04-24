/// Neuralis — l10n
/// Estensione BuildContext per accesso rapido a AppLocalizations.
///
/// Posizione: lib/l10n/l10n_extension.dart
library;

import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// Shorthand per `AppLocalizations.of(context)!`.
///
/// Uso in ogni widget LCARS:
/// ```dart
/// Text(context.l10n.padBass)
/// ```
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

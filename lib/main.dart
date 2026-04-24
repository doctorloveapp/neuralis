/// Neuralis — App root con ProviderScope e inizializzazione servizi.
///
/// Posizione: lib/main.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

/// Entry point dell'applicazione Neuralis.
///
/// ⚠️ ORDINE OBBLIGATORIO:
///   1. WidgetsFlutterBinding.ensureInitialized() — prima di qualsiasi
///      operazione async o accesso al motore Flutter.
///   2. ProviderScope — radice obbligatoria per Riverpod 3.x.
///   3. NeuralisApp — MaterialApp con i18n, tema LCARS base e routing.
///
/// Il warm-up dello shader (ShaderRepository.loadShader()) e l'init
/// dei servizi avvengono nel layer Presentation durante lo splash screen,
/// NON qui — per rispettare Clean Architecture.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: NeuralisApp(),
    ),
  );
}

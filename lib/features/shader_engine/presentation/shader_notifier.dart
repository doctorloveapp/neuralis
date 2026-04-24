/// Neuralis — Shader Engine / Presentation
/// ShaderNotifier: gestisce il Ticker a 60fps e gli uniforms dello shader.
///
/// Posizione: lib/features/shader_engine/presentation/shader_notifier.dart
library;

import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/wavefront_uniforms.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ShaderState — stato immutabile del motore shader
// ─────────────────────────────────────────────────────────────────────────────

/// Stato del ciclo di vita e degli uniforms del shader.
class ShaderState {
  const ShaderState({
    required this.isLoaded,
    required this.isRunning,
    required this.uniforms,
    this.errorKey,
  });

  /// True se [ShaderRepositoryImpl.loadShader()] è completato.
  final bool isLoaded;

  /// True se il Ticker è attivo (frame loop in esecuzione).
  final bool isRunning;

  /// Uniforms correnti del frame — aggiornati ~60 volte al secondo.
  final WavefrontUniforms uniforms;

  /// Chiave i18n per l'errore (null = nessun errore).
  /// Esempio: 'shaderLoadFailed'
  final String? errorKey;

  factory ShaderState.initial() => ShaderState(
        isLoaded:  false,
        isRunning: false,
        uniforms:  WavefrontUniforms.initial(),
      );

  ShaderState copyWith({
    bool?             isLoaded,
    bool?             isRunning,
    WavefrontUniforms? uniforms,
    String?           errorKey,
  }) =>
      ShaderState(
        isLoaded:  isLoaded  ?? this.isLoaded,
        isRunning: isRunning ?? this.isRunning,
        uniforms:  uniforms  ?? this.uniforms,
        errorKey:  errorKey  ?? this.errorKey,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ShaderNotifier — Ticker a 60fps + sincronizzazione uniforms
// ─────────────────────────────────────────────────────────────────────────────

/// AsyncNotifier che gestisce:
///   1. Warm-up asincrono dello shader (SchedulerBinding.instance.addPostFrameCallback)
///   2. Ticker a 60fps per aggiornare uTime
///   3. Ricezione degli aggiornamenti FFT dall'AudioNotifier
///
/// Il Ticker usa [SchedulerBinding] direttamente per evitare dipendenze
/// su widget/vsync specifici (il notifier vive fuori dal tree di widget).
class ShaderNotifier extends AsyncNotifier<ShaderState> {
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  double   _elapsedSeconds = 0.0;

  @override
  Future<ShaderState> build() async {
    ref.onDispose(_cleanup);
    return ShaderState.initial();
  }

  // ─────────────────────────────────────────────────────────────────────
  // API pubblica
  // ─────────────────────────────────────────────────────────────────────

  /// Avvia il warm-up dello shader e il Ticker.
  /// Da chiamare durante la fase di Init/Splash dell'app.
  Future<void> initialize(dynamic shaderRepository) async {
    state = const AsyncLoading();
    try {
      await shaderRepository.loadShader();
      _startTicker();
      state = AsyncData(ShaderState.initial().copyWith(
        isLoaded:  true,
        isRunning: true,
      ));
    } catch (e, _) {
      state = AsyncData(ShaderState.initial().copyWith(
        errorKey: 'shaderLoadFailed',
      ));
      // Non ri-throw: errori shader non devono crashare l'app
    }
  }

  /// Aggiorna le bande FFT correnti (chiamato dall'AudioNotifier).
  /// Difesa in profondità: clampa ogni banda in [0.0, 1.0] e
  /// valida che la lista abbia esattamente 32 elementi.
  void updateAudio(List<double> bands) {
    final current = state.asData?.value;
    if (current == null || !current.isLoaded) return;

    // Validazione lunghezza: se non 32, padding/troncamento silenzioso
    List<double> safeBands;
    if (bands.length == 32) {
      safeBands = bands;
    } else {
      debugPrint('[ShaderNotifier] updateAudio: attese 32 bande, ricevute ${bands.length}');
      safeBands = List<double>.generate(
        32,
        (i) => i < bands.length ? bands[i].clamp(0.0, 1.0) : 0.0,
        growable: false,
      );
    }

    state = AsyncData(current.copyWith(
      uniforms: current.uniforms.copyWith(audioFrequency: safeBands),
    ));
  }

  /// Aggiorna il vettore di bending (chiamato dall'InteractionController S5).
  /// Difesa in profondità: clampa entrambi gli assi in [-1.0, 1.0].
  void updateBending(Offset bending) {
    final current = state.asData?.value;
    if (current == null) return;

    final clampedBending = Offset(
      bending.dx.clamp(-1.0, 1.0),
      bending.dy.clamp(-1.0, 1.0),
    );

    state = AsyncData(current.copyWith(
      uniforms: current.uniforms.copyWith(bending: clampedBending),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────
  // Ticker privato
  // ─────────────────────────────────────────────────────────────────────

  void _startTicker() {
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed    = elapsed;
    _elapsedSeconds += dt;

    final current = state.asData?.value;
    if (current == null || !current.isLoaded) return;

    state = AsyncData(current.copyWith(
      uniforms: current.uniforms.copyWith(time: _elapsedSeconds),
    ));
  }

  void _cleanup() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
  }
}

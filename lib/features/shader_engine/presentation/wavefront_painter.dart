/// Neuralis — Shader Engine / Presentation
/// WavefrontPainter: CustomPainter che renderizza il fragment shader.
///
/// Posizione: lib/features/shader_engine/presentation/wavefront_painter.dart
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/repositories/shader_repository_impl.dart';
import '../domain/entities/wavefront_uniforms.dart';

/// CustomPainter che esegue il fragment shader su un [Canvas].
///
/// Riceve [fragmentShader] e [uniforms] come parametri immutabili.
/// Il [ShaderNotifier] aggiorna questi valori tramite [notifyListeners]
/// ad ogni tick del Ticker (target: 60fps).
///
/// ⚠️ REGOLA PERFORMANCE: il [fragmentShader] è una singola istanza GPU
/// riutilizzata ad ogni frame. NON creare nuove istanze in paint().
class WavefrontPainter extends CustomPainter {
  const WavefrontPainter({
    required this.fragmentShader,
    required this.uniforms,
    required this.repository,
  });

  /// FragmentShader già compilato e caricato da [ShaderRepositoryImpl].
  final ui.FragmentShader fragmentShader;

  /// Uniforms correnti del frame (time, resolution, FFT, bending).
  final WavefrontUniforms uniforms;

  /// Repository per aggiornare gli uniforms prima di ogni draw call.
  final ShaderRepositoryImpl repository;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Aggiorna risoluzione con le dimensioni reali del canvas
    final currentUniforms = uniforms.copyWith(
      resolution: ui.Offset(size.width, size.height),
    );

    // 2. Scrivi tutti gli uniforms sul FragmentShader (zero allocazioni)
    repository.updateUniforms(currentUniforms);

    // 3. Paint con lo shader
    final paint = Paint()..shader = fragmentShader;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(WavefrontPainter old) {
    // Ripingi se il tempo o i dati audio sono cambiati
    return old.uniforms.time != uniforms.time ||
        old.uniforms.audioFrequency != uniforms.audioFrequency ||
        old.uniforms.bending != uniforms.bending;
  }
}

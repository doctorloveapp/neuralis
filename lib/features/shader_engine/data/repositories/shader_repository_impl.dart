/// Neuralis — Shader Engine / Data / Repositories
/// ShaderRepositoryImpl: caricamento e controllo del FragmentShader.
///
/// Posizione: lib/features/shader_engine/data/repositories/shader_repository_impl.dart
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/entities/shader_params.dart';
import '../../domain/entities/wavefront_uniforms.dart';
import '../../domain/repositories/shader_repository.dart';

/// Implementazione concreta di [ShaderRepository].
///
/// Incapsula [ui.FragmentProgram] e [ui.FragmentShader] — ZERO fuga di dart:ui
/// al di fuori di questo file (ARCHITECTURE.md §4).
///
/// Strategia di warm-up:
///   - [loadShader()] deve essere chiamato durante la fase Splash/Init dell'app,
///     PRIMA di navigare all'OverlayDashboard.
///   - [updateUniforms()] scrive direttamente sul [FragmentShader] già allocato,
///     riutilizzando la stessa istanza ad ogni frame (zero allocazioni).
class ShaderRepositoryImpl implements ShaderRepository {
  static const _shaderAsset = 'assets/shaders/wavefront.frag';

  ui.FragmentProgram? _program;
  ui.FragmentShader?  _shader;
  bool _isLoaded = false;

  /// L'istanza [FragmentShader] pronta per essere passata al [WavefrontPainter].
  /// Null se [loadShader()] non è ancora stato completato.
  ui.FragmentShader? get fragmentShader => _shader;

  @override
  bool get isLoaded => _isLoaded;

  // ─────────────────────────────────────────────────────────────────────
  // loadShader — warm-up obbligatorio allo startup
  // ─────────────────────────────────────────────────────────────────────

  @override
  Future<void> loadShader({ShaderParams? params}) async {
    if (_isLoaded) return; // idempotente

    debugPrint('[ShaderRepository] Caricamento $_shaderAsset...');
    _program = await ui.FragmentProgram.fromAsset(_shaderAsset);
    _shader  = _program!.fragmentShader();

    // Scrivi i parametri strutturali iniziali (risoluzione placeholder)
    final uniforms = WavefrontUniforms.initial();
    updateUniforms(uniforms);

    _isLoaded = true;
    debugPrint('[ShaderRepository] Shader caricato ✓');
  }

  // ─────────────────────────────────────────────────────────────────────
  // updateUniforms — chiamato ogni frame dal WavefrontPainter
  // ─────────────────────────────────────────────────────────────────────

  /// Scrive gli uniforms sul [FragmentShader] secondo l'ordine degli indici
  /// definito in ARCHITECTURE.md §6 e in wavefront_uniforms.dart:
  ///
  ///   Index 0      → uTime
  ///   Index 1-2    → uResolution (x, y)
  ///   Index 3-34   → uAudioFrequency[0..31]
  ///   Index 35-36  → uBending (x, y)
  @override
  void updateUniforms(WavefrontUniforms uniforms) {
    final shader = _shader;
    if (shader == null) return; // shader non ancora caricato

    shader.setFloat(0, uniforms.time.toDouble());
    shader.setFloat(1, uniforms.resolution.dx);
    shader.setFloat(2, uniforms.resolution.dy);

    for (int i = 0; i < 32; i++) {
      shader.setFloat(3 + i, uniforms.audioFrequency[i]);
    }

    shader.setFloat(35, uniforms.bending.dx);
    shader.setFloat(36, uniforms.bending.dy);
  }

  // ─────────────────────────────────────────────────────────────────────
  // dispose
  // ─────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _shader?.dispose();
    _shader = null;
    _program = null;
    _isLoaded = false;
    debugPrint('[ShaderRepository] dispose() completato');
  }
}

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
  ///   Index 3-34   → uAudioBand0..7 (32 float)
  ///   Index 35-36  → uBending (x, y)
  ///   Index 37-39  → uColorBase (r, g, b)
  ///   Index 40-42  → uColorMid  (r, g, b)
  ///   Index 43-45  → uColorPeak (r, g, b)
  ///   Index 46     → uFov
  ///   Index 47     → uMeshW
  ///   Index 48     → uLineWeight
  ///   Index 49     → uWaveSpeed
  @override
  void updateUniforms(WavefrontUniforms uniforms) {
    final shader = _shader;
    if (shader == null) return;

    shader.setFloat(0, uniforms.time.toDouble());
    shader.setFloat(1, uniforms.resolution.dx);
    shader.setFloat(2, uniforms.resolution.dy);

    for (int i = 0; i < 32; i++) {
      shader.setFloat(3 + i, uniforms.audioFrequency[i]);
    }

    shader.setFloat(35, uniforms.bending.dx);
    shader.setFloat(36, uniforms.bending.dy);

    // ── Colori preset (vec3 → 3 float ciascuno) ───────────────────────────
    shader.setFloat(37, uniforms.colorBase.r);
    shader.setFloat(38, uniforms.colorBase.g);
    shader.setFloat(39, uniforms.colorBase.b);

    shader.setFloat(40, uniforms.colorMid.r);
    shader.setFloat(41, uniforms.colorMid.g);
    shader.setFloat(42, uniforms.colorMid.b);

    shader.setFloat(43, uniforms.colorPeak.r);
    shader.setFloat(44, uniforms.colorPeak.g);
    shader.setFloat(45, uniforms.colorPeak.b);

    // ── Geometria preset ──────────────────────────────────────────────────
    shader.setFloat(46, uniforms.fov);
    shader.setFloat(47, uniforms.meshW);
    shader.setFloat(48, uniforms.lineWeight);
    shader.setFloat(49, uniforms.waveSpeed);
    shader.setFloat(50, uniforms.camDist);
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

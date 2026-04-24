/// Neuralis — Shader Engine / Presentation
/// WavefrontWidget: widget che wrappa WavefrontPainter con placeholder LCARS.
///
/// Posizione: lib/features/shader_engine/presentation/wavefront_widget.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../shared/theme/lcars_colors.dart';
import '../../../shared/theme/lcars_typography.dart';
import 'wavefront_painter.dart';

/// Widget che ospita il WavefrontPainter e gestisce gli stati:
///   - Loading → placeholder "INITIALIZING SENSORS..."
///   - Error   → placeholder "SENSOR CALIBRATION FAILED"
///   - Ready   → CustomPaint con WavefrontPainter
///
/// Riceve [shaderRepository] già inizializzato dal provider.
class WavefrontWidget extends ConsumerWidget {
  const WavefrontWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shaderAsync = ref.watch(shaderNotifierProvider);

    return shaderAsync.when(
      loading: () => _LcarsPlaceholder(label: 'INITIALIZING SENSORS...'),
      error:   (_, __) => _LcarsPlaceholder(
        label: context.l10n.shaderLoadFailed.toUpperCase(),
        isError: true,
      ),
      data: (shaderState) {
        // ⚠️ Controllare errorKey PRIMA di isLoaded!
        // Se lo shader fallisce, errorKey è set ma isLoaded resta false.
        if (shaderState.errorKey != null) {
          return _LcarsPlaceholder(
            label: context.l10n.shaderLoadFailed.toUpperCase(),
            isError: true,
          );
        }
        if (!shaderState.isLoaded) {
          return _LcarsPlaceholder(label: 'INITIALIZING SENSORS...');
        }

        final repo   = ref.watch(shaderRepositoryProvider);
        final shader = repo.fragmentShader;
        if (shader == null) {
          return _LcarsPlaceholder(label: 'INITIALIZING SENSORS...');
        }

        return RepaintBoundary(
          child: CustomPaint(
            painter: WavefrontPainter(
              fragmentShader: shader,
              uniforms:       shaderState.uniforms,
              repository:     repo,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LcarsPlaceholder — schermata di attesa stile LCARS
// ─────────────────────────────────────────────────────────────────────────────

class _LcarsPlaceholder extends StatelessWidget {
  const _LcarsPlaceholder({required this.label, this.isError = false});

  final String label;
  final bool   isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? LcarsColors.warning : LcarsColors.blueGray;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Indicatore animato (pulsante)
          if (!isError)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.3, end: 1.0),
              duration: const Duration(milliseconds: 800),
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LcarsColors.blueGray,
                ),
              ),
            ),
          if (!isError) const SizedBox(height: 16),
          Text(
            label,
            style: LcarsTypography.labelSmall.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

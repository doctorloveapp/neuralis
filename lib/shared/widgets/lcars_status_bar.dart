/// Neuralis — Shared Widgets
/// LcarsStatusBar: barra di stato superiore dell'overlay.
///
/// Posizione: lib/shared/widgets/lcars_status_bar.dart
library;

import 'package:flutter/material.dart';

import '../../features/audio_engine/domain/entities/audio_entity.dart';
import '../../features/audio_engine/presentation/audio_state.dart';
import '../../l10n/l10n_extension.dart';
import '../theme/lcars_colors.dart';
import '../theme/lcars_typography.dart';

/// Barra di stato LCARS — mostra sorgente audio e stato del sistema.
///
/// Layout:
///   [NEURALIS] ─── [audio mode label] ─── [• ONLINE / ⚠ WARNING]
///
/// Si aggiorna automaticamente quando [audioState] cambia.
class LcarsStatusBar extends StatelessWidget {
  const LcarsStatusBar({
    super.key,
    this.audioState,
    this.height = 44.0,
  });

  final AudioState? audioState;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDrm     = audioState?.isDrmBlocked ?? false;
    final mode      = audioState?.mode ?? AudioCaptureMode.internal;
    final capturing = audioState?.isCapturing ?? false;

    final statusColor = isDrm ? LcarsColors.warning : LcarsColors.online;
    final statusLabel = isDrm ? l10n.statusWarning : l10n.statusOnline;
    final modeLabel   = _modeLabel(mode, l10n);

    return Container(
      height: height,
      color: LcarsColors.panelBg,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // ── Brand ────────────────────────────────────────────────────
          Text(
            'NEURALIS',
            style: LcarsTypography.label.copyWith(
              color: LcarsColors.atomic,
              letterSpacing: 4.0,
            ),
          ),

          // ── Separatore ────────────────────────────────────────────────
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              height: 1,
              color: LcarsColors.withAlpha(LcarsColors.blueGray, 0.4),
            ),
          ),

          // ── Modalità audio ────────────────────────────────────────────
          if (capturing)
            Text(
              modeLabel,
              style: LcarsTypography.labelSmall,
            ),
          if (capturing)
            const SizedBox(width: 16),

          // ── Indicatore stato ──────────────────────────────────────────
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusLabel.toUpperCase(),
            style: LcarsTypography.status.copyWith(color: statusColor),
          ),
        ],
      ),
    );
  }

  String _modeLabel(AudioCaptureMode mode, dynamic l10n) {
    return switch (mode) {
      AudioCaptureMode.internal => l10n.audioModeInternal,
      AudioCaptureMode.external => l10n.audioModeExternal,
      AudioCaptureMode.hybrid   => l10n.audioModeHybrid,
    };
  }
}

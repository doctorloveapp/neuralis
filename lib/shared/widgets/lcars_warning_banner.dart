/// Neuralis — Shared Widgets
/// LcarsWarningBanner: banner lampeggiante per eventi DRM.
///
/// Posizione: lib/shared/widgets/lcars_warning_banner.dart
library;

import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../theme/lcars_colors.dart';
import '../theme/lcars_typography.dart';

/// Banner animato (blink 1 Hz) che appare quando [isDrmBlocked] è true.
///
/// Mostra il messaggio i18n [drmWarningBanner] in stile LCARS warning.
/// La visibilità è controllata esternamente — questo widget si limita
/// ad animarsi quando è inserito nel tree.
///
/// Collegamento allo stato DRM in [OverlayDashboard]:
/// ```dart
/// if (audioState?.isDrmBlocked == true)
///   const LcarsWarningBanner(),
/// ```
class LcarsWarningBanner extends StatefulWidget {
  const LcarsWarningBanner({super.key});

  @override
  State<LcarsWarningBanner> createState() => _LcarsWarningBannerState();
}

class _LcarsWarningBannerState extends State<LcarsWarningBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double>   _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500), // 0.5s ON + 0.5s OFF = 1Hz
    )..repeat(reverse: true);

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: LcarsColors.withAlpha(LcarsColors.warning, 0.15),
        child: Row(
          children: [
            // ── Icona warning ─────────────────────────────────────────
            Container(
              width: 4,
              height: 20,
              color: LcarsColors.warning,
              margin: const EdgeInsets.only(right: 12),
            ),

            // ── Testo DRM ─────────────────────────────────────────────
            Expanded(
              child: Text(
                context.l10n.drmWarningBanner.toUpperCase(),
                style: LcarsTypography.warningLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

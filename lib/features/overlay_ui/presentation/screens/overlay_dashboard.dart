/// Neuralis — Overlay UI / Presentation / Screens
/// OverlayDashboard: layout principale dell'overlay LCARS.
///
/// Posizione: lib/features/overlay_ui/presentation/screens/overlay_dashboard.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../l10n/l10n_extension.dart';
import '../../../../shared/theme/lcars_colors.dart';
import '../../../../shared/theme/lcars_typography.dart';
import '../../../../shared/widgets/lcars_button.dart';
import '../../../../shared/widgets/lcars_elbow.dart';
import '../../../../shared/widgets/lcars_status_bar.dart';
import '../../../../shared/widgets/lcars_warning_banner.dart';
import '../../../audio_engine/domain/entities/audio_entity.dart';
import '../../../preset/domain/entities/neuralis_preset.dart';
import '../../../shader_engine/presentation/wavefront_widget.dart';

/// Schermata principale dell'overlay LCARS.
///
/// Layout asimmetrico (ispirato alla griglia LCARS originale):
///
///   ┌─────────────────────────────┐
///   │  [STATUS BAR]               │  ← atomic orange, 44px
///   │  [DRM WARNING BANNER?]      │  ← tan, lampeggiante (se isDrmBlocked)
///   ├──┬──────────────────────────┤
///   │EL│                          │  ← Elbow + area vuota (Sezione 4: Wavefront)
///   │EL│   WAVEFRONT ENGINE       │
///   │EL│   (placeholder S4)       │
///   ├──┴──────┬───────────────────┤
///   │[BASS]   │  [NAV]            │  ← pads interattivi
///   └─────────┴───────────────────┘
///
/// ⚠️ Questo widget è renderizzato da [OverlayManager.kt] come overlay
/// di sistema tramite WindowManager. NON deve avere Scaffold.
class OverlayDashboard extends ConsumerWidget {
  const OverlayDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioAsync   = ref.watch(audioNotifierProvider);
    final audioState   = audioAsync.asData?.value;
    final isDrmBlocked = audioState?.isDrmBlocked ?? false;
    final l10n         = context.l10n;

    return SafeArea(
      child: SizedBox.expand(
        child: Material(
          color: Colors.transparent,
          child: Container(
            color: LcarsColors.overlayBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            // ── Status Bar ───────────────────────────────────────────────
            LcarsStatusBar(audioState: audioState),

            // ── DRM Warning Banner (condizionale) ─────────────────────────
            if (isDrmBlocked) const LcarsWarningBanner(),

            // ── LAUNCH TACTICAL OVERLAY ───────────────────────────────────
            _LaunchOverlayButton(ref: ref),

            // ── Area Centrale: Elbows + Wavefront ─────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Colonna sinistra: elbows verticali LCARS
                  _LeftColumn(),

                  // Area centrale: WavefrontWidget
                  const Expanded(
                    child: WavefrontWidget(),
                  ),
                ],
              ),
            ),

            // ── Bottom: Pads interattivi ──────────────────────────────────
              _BottomPadRow(ref: ref, l10n: l10n, audioState: audioState),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LaunchOverlayButton — pulsante LAUNCH TACTICAL OVERLAY
// ---------------------------------------------------------------------------

class _LaunchOverlayButton extends StatelessWidget {
  const _LaunchOverlayButton({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final overlayState = ref.watch(overlayNotifierProvider);
    final isVisible    = overlayState.isVisible;

    return Container(
      color:   LcarsColors.panelBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Indicatore stato overlay
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isVisible ? LcarsColors.atomic : LcarsColors.blueGray,
              boxShadow: isVisible ? [
                BoxShadow(
                  color: LcarsColors.withAlpha(LcarsColors.atomic, 0.6),
                  blurRadius: 8, spreadRadius: 2,
                ),
              ] : null,
            ),
          ),
          const SizedBox(width: 10),

          // Pulsante principale
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(overlayNotifierProvider.notifier).toggle(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 44,
                decoration: BoxDecoration(
                  color: LcarsColors.withAlpha(
                    isVisible ? LcarsColors.atomic : LcarsColors.blueGray,
                    isVisible ? 0.20 : 0.10,
                  ),
                  border: Border.all(
                    color: isVisible ? LcarsColors.atomic : LcarsColors.blueGray,
                    width: isVisible ? 2.0 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  isVisible ? 'OVERLAY ATTIVO  ● TOCCA PER NASCONDERE' : '▶  LAUNCH TACTICAL OVERLAY',
                  style: LcarsTypography.label.copyWith(
                    color: isVisible ? LcarsColors.atomic : LcarsColors.blueGray,
                    fontSize: 13,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LeftColumn — colonna sinistra LCARS con elbows
// ---------------------------------------------------------------------------

class _LeftColumn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: Column(
        children: [
          // Elbow superiore (angolo top-left del contenuto)
          SizedBox(
            width: 56,
            height: 80,
            child: const LcarsElbow(
              orientation:         LcarsElbowOrientation.topLeft,
              horizontalThickness: 14,
              verticalThickness:   56,
              cornerRadius:        46,
              color:               LcarsColors.blueGray,
            ),
          ),

          // Barra verticale centrale
          Expanded(
            child: Container(
              width: 14,
              color: LcarsColors.blueGray,
            ),
          ),

          // Elbow inferiore (angolo bottom-left del contenuto)
          SizedBox(
            width: 56,
            height: 80,
            child: const LcarsElbow(
              orientation:         LcarsElbowOrientation.bottomLeft,
              horizontalThickness: 14,
              verticalThickness:   56,
              cornerRadius:        46,
              color:               LcarsColors.purple,
            ),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// _BottomPadRow — BassPad + NavPad
// ---------------------------------------------------------------------------

class _BottomPadRow extends StatelessWidget {
  const _BottomPadRow({
    required this.ref,
    required this.l10n,
    required this.audioState,
  });

  final WidgetRef ref;
  final dynamic   l10n;
  final dynamic   audioState;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      color: LcarsColors.panelBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // ── BassPad ────────────────────────────────────────────────────
          _BassPad(ref: ref, l10n: l10n),

          const SizedBox(width: 12),

          // ── Separatore centrale ────────────────────────────────────────
          Container(width: 1, color: LcarsColors.withAlpha(LcarsColors.blueGray, 0.3)),

          const SizedBox(width: 12),

          // ── NavPad ─────────────────────────────────────────────────────
          Expanded(child: _NavPad(ref: ref, l10n: l10n)),

          const SizedBox(width: 16),

          // ── Mode switcher ──────────────────────────────────────────────
          _ModeSwitcher(ref: ref, l10n: l10n, audioState: audioState),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _BassPad — pulsante pressione continua bass con feedback visivo
// ---------------------------------------------------------------------------

class _BassPad extends StatelessWidget {
  const _BassPad({required this.ref, required this.l10n});
  final WidgetRef ref;
  final dynamic   l10n;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, watchRef, _) {
        // ref.select → rebuild SOLO quando bassGain cambia
        final bassGain = watchRef.watch(
          interactionControllerProvider.select((s) => s.bassGain),
        );

        // Interpolazione colore blueGray → atomic proporzionale al gain [1.0, 3.0]
        final t     = ((bassGain - 1.0) / 2.0).clamp(0.0, 1.0);
        final color = Color.lerp(LcarsColors.blueGray, LcarsColors.atomic, t)!;

        return GestureDetector(
          // Long press: pressione continua → boost sostenuto
          onLongPressStart: (_) => ref
              .read(interactionControllerProvider.notifier)
              .onBassPadPressed(),
          onLongPressEnd: (_) => ref
              .read(interactionControllerProvider.notifier)
              .onBassPadReleased(),
          // Tap breve: burst rapido
          onTapDown: (_) => ref
              .read(interactionControllerProvider.notifier)
              .onBassPadPressed(),
          onTapUp: (_) => ref
              .read(interactionControllerProvider.notifier)
              .onBassPadReleased(),
          onTapCancel: () => ref
              .read(interactionControllerProvider.notifier)
              .onBassPadReleased(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width:  100,
            height: 64,
            decoration: BoxDecoration(
              color:        LcarsColors.withAlpha(color, 0.15 + t * 0.25),
              border:       Border.all(color: color, width: 1.5 + t),
              borderRadius: const BorderRadius.only(
                topLeft:     Radius.circular(28),
                bottomLeft:  Radius.circular(28),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              l10n.padBass.toUpperCase(),
              style: LcarsTypography.label.copyWith(color: color, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _NavPad — selettore preset Multiverse + swipe rotazione
// ---------------------------------------------------------------------------

class _NavPad extends StatelessWidget {
  const _NavPad({required this.ref, required this.l10n});
  final WidgetRef ref;
  final dynamic   l10n;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, watchRef, _) {
        final activePreset = watchRef.watch(presetNotifierProvider);
        final presetData   = PresetLibrary.of(activePreset);
        final isBending    = watchRef.watch(
          interactionControllerProvider.select((s) => s.isBending),
        );

        // Colore bordo dal preset attivo
        final baseColor = presetData.colorMid;
        final borderColor = isBending
            ? baseColor.withAlpha(200)
            : baseColor.withAlpha(100);
        final bgColor = baseColor.withAlpha(isBending ? 50 : 25);

        return LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              // TAP: cicla al prossimo preset
              onTap: () {
                ref.read(presetNotifierProvider.notifier).next();
                // Propaga il nuovo preset allo shader
                final next = ref.read(presetNotifierProvider.notifier).current;
                try {
                  ref.read(shaderNotifierProvider.notifier).updatePreset(next);
                } catch (_) {}
                HapticFeedback.mediumImpact();
              },
              // SWIPE: rotazione NavPad (come v6)
              onPanUpdate: (details) {
                final w = constraints.maxWidth.clamp(1.0, double.infinity);
                final h = constraints.maxHeight.clamp(1.0, double.infinity);
                ref
                    .read(interactionControllerProvider.notifier)
                    .onNavPadUpdate(
                      details.delta.dx / w,
                      details.delta.dy / h,
                    );
              },
              onPanEnd: (_) => ref
                  .read(interactionControllerProvider.notifier)
                  .onNavPadEnd(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 64,
                decoration: BoxDecoration(
                  color:  bgColor,
                  border: Border.all(color: borderColor, width: isBending ? 2.0 : 1.0),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'NAV: ${presetData.shortName}',
                      style: LcarsTypography.label.copyWith(
                        color: borderColor,
                        fontSize: 13,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '◀ SWIPE │ TAP ▶',
                      style: LcarsTypography.labelSmall.copyWith(
                        color: borderColor.withAlpha(140),
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _ModeSwitcher — bottoni cambio modalità audio
// ---------------------------------------------------------------------------

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({
    required this.ref,
    required this.l10n,
    required this.audioState,
  });

  final WidgetRef ref;
  final dynamic   l10n;
  final dynamic   audioState;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
     child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // INT button
        _ModeButton(
          label:    l10n.audioModeInternal,
          isActive: audioState?.mode == AudioCaptureMode.internal,
          color:    LcarsColors.atomic,
          onTap:    () => ref
              .read(audioNotifierProvider.notifier)
              .setMode(AudioCaptureMode.internal),
        ),
        // EXT button
        _ModeButton(
          label:    l10n.audioModeExternal,
          isActive: audioState?.mode == AudioCaptureMode.external,
          color:    LcarsColors.blueGray,
          onTap:    () => ref
              .read(audioNotifierProvider.notifier)
              .setMode(AudioCaptureMode.external),
        ),
      ],
     ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  final String   label;
  final bool     isActive;
  final Color    color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LcarsButton(
      label:    label,
      onTap:    onTap,
      color:    color,
      isActive: !isActive,
      width:    90,
      height:   32,
    );
  }
}

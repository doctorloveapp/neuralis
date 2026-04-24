/// Neuralis — Overlay UI / Presentation / Notifiers
/// OverlayNotifier: Riverpod 3.x Notifier per la visibilità overlay.
///
/// Posizione: lib/features/overlay_ui/presentation/notifiers/overlay_notifier.dart
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../states/overlay_state.dart';

/// Notifier che gestisce la visibilità, opacità e lock dell'overlay.
///
/// Comunica con [OverlayManager.kt] tramite MethodChannel('neuralis/overlay').
/// Il layer Flutter non conosce WindowManager — delega tutto al layer nativo.
class OverlayNotifier extends Notifier<OverlayState> {
  static const _channel = MethodChannel('neuralis/overlay');

  @override
  OverlayState build() => OverlayState.initial();

  // ─────────────────────────────────────────────────────────────────────
  // Comandi pubblici
  // ─────────────────────────────────────────────────────────────────────

  Future<void> show() async {
    await _channel.invokeMethod<void>('show');
    state = state.copyWith(isVisible: true);
  }

  Future<void> hide() async {
    await _channel.invokeMethod<void>('hide');
    state = state.copyWith(isVisible: false);
  }

  Future<void> toggle() async {
    if (state.isVisible) {
      await hide();
    } else {
      await show();
    }
  }

  Future<void> setOpacity(double opacity) async {
    await _channel.invokeMethod<void>('setOpacity', opacity);
    state = state.copyWith(opacity: opacity);
  }

  Future<void> setLocked(bool locked) async {
    await _channel.invokeMethod<void>('setLocked', locked);
    state = state.copyWith(isLocked: locked);
  }
}

/// Neuralis — Core DI
/// Provider Riverpod globali per tutto il progetto.
///
/// Posizione: lib/core/di/providers.dart
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/audio_engine/data/repositories/audio_capture_repository_impl.dart';
import '../../features/audio_engine/domain/repositories/audio_capture_repository.dart';
import '../../features/audio_engine/presentation/audio_notifier.dart';
import '../../features/audio_engine/presentation/audio_state.dart';
import '../../features/overlay_ui/presentation/notifiers/overlay_notifier.dart';
import '../../features/overlay_ui/presentation/states/overlay_state.dart';
import '../../features/shader_engine/data/repositories/shader_repository_impl.dart';
import '../../features/shader_engine/presentation/shader_notifier.dart';
import '../services/permission_service.dart';
import '../services/permission_service_impl.dart';

// ═══════════════════════════════════════════════════════════════════════
// CORE — Permessi
// ═══════════════════════════════════════════════════════════════════════

final permissionServiceProvider = Provider<PermissionService>(
  (_) => PermissionServiceImpl(),
  name: 'permissionServiceProvider',
);

final permissionsStateProvider = FutureProvider<PermissionsState>(
  (ref) => ref.watch(permissionServiceProvider).checkAllPermissions(),
  name: 'permissionsStateProvider',
);

// ═══════════════════════════════════════════════════════════════════════
// AUDIO ENGINE — Repository + Notifier
// ═══════════════════════════════════════════════════════════════════════

final audioCaptureRepositoryProvider = Provider<AudioCaptureRepository>(
  (_) => AudioCaptureRepositoryImpl(),
  name: 'audioCaptureRepositoryProvider',
);

final audioNotifierProvider =
    AsyncNotifierProvider<AudioNotifier, AudioState>(
  AudioNotifier.new,
  name: 'audioNotifierProvider',
);

// ═══════════════════════════════════════════════════════════════════════
// OVERLAY UI — Notifier
// ═══════════════════════════════════════════════════════════════════════

final overlayNotifierProvider =
    NotifierProvider<OverlayNotifier, OverlayState>(
  OverlayNotifier.new,
  name: 'overlayNotifierProvider',
);

// ═══════════════════════════════════════════════════════════════════════
// SHADER ENGINE — Repository + Notifier
// ═══════════════════════════════════════════════════════════════════════

/// Singleton del repository shader — warm-up eseguito una sola volta.
final shaderRepositoryProvider = Provider<ShaderRepositoryImpl>(
  (_) => ShaderRepositoryImpl(),
  name: 'shaderRepositoryProvider',
);

/// Controller shader con Ticker 60fps + gestione uniforms.
final shaderNotifierProvider =
    AsyncNotifierProvider<ShaderNotifier, ShaderState>(
  ShaderNotifier.new,
  name: 'shaderNotifierProvider',
);

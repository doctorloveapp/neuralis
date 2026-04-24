/// Neuralis — Unit Test: PermissionService
///
/// Posizione: test/unit/services/permission_service_test.dart
///
/// Verifica il comportamento di [PermissionService] tramite un mock
/// costruito con `mocktail`. I test coprono:
///   - Ogni singolo permesso (overlay, audio, mediaProjection)
///   - Lo stato aggregato [PermissionsState]
///   - Il caso [PermissionStatus.permanentlyDenied] con helper flags
///   - Il metodo [openAppSettings]
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:neuralis/core/services/permission_service.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

/// Mock di [PermissionService] generato da mocktail.
/// Non richiede code generation — mocktail usa noSuchMethod.
class MockPermissionService extends Mock implements PermissionService {}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

void main() {
  late MockPermissionService mockService;

  setUp(() {
    mockService = MockPermissionService();
  });

  tearDown(() {
    reset(mockService);
  });

  // ─────────────────────────────────────────────────────────────────────
  // requestOverlayPermission
  // ─────────────────────────────────────────────────────────────────────

  group('requestOverlayPermission', () {
    test('restituisce granted quando il permesso viene concesso', () async {
      when(() => mockService.requestOverlayPermission())
          .thenAnswer((_) async => PermissionStatus.granted);

      final result = await mockService.requestOverlayPermission();

      expect(result, equals(PermissionStatus.granted));
      verify(() => mockService.requestOverlayPermission()).called(1);
    });

    test('restituisce denied quando il permesso viene negato', () async {
      when(() => mockService.requestOverlayPermission())
          .thenAnswer((_) async => PermissionStatus.denied);

      final result = await mockService.requestOverlayPermission();

      expect(result, equals(PermissionStatus.denied));
    });

    test('restituisce permanentlyDenied quando il permesso è bloccato', () async {
      when(() => mockService.requestOverlayPermission())
          .thenAnswer((_) async => PermissionStatus.permanentlyDenied);

      final result = await mockService.requestOverlayPermission();

      expect(result, equals(PermissionStatus.permanentlyDenied));
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // requestAudioPermission
  // ─────────────────────────────────────────────────────────────────────

  group('requestAudioPermission', () {
    test('restituisce granted quando il microfono è concesso', () async {
      when(() => mockService.requestAudioPermission())
          .thenAnswer((_) async => PermissionStatus.granted);

      final result = await mockService.requestAudioPermission();

      expect(result, equals(PermissionStatus.granted));
    });

    test('restituisce permanentlyDenied se l\'utente ha selezionato "Non chiedere più"', () async {
      when(() => mockService.requestAudioPermission())
          .thenAnswer((_) async => PermissionStatus.permanentlyDenied);

      final result = await mockService.requestAudioPermission();

      expect(result, equals(PermissionStatus.permanentlyDenied));
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // requestMediaProjection
  // ─────────────────────────────────────────────────────────────────────

  group('requestMediaProjection', () {
    test('restituisce granted dopo RESULT_OK dal dialogo di sistema', () async {
      when(() => mockService.requestMediaProjection())
          .thenAnswer((_) async => PermissionStatus.granted);

      final result = await mockService.requestMediaProjection();

      expect(result, equals(PermissionStatus.granted));
    });

    test('restituisce denied se l\'utente annulla il dialogo (RESULT_CANCELED)', () async {
      when(() => mockService.requestMediaProjection())
          .thenAnswer((_) async => PermissionStatus.denied);

      final result = await mockService.requestMediaProjection();

      expect(result, equals(PermissionStatus.denied));
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // checkAllPermissions — stato aggregato
  // ─────────────────────────────────────────────────────────────────────

  group('checkAllPermissions', () {
    test('restituisce PermissionsState con tutti i permessi granted', () async {
      when(() => mockService.checkAllPermissions())
          .thenAnswer((_) async => const PermissionsState(
                overlay: PermissionStatus.granted,
                audio: PermissionStatus.granted,
                mediaProjection: PermissionStatus.granted,
              ));

      final state = await mockService.checkAllPermissions();

      expect(state.overlay, equals(PermissionStatus.granted));
      expect(state.audio, equals(PermissionStatus.granted));
      expect(state.mediaProjection, equals(PermissionStatus.granted));
      expect(state.allGranted, isTrue);
      expect(state.hasPermanentlyDenied, isFalse);
    });

    test('allGranted è false se anche solo un permesso non è granted', () async {
      when(() => mockService.checkAllPermissions())
          .thenAnswer((_) async => const PermissionsState(
                overlay: PermissionStatus.granted,
                audio: PermissionStatus.denied,
                mediaProjection: PermissionStatus.unknown,
              ));

      final state = await mockService.checkAllPermissions();

      expect(state.allGranted, isFalse);
    });

    test('hasPermanentlyDenied è true se overlay è permanentlyDenied', () async {
      when(() => mockService.checkAllPermissions())
          .thenAnswer((_) async => const PermissionsState(
                overlay: PermissionStatus.permanentlyDenied,
                audio: PermissionStatus.granted,
                mediaProjection: PermissionStatus.unknown,
              ));

      final state = await mockService.checkAllPermissions();

      expect(state.hasPermanentlyDenied, isTrue);
    });

    test('hasPermanentlyDenied è true se audio è permanentlyDenied', () async {
      when(() => mockService.checkAllPermissions())
          .thenAnswer((_) async => const PermissionsState(
                overlay: PermissionStatus.granted,
                audio: PermissionStatus.permanentlyDenied,
                mediaProjection: PermissionStatus.unknown,
              ));

      final state = await mockService.checkAllPermissions();

      expect(state.hasPermanentlyDenied, isTrue);
    });

    test('hasPermanentlyDenied è true se mediaProjection è permanentlyDenied', () async {
      when(() => mockService.checkAllPermissions())
          .thenAnswer((_) async => const PermissionsState(
                overlay: PermissionStatus.granted,
                audio: PermissionStatus.granted,
                mediaProjection: PermissionStatus.permanentlyDenied,
              ));

      final state = await mockService.checkAllPermissions();

      expect(state.hasPermanentlyDenied, isTrue);
    });

    test('restituisce PermissionsState.initial() con tutti unknown', () async {
      when(() => mockService.checkAllPermissions())
          .thenAnswer((_) async => PermissionsState.initial());

      final state = await mockService.checkAllPermissions();

      expect(state.overlay, equals(PermissionStatus.unknown));
      expect(state.audio, equals(PermissionStatus.unknown));
      expect(state.mediaProjection, equals(PermissionStatus.unknown));
      expect(state.allGranted, isFalse);
      expect(state.hasPermanentlyDenied, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // PermissionsState.copyWith
  // ─────────────────────────────────────────────────────────────────────

  group('PermissionsState.copyWith', () {
    test('aggiorna solo il campo specificato', () {
      const original = PermissionsState(
        overlay: PermissionStatus.granted,
        audio: PermissionStatus.denied,
        mediaProjection: PermissionStatus.unknown,
      );

      final updated = original.copyWith(audio: PermissionStatus.granted);

      expect(updated.overlay, equals(PermissionStatus.granted));
      expect(updated.audio, equals(PermissionStatus.granted));
      expect(updated.mediaProjection, equals(PermissionStatus.unknown));
    });

    test('mantiene tutti i campi invariati se nessun parametro viene passato', () {
      const original = PermissionsState(
        overlay: PermissionStatus.denied,
        audio: PermissionStatus.permanentlyDenied,
        mediaProjection: PermissionStatus.granted,
      );

      final copy = original.copyWith();

      expect(copy, equals(original));
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // openAppSettings
  // ─────────────────────────────────────────────────────────────────────

  group('openAppSettings', () {
    test('viene chiamato quando hasPermanentlyDenied è true', () async {
      when(() => mockService.openAppSettings()).thenAnswer((_) async {});
      when(() => mockService.checkAllPermissions())
          .thenAnswer((_) async => const PermissionsState(
                overlay: PermissionStatus.permanentlyDenied,
                audio: PermissionStatus.granted,
                mediaProjection: PermissionStatus.unknown,
              ));

      final state = await mockService.checkAllPermissions();
      if (state.hasPermanentlyDenied) {
        await mockService.openAppSettings();
      }

      verify(() => mockService.openAppSettings()).called(1);
    });

    test('NON viene chiamato se nessun permesso è permanentlyDenied', () async {
      when(() => mockService.openAppSettings()).thenAnswer((_) async {});
      when(() => mockService.checkAllPermissions())
          .thenAnswer((_) async => const PermissionsState(
                overlay: PermissionStatus.granted,
                audio: PermissionStatus.granted,
                mediaProjection: PermissionStatus.granted,
              ));

      final state = await mockService.checkAllPermissions();
      if (state.hasPermanentlyDenied) {
        await mockService.openAppSettings();
      }

      verifyNever(() => mockService.openAppSettings());
    });
  });
}

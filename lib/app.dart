/// Neuralis — Root MaterialApp con splash, i18n, tema LCARS e flusso permessi.
///
/// Posizione: lib/app.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/providers.dart';
import 'core/services/permission_service.dart';
import 'features/audio_engine/domain/entities/audio_entity.dart';
import 'features/overlay_ui/presentation/screens/overlay_dashboard.dart';
import 'l10n/app_localizations.dart';
import 'shared/theme/lcars_colors.dart';
import 'shared/theme/lcars_theme.dart';
import 'shared/theme/lcars_typography.dart';

// ---------------------------------------------------------------------------
// NeuralisApp
// ---------------------------------------------------------------------------

class NeuralisApp extends ConsumerWidget {
  const NeuralisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Neuralis',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales:        AppLocalizations.supportedLocales,
      theme:                   LcarsTheme.dark,
      home:                    const _SplashScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// _SplashScreen — Logo + bootstrap permessi + transizione Dashboard
// ---------------------------------------------------------------------------

class _SplashScreen extends ConsumerStatefulWidget {
  const _SplashScreen();

  @override
  ConsumerState<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<_SplashScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  // ── Animazione logo ────────────────────────────────────────────────────────
  late final AnimationController _logoAnim;
  late final Animation<double>    _fadeIn;

  // ── Stato bootstrap ────────────────────────────────────────────────────────
  String _statusLine   = 'BOOTING NEURALIS OS...';
  bool   _permGranted  = false;
  bool   _permDenied   = false;
  bool   _waitingForOverlay = false; // true mentre siamo nelle impostazioni Android

  static const _permChannel = MethodChannel('neuralis/permissions');

  // ──────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _logoAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(parent: _logoAnim, curve: Curves.easeInOut);
    _logoAnim.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _logoAnim.dispose();
    super.dispose();
  }

  /// Intercetta il ritorno dell'utente dalle impostazioni di sistema.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForOverlay) {
      _waitingForOverlay = false;
      // L'utente è tornato — controlla se il permesso è stato concesso
      _checkOverlayAndContinue();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Bootstrap
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(milliseconds: 900));
    await _requestOverlay();
  }

  // ── Fase 1: Overlay ────────────────────────────────────────────────────────

  Future<void> _requestOverlay() async {
    _setStatus('CHECKING OVERLAY PERMISSION...');

    // Prima controlla se è già concesso
    final alreadyGranted =
        await _permChannel.invokeMethod<bool>('checkOverlay') ?? false;

    if (alreadyGranted) {
      await _continueWithAudio();
      return;
    }

    // Apre le impostazioni Android → l'app va in background
    _setStatus('GRANT OVERLAY PERMISSION IN SETTINGS...');
    _waitingForOverlay = true;
    await _permChannel.invokeMethod<void>('requestOverlay');
    // ⚠️ Il controllo riprende in didChangeAppLifecycleState → resumed
  }

  Future<void> _checkOverlayAndContinue() async {
    _setStatus('VERIFYING OVERLAY PERMISSION...');
    final granted =
        await _permChannel.invokeMethod<bool>('checkOverlay') ?? false;

    if (!granted) {
      _setStatus('OVERLAY PERMISSION REQUIRED — TAP TO RETRY');
      setState(() => _permDenied = true);
      return;
    }
    await _continueWithAudio();
  }

  // ── Fase 2: Audio (microfono) ──────────────────────────────────────────────

  Future<void> _continueWithAudio() async {
    _setStatus('REQUESTING AUDIO PERMISSION...');
    if (mounted) setState(() => _permDenied = false);

    try {
      final service = ref.read(permissionServiceProvider);
      final result  = await service.requestAudioPermission();
      if (result == PermissionStatus.permanentlyDenied) {
        _setStatus('AUDIO PERMISSION PERMANENTLY DENIED');
        setState(() => _permDenied = true);
        return;
      }
    } catch (e) {
      debugPrint('[Splash] audio permission error: $e');
      // Non bloccare su errore mic: mostriamo la dashboard lo stesso
    }

    // ── Fase 3: Shader warm-up ────────────────────────────────────────────────
    _setStatus('LOADING NEURAL SHADER...');
    try {
      await ref.read(shaderNotifierProvider.notifier)
          .initialize(ref.read(shaderRepositoryProvider));
    } catch (e) {
      debugPrint('[Splash] shader init error: $e');
      // Non bloccante: la Dashboard mostra il placeholder di errore
    }

    // ── Fase 4: Avvia cattura audio ───────────────────────────────────────────
    _setStatus('ACTIVATING AUDIO SENSORS...');
    try {
      await ref.read(audioNotifierProvider.notifier)
          .startCapture(AudioCaptureMode.external);
    } catch (e) {
      debugPrint('[Splash] audio start error: $e');
      // Non bloccante: l'utente può usare INT/EXT dalla Dashboard
    }

    // ── Tutte le fasi OK ─────────────────────────────────────────────────────
    _setStatus('ALL SYSTEMS ONLINE — LOADING NEURAL INTERFACE...');
    setState(() => _permGranted = true);
    await Future.delayed(const Duration(milliseconds: 500));
    await _navigateToDashboard();
  }

  Future<void> _navigateToDashboard() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const OverlayDashboard(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _statusLine = msg);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Retry (tap sul messaggio di errore)
  // ──────────────────────────────────────────────────────────────────────────

  void _onRetryTap() {
    setState(() {
      _permDenied = false;
      _permGranted = false;
    });
    _requestOverlay();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // UI
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LcarsColors.overlayBg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            children: [
              // ── Logo centrale ────────────────────────────────────────────
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo con bordo LCARS atomic
                      Container(
                        width:  160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: LcarsColors.atomic,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: LcarsColors.withAlpha(LcarsColors.atomic, 0.25),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo_neuralis.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Nome sistema
                      Text(
                        'NEURALIS',
                        style: LcarsTypography.displayLarge.copyWith(
                          letterSpacing: 12,
                          color: LcarsColors.atomic,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'NEURAL LCARS OVERLAY SYSTEM',
                        style: LcarsTypography.labelSmall.copyWith(
                          color: LcarsColors.blueGray,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Footer ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 44),
                child: Column(
                  children: [
                    // Status (cliccabile in caso di errore per retry)
                    GestureDetector(
                      onTap: _permDenied ? _onRetryTap : null,
                      child: Text(
                        _statusLine + (_permDenied ? '\n[TAP TO RETRY]' : ''),
                        style: LcarsTypography.caption.copyWith(
                          color: _permDenied
                              ? LcarsColors.warning
                              : (_permGranted ? LcarsColors.atomic : LcarsColors.tan),
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Indicatore
                    if (!_permGranted && !_permDenied)
                      _LcarsProgressBar()
                    else if (_permDenied)
                      Icon(Icons.warning_amber_rounded,
                          color: LcarsColors.warning, size: 28)
                    else
                      Icon(Icons.check_circle_outline,
                          color: LcarsColors.atomic, size: 28),

                    const SizedBox(height: 20),

                    // Barra decorativa LCARS
                    Row(
                      children: [
                        Container(width: 40, height: 6, color: LcarsColors.atomic),
                        const SizedBox(width: 4),
                        Container(width: 8,  height: 6, color: LcarsColors.tan),
                        const SizedBox(width: 4),
                        Expanded(child: Container(height: 2,
                            color: LcarsColors.withAlpha(LcarsColors.blueGray, 0.35))),
                        const SizedBox(width: 4),
                        Container(width: 8,  height: 6, color: LcarsColors.purple),
                        const SizedBox(width: 4),
                        Container(width: 24, height: 6, color: LcarsColors.blueGray),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LcarsProgressBar
// ---------------------------------------------------------------------------

class _LcarsProgressBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      backgroundColor: LcarsColors.withAlpha(LcarsColors.blueGray, 0.2),
      valueColor:      AlwaysStoppedAnimation<Color>(LcarsColors.atomic),
      minHeight:       4,
    );
  }
}

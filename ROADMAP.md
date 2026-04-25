# 🛸 NEURALIS — ROADMAP

### Neural LCARS Overlay System — Enterprise Edition V.1.3

> Documento di tracking dello sviluppo. Ogni voce viene marcata `[x]` al completamento.
> **Regola:** Non procedere alla sezione successiva senza aver consolidato e testato l'attuale.

---

## 🏛 SEZIONE 0: DECISIONI ARCHITETTURALI (PRE-SVILUPPO)

**Obiettivo:** Fissare tutte le scelte tecnologiche prima di scrivere codice.

### Decisioni Vincolanti Confermate

| Categoria | Scelta | Motivazione |
|---|---|---|
| State Management | Riverpod 3.x (Notifier / AsyncNotifier) | Reattività, DI integrata, testabilità, API moderna |
| Dependency Injection | Riverpod Providers | Nessun container esterno aggiuntivo |
| Code Generation | Manuale (no riverpod_generator) | riverpod_generator 4.x incompatibile con Flutter SDK 3.38.5 (conflitto analyzer) — boilerplate Notifier minimo |
| Audio Capture | MethodChannel + EventChannel nativo custom | Controllo totale, zero dipendenze fragili |
| Overlay | MethodChannel nativo custom (WindowManager Kotlin) | Compatibilità garantita SDK 33+ |
| Font | Google Fonts — 'Antonio' | Identità visiva LCARS |
| Shader Loading | `FragmentProgram.fromAsset()` con warm-up esplicito | Previene jank al primo frame |
| Testing | `flutter_test` + `mocktail` | Copertura Use Cases e Service layer |
| Kotlin Async | Kotlin Coroutines | Gestione thread audio non-blocking |
| i18n | `flutter_localizations` + `intl` + ARB files | EN + IT, zero stringhe hardcoded |
| Package Name | `com.neuralis.app` | Identificativo Android |

### Task

- [x] Creare `ROADMAP.md` completo
- [x] Creare `docs/ARCHITECTURE.md` con tabella decisioni e struttura cartelle
- [x] Definire tutte le interfacce astratte (`abstract class`) dei Service prima di qualsiasi implementazione
- [x] Configurare struttura cartelle Clean Architecture
- [x] Configurare i18n (`l10n.yaml`, `app_en.arb`, `app_it.arb`)

---

## 🛠 SEZIONE 1: INFRASTRUTTURA, OVERLAY E PERMESSI

**Obiettivo:** Setup del Core e gestione corretta di tutti i permessi Android 13+.

### Permessi Android

- `SYSTEM_ALERT_WINDOW` — overlay di sistema
- `RECORD_AUDIO` — cattura microfono
- `FOREGROUND_SERVICE` — servizio in primo piano
- `FOREGROUND_SERVICE_MEDIA_PROJECTION` — cattura audio interno

### Foreground Service

- Canale notifica: `neuralis_overlay_channel` / "Neuralis System"
- Notifica: "Neuralis — System Active", IMPORTANCE_LOW
- Tipo servizio: `FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION`

### MediaProjection Flow (7 passi obbligatori)

1. UI Flutter → "Avvia Cattura Interna"
2. MethodChannel → Kotlin → `MediaProjectionManager.createScreenCaptureIntent()`
3. Dialogo di sistema mostrato
4. `onActivityResult()` → RESULT_CANCELED (errore) o RESULT_OK (prosegui)
5. Avvia `NeuralisForegroundService` con MediaProjectionData
6. `AudioRecord` + `AudioPlaybackCaptureConfiguration`
7. Emetti `INTERNAL_AUDIO_READY` via EventChannel

### Task

- [x] `AndroidManifest.xml` con tutti i permessi
- [x] `NeuralisForegroundService.kt` con notifica persistente (canale + titolo + tipo)
- [x] `MediaProjectionHandler.kt` con flow completo in 7 passi
- [x] `OverlayManager.kt` con WindowManager
- [x] `PermissionService` abstract class + implementazione concreta
- [x] MediaProjection flow con gestione `RESULT_CANCELED`
- [ ] Navigazione App ↔ Overlay (HomeScreen completa — Sezione 3)
- [x] Stringhe i18n per UI permessi (`app_en.arb` + `app_it.arb`)
- [x] Unit test: `PermissionService` mockato con `mocktail` — 17/17 test passati ✅
- [x] Riverpod provider: `permissionServiceProvider` + `permissionsStateProvider`
- [x] `lib/app.dart` + refactor `lib/main.dart` con ProviderScope
- [x] **SplashScreen LCARS** (`lib/app.dart` → `_SplashScreen`):
  - Logo `assets/images/logo_neuralis.png` con alone `atomic` e `BoxShadow`
  - Progress bar `LinearProgressIndicator` stile LCARS
  - Barra decorativa orizzontale LCARS (atomic + tan + blueGray + purple)
  - Testo status aggiornato in tempo reale durante il bootstrap
  - Tap su errore → retry automatico
- [x] **Flusso permessi al boot** (WidgetsBindingObserver pattern):
  - `checkOverlay` → se non concesso apre `ACTION_MANAGE_OVERLAY_PERMISSION`
  - `didChangeAppLifecycleState(resumed)` → riprende flusso al ritorno dall'impostazioni
  - `requestAudioPermission()` via `permissionServiceProvider`
  - Navigazione con `FadeTransition` (600ms) verso `OverlayDashboard`
- [x] Permessi già concessi → nessuna dialog inutile (comportamento corretto Android)

---

## 🔊 SEZIONE 2: ENGINE AUDIO & GESTIONE DRM (FALLBACK LOGIC)

**Obiettivo:** Estrazione FFT avanzata con resilienza ai blocchi DRM delle piattaforme streaming.

### Implementazione Nativa

- `MethodChannel("neuralis/audio")` → comandi (start, stop, setMode)
- `EventChannel("neuralis/audio_stream")` → stream continuo dati FFT

### Tre Modalità di Cattura

| Modalità | Sorgente | Descrizione |
|---|---|---|
| `Internal` | `AudioPlaybackCapture` via `MediaProjection` | Audio di sistema |
| `External` | `AudioRecord` via `MIC` | Microfono ambientale |
| `Hybrid` | Entrambi in parallelo | Somma pesata dei due segnali |

### FFT Pipeline

1. Hanning Window sul buffer grezzo
2. FFT (1024 campioni)
3. Magnitudine per ogni bin: `sqrt(re² + im²)`
4. Raggruppamento in 32 bande logaritmiche
5. Normalizzazione `[0.0, 1.0]` rispetto al picco storico
6. Invio `float[32]` via EventChannel

### Logica Anti-DRM

- Monitoraggio RMS continuo in modalità Internal / Hybrid
- `rms_media` su finestra mobile di 3 secondi
- Se `rms_media < SOGLIA_SILENZIO (0.001)` per > 3s → failover a Mic
- Emissione `DrmBlockedEvent` → `LcarsWarningBanner`

### Task

- [x] `NativeAudioCapture.kt` — AudioRecord 3 modalità, Hanning Window, FFT Cooley-Tukey, 32 bande log
- [x] Logica Anti-DRM: calcolo RMS, finestra 3 secondi, failover automatico a EXTERNAL
- [x] EventChannel(`neuralis/audio_stream`) per FFT + eventi DRM
- [x] `AudioCaptureRepositoryImpl` — bridge MethodChannel/EventChannel → domain types
- [x] `AudioState` — stato immutabile (mode, currentFFT, isCapturing, isDrmBlocked)
- [x] `AudioNotifier` — AsyncNotifier Riverpod 3.x con stream FFT + DRM
- [x] Provider: `audioCaptureRepositoryProvider` + `audioNotifierProvider`
- [ ] Unit test AudioNotifier (mock repository) — Sezione 2 extra
- [ ] `NativeAudioCapture` integration test su device fisico
- [ ] Warning UI LCARS al failover (stringa i18n)
- [ ] `AudioCaptureRepository` (abstract) + implementazione concreta
- [ ] Entity: `AudioEntity`, `FFTData`
- [ ] Use Cases: `StartCaptureUseCase`, `StopCaptureUseCase`, `SetModeUseCase`
- [ ] Riverpod provider: `audioCaptureProvider` (AsyncNotifier)
- [ ] Unit test: mock EventChannel, test trigger RMS sotto soglia, test switch modalità

---

## 🎨 SEZIONE 3: NEURALIS LCARS DESIGN SYSTEM

**Obiettivo:** Framework UI modulare e riutilizzabile — identità visiva Neuralis.

### Palette Colori

| Nome | Hex | Uso |
|---|---|---|
| `atomic` | `#FF9900` | Primario, alert, picchi frequenza |
| `tan` | `#FFCC66` | Secondario, highlight |
| `purple` | `#CC99CC` | Accento, info |
| `blueGray` | `#9999CC` | UI neutro, wireframe base |
| `darkBg` | `#000000` | Sfondo overlay |
| `panelBg` | `#0A0A1A` | Sfondo pannello |

### Typography

- Font: **Antonio** via `google_fonts`
- Stile: uppercase, letter-spacing `2.0–4.0`, weight variabile

### Widget Modulari

| Widget | Tipo | Descrizione |
|---|---|---|
| `LcarsElbow` | `CustomPainter` | Angolo a L, 4 orientamenti |
| `LcarsButton` | `StatefulWidget` | Bordo sinistro, label Antonio, animazione stato |
| `LcarsPanel` | `Widget` | Header colorato + body scuro semitrasparente |
| `LcarsStatusBar` | `Widget` | Label + valore + indicatore OK/WARNING/ERROR |
| `LcarsWarningBanner` | `AnimatedWidget` | Banner lampeggiante per eventi critici |

### Task

- [x] `LcarsColors` — palette: Atomic #FF9900, Tan #FFCC66, Purple #CC99CC, BlueGray #9999CC
- [x] `LcarsTypography` — scale completa Antonio: displayLarge → caption
- [x] `LcarsTheme` — ThemeData globale dark + colorScheme + textTheme Antonio
- [x] `LcarsElbow` — CustomPainter, 4 orientamenti, spessori variabili, arco esterno
- [x] `LcarsButton` — un angolo arrotondato (left), HapticFeedback.lightImpact, isActive toggle
- [x] `LcarsStatusBar` — brand + separatore + modalità audio + indicatore Online/Warning
- [x] `LcarsWarningBanner` — FadeTransition 1Hz, tan color, stringa i18n drmWarningBanner
- [x] `OverlayState` — stato immutabile (isVisible, opacity, isLocked)
- [x] `OverlayNotifier` — Riverpod Notifier + MethodChannel('neuralis/overlay')
- [x] `OverlayDashboard` — layout asimmetrico LCARS: StatusBar, Elbows, Wavefront placeholder, BassPad/NavPad
- [x] **Fix `OverlayDashboard`** (sessione 2026-04-24):
  - `SafeArea` wrapper → rispetta status bar e navigation bar Android
  - `SizedBox.expand()` → vincoli tight per Material, elimina overflow non vincolato
  - `_ModeSwitcher` → `AudioCaptureMode` direct enum comparison (fix `NoSuchMethodError: .name`)
  - `IntrinsicWidth` + `mainAxisSize.min` → Column nel Row senza overflow
  - Import esplicito `AudioCaptureMode` da `audio_entity.dart`
  - Rimosso metodo `_audioMode()` obsoleto (passava `int` invece di enum)
- [x] `overlayNotifierProvider` aggiunto a `providers.dart`
- [x] `context.l10n` extension in `lib/l10n/l10n_extension.dart`
- [x] ARB EN+IT: statusOnline, statusWarning, padBass, padNav
- [x] `app.dart` aggiornato con `LcarsTheme.dark` + `LcarsTypography` DRM
- [x] Tutte le stringhe widget via i18n (`context.l10n`)
- [x] Widget test per ogni componente

---

## 🌌 SEZIONE 4: NEURAL WAVEFRONT ENGINE (SHADERS GLSL)

**Obiettivo:** Rendering GLSL ad alte prestazioni, audio-reattivo.

### Shader Warm-Up (CRITICO)

- `ShaderRepository.init()` durante splash screen
- `FragmentProgram.fromAsset('assets/shaders/wavefront.frag')`
- Mai on-demand, mai al primo frame di rendering

### `wavefront.frag` — Requisiti

1. **Mesh wireframe 3D procedurale** — Griglia NxN (N=16) proiettata in 2D con prospettiva
2. **Vertex displacement audio-reattivo** sull'asse Y:
   - Bande 0–7 (basse) → righe centrali
   - Bande 8–15 → zona intermedia
   - Bande 16–23 → zona esterna
   - Bande 24–31 (alte) → bordi estremi
3. **Rotazione 3D animata** — asse Y, ~0.3 rad/s, effetto floating
4. **Aberrazione cromatica dinamica** — attiva quando `length(uBending) > 0.1`
5. **Palette colori** — blueGray base → atomic sui picchi, sfondo trasparente

### Uniforms (aggiornati ogni frame)

| Uniform | Tipo | Range |
|---|---|---|
| `uTime` | `float` | secondi dall'avvio |
| `uResolution` | `vec2` | pixel canvas |
| `uAudioFrequency` | `float[32]` | `[0.0, 1.0]` per banda |
| `uBending` | `vec2` | `[-1.0, 1.0]` |

### Task

- [x] `ShaderRepository` con warm-up in fase init (non on-demand)
- [x] `wavefront.frag` completo: mesh wireframe 3D, displacement FFT 32 bande, aberrazione cromatica RGB
- [x] Uniforms aggiornati ogni frame via `ShaderRepositoryImpl.updateUniforms()`
- [x] Transizione colore blueGray → atomic sui picchi FFT (GLSL `mix()`)
- [x] `pubspec.yaml`: shader registrato in `flutter.shaders`
- [x] `ShaderState` + `ShaderNotifier` — AsyncNotifier con Ticker 60fps
- [x] `WavefrontPainter` — CustomPainter zero-allocazioni per frame
- [x] `WavefrontWidget` — 3 stati: loading, error (i18n), live shader
- [x] `shaderRepositoryProvider` + `shaderNotifierProvider` in `providers.dart`
- [x] ARB EN+IT: `shaderLoadFailed` ("SENSOR CALIBRATION FAILED")
- [x] `WavefrontWidget` integrato in `OverlayDashboard` (area centrale espansa)

---

## 🕹️ SEZIONE 5: BUSINESS LOGIC DEI PAD & INTERAZIONE

**Obiettivo:** Interazione tattile mappata sui parametri shader, isolata e testabile.

### InteractionController (Dominio Puro)

```
InteractionState:
  bassGain  : double [0.5, 3.0] — default 1.0
  bending   : Offset [-1.0, 1.0] — default Offset.zero
```

### BassPad

- Moltiplicatore gain sulle bande FFT 0–7
- Range: `0.5` (attenuazione) → `3.0` (boost massimo)
- Pressione continua → curva esponenziale verso 3.0
- Rilascio → ritorno a `1.0` in 300ms con ease-out
- Feedback visivo: blueGray → atomic proporzionale al gain

### NavPad (Bending)

- Swipe 2D → `uBending` (vec2) → aberrazione cromatica
- Soglia: `length(uBending) > 0.1`
- Rilascio → ritorno a `(0, 0)` in 500ms con ease-out
- `GestureDetector.onPanUpdate` con normalizzazione delta

### Task

- [x] `InteractionController` con `InteractionState` — zero dipendenze UI
  - `lib/features/interaction/presentation/interaction_controller.dart`
  - Ticker frame-accurate (SchedulerBinding) per ease-out fluido
  - `bassGain` [1.0, 3.0]: salita esponenziale (4.5x/s), discesa ease-out (300ms)
  - `bending` (X+Y) [-1.0, 1.0]: ease-out verso zero in ~450ms
  - `HapticFeedback.lightImpact()` su press/release, `selectionClick()` su swipe
- [x] `BassPad` widget con curva esponenziale gain e ease-out (300ms)
  - `onLongPressStart`/`onLongPressEnd` + `onTapDown`/`onTapUp` per burst brevi
  - Colore: `blueGray → atomic` via `Color.lerp` proporzionale al gain
  - `Consumer` + `ref.select(s.bassGain)` → rebuild selettivo (no full Dashboard)
- [x] `NavPad` widget con GestureDetector, normalizzazione delta, ease-out (450ms)
  - `onPanUpdate`: `delta.dx / padWidth`, `delta.dy / padHeight` → clampa [-1.0, 1.0]
  - Feedback visivo: bordo/sfondo `blueGray → purple` quando `isBending == true`
  - `Consumer` + `ref.select(s.isBending)` → rebuild selettivo
- [x] Riverpod provider: `interactionControllerProvider` in `providers.dart`
- [x] Routing FFT → Shader: `AudioNotifier._routeToShader()` applica bassGain alle bande 0–7
- [x] Shader warm-up al boot: `app.dart` `_continueWithAudio()` → `ShaderNotifier.initialize()`
- [x] Audio start al boot: `app.dart` → `AudioNotifier.startCapture(AudioCaptureMode.external)`
- [x] Routing bending → Shader: `InteractionController._onTick()` → `ShaderNotifier.updateBending()`
- [ ] Unit test:
  - [ ] Mapping swipe → bending normalizzato
  - [ ] Gain range `[0.5, 3.0]` non superabile
  - [ ] Ritorno a zero dopo rilascio
  - [ ] Soglia aberrazione `length > 0.1`

---

## 🚀 SEZIONE 6: OTTIMIZZAZIONE, LIFECYCLE E BUILD

**Obiettivo:** Stabilità enterprise, zero memory leak, predisposizione espansioni.

### Lifecycle Management (Ordine Dispose Obbligatorio)

```
1. interactionController.dispose()     → ferma animazioni pad
2. shaderRepository.dispose()          → rilascia FragmentShader
3. audioCaptureService.stop()          → chiude AudioRecord nativo
4. overlayService.hide()               → rimuove View da WindowManager
5. NeuralisForegroundService.stopSelf() → termina il service Android
```

### Gestione Stati Lifecycle

| Stato | Azione |
|---|---|
| `paused` | Pausa audio capture, shader in idle |
| `resumed` | Riprende audio capture, shader attivo |
| `detached` | Dispose chain completa |

### Dipendenze Approvate (Finale)

```
flutter_riverpod: ^3.3.1
google_fonts: ^8.0.2
permission_handler: ^12.0.1
flutter_localizations (sdk)
intl
---
mocktail: ^1.0.4 (dev)
# riverpod_generator/build_runner/riverpod_lint rimossi per conflitto analyzer
```

> ⛔ VIETATO: `flutter_audio_visualizer`, `system_alert_window`, qualsiasi pacchetto nativo non elencato.

### Predisposizione Future

- `MetadataRepository` abstract (Spotify / Last.fm)
- Tutti i punti di estensione marcati `// TODO(future):`

### Task

- [ ] `AppLifecycleObserver` con tutti e 3 gli stati lifecycle
- [ ] Dispose chain completa e ordinata
- [x] `pubspec.yaml` finalizzato e verificato (`flutter pub get` OK)
- [x] **`flutter_launcher_icons: ^0.14.1`** configurato e lanciato:
  - `image_path: assets/images/logo_neuralis.png`
  - `adaptive_icon_background: "#000000"`
  - Generati tutti i mipmap Android (mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi)
  - `dart run flutter_launcher_icons` eseguito con successo ✅
- [x] App icon launcher = logo Neuralis (non più Flutter default)
- [ ] `MetadataRepository` abstract class predisposta
- [ ] Test di integrazione: ciclo completo init → overlay → paused → resumed → dispose

---

## 🔧 NOTE BUILD & DEPLOY (WINDOWS)

> Problemi ricorrenti su Windows e soluzioni documentate.

### Dipendenze Native — Conflitto path con spazi

`pubspec.yaml` → `dependency_overrides` OBBLIGATORI se il progetto è in un path con spazi:

```yaml
dependency_overrides:
  objective_c: 6.0.0          # Bug Dart SDK su path Windows con spazi
  path_provider_foundation: 2.3.2  # Compatibile con objective_c ≤ 6.x
```

### Kotlin Native — Dipendenze `build.gradle.kts`

```kotlin
// Obbligatorie per registerForActivityResult e Coroutines
implementation("androidx.activity:activity-ktx:1.9.3")
implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
```

### MainActivity — FlutterFragmentActivity (NON FlutterActivity)

`MainActivity.kt` estende `FlutterFragmentActivity` per esporre `registerForActivityResult()`.
Cambiare in `FlutterActivity` rompe `MediaProjectionHandler`.

### File Lock `R.jar` su Windows

Errore: `Impossibile accedere al file. Il file è utilizzato da un altro processo`

**Soluzione:**
```powershell
# Ferma SOLO i daemon Gradle (non tocca ADB)
.\android\gradlew --stop
flutter clean
flutter run --debug
```

**⚠️ ATTENZIONE:** `taskkill /F /IM java.exe /T` uccide anche il daemon ADB.
Se già eseguito → `adb kill-server; adb start-server` per ripristinare la connessione.

### Coroutines — `isActive` ambiguo

`NativeAudioCapture.kt` usa `currentCoroutineContext().isActive` (non `isActive` diretto)
per evitare ambiguità tra `Job.isActive` e `CoroutineScope.isActive` in suspend fun.

---

## 📊 PROGRESSO GLOBALE

| Sezione | Stato | Note |
|---|---|---|
| Sezione 0 — Architettura | ✅ Completata | ROADMAP ✅, ARCHITECTURE ✅, Cartelle ✅, i18n ✅, pubspec ✅, Interfacce ✅ |
| Sezione 1 — Infrastruttura | ✅ Completata | Manifest ✅, Kotlin ✅, PermissionService ✅, SplashScreen ✅, Permessi Boot ✅ |
| Sezione 2 — Audio Engine | ✅ Completata | NativeAudioCapture ✅, FFT+RMS ✅, Repository ✅, Notifier ✅ |
| Sezione 3 — LCARS Design | ✅ Completata | Colori ✅, Tipografia ✅, Tema ✅, Elbow ✅, Button ✅, StatusBar ✅, Banner ✅, Dashboard ✅, SafeArea ✅ |
| Sezione 4 — Shader Engine | ✅ Completata | wavefront.frag v4 ✅, ShaderRepo ✅, WavefrontPainter ✅, ShaderNotifier ✅, WavefrontWidget ✅ |
| Sezione 5 — Interazione | ✅ Completata | InteractionController ✅, BassPad ✅ (gain 8.0), NavPad ✅ (sens. 3x), FFT→Shader ✅, Bending→Shader ✅ |
| Sezione 6 — Lifecycle | 🔄 In corso | App Icon ✅, Launcher Icons ✅, Lifecycle Observer ⬜ |
| Build & Deploy | ✅ Stabile | APK debug funzionante su Samsung S911B |

### 📱 Stato Device (2026-04-25) — Sprint Performance & UX

| Item | Stato |
|---|---|
| Build APK debug | ✅ Funzionante |
| Install su Samsung Galaxy S23 (SM-S911B) | ✅ Funzionante |
| Splash screen con logo Neuralis | ✅ Visibile |
| Shader GLSL wavefront (SPIR-V) | ✅ Caricato correttamente |
| Wavefront visibile a schermo | ✅ Fix: rimossa `assets/shaders/` da `flutter.assets` |
| Shader v4 — scala 1.8x | ✅ MESH_W 0.22→0.40, FOV 0.60→0.80 |
| Shader v4 — colore audio reattivo | ✅ energy×5.0 → arancione a volumi medi |
| Shader v4 — aberrazione cromatica | ✅ 2× più visibile, lineare con bendLen |
| BassPad gain | ✅ 3.0→8.0 (esplosione visiva) |
| NavPad sensibilità bending | ✅ 1.8→5.4 (3× più reattivo) |
| setBassGain routing zero-alloc | ✅ Campo `_bassGain` locale in AudioNotifier |
| ForegroundService persistenza | ✅ START_STICKY + onTaskRemoved() |
| Overlay — LAUNCH TACTICAL OVERLAY | ✅ Pulsante in OverlayDashboard con stato toggle |
| Overlay — Z-order | ✅ TYPE_APPLICATION_OVERLAY + FLAG_NOT_FOCUSABLE |
| DRM failover guard | ✅ hasDrmFailoverOccurred (max 1 failover/sessione) |
| Uniform clamping (difesa in profondità) | ✅ ShaderNotifier.updateBending + updateAudio |
| flutter analyze | ✅ 0 issues |

### 🐛 Bug Risolti (Sprint 2026-04-24/25)

| Bug | Root Cause | Fix |
|---|---|---|
| "INITIALIZING SENSORS..." infinito | `assets/shaders/` sotto `flutter.assets` sovrascriveva SPIR-V | Rimossa dalla sezione `flutter.assets` |
| Shader non compila (SPIR-V) | `uniform float arr[32]` non supportato da impellerc | Sostituito con 8 `uniform vec4` |
| Rettangolo bianco | `MESH_DEPTH (2.5) > CAM_Z (2.2)` → divisore → 0 → line_width → ∞ | CAM_DIST/MESH_D corretti, nuova camera model |
| DRM loop infinito | `triggerDrmFailover()` senza guard → rilancia infinitamente se mic occupato | Flag `hasDrmFailoverOccurred` |

---

*Neuralis — Neural LCARS Overlay System*
*Roadmap V.1.5 — Aggiornata 2026-04-25 — Sprint Performance & UX Completato*

# 🛸 Master Prompt: Project NEURALIS — Enterprise Edition V.1.2
### *Il documento Gold Standard per lo sviluppo di Neuralis*

---

## 🪪 Contesto e Identità

| Campo | Valore |
|---|---|
| **Nome Applicazione** | Neuralis |
| **Piattaforma** | Android SDK 33+ |
| **Ruolo Agente** | Senior Software Architect & Lead Flutter Developer |
| **Versione Prompt** | V.1.2 — Definitiva |

**Missione:** Progettare e sviluppare **Neuralis**, un'applicazione Android di livello enterprise che funzioni come overlay di sistema, catturi l'audio e lo visualizzi tramite una *Neural Wavefront 3D* renderizzata in GLSL, con resilienza ai blocchi DRM e interazione tattile avanzata.

---

## 💎 REGOLA D'ORO: ARCHITETTURA ENTERPRISE E SCALABILITÀ

L'applicazione deve seguire i principi della **Clean Architecture**. Deve essere modulare, testabile e scalabile.

### Separazione dei Layer
- `Data` → Repository, Native MethodChannels, EventChannels
- `Domain` → Entity, Use Cases, interfacce astratte dei Service
- `Presentation` → UI, StateNotifier, Riverpod providers

### State Management & Dependency Injection
Usa **Riverpod** (versione stabile più recente) come **unica** soluzione per stato e DI in tutto il progetto. Non introdurre BLoC, Provider, o get_it. Riverpod gestisce AudioCaptureService, OverlayService, PermissionService e InteractionController tramite provider dedicati.

### Native Channels
Tutta la comunicazione con il layer Android nativo (audio capture, overlay, MediaProjection) avviene **esclusivamente** tramite `MethodChannel` o `EventChannel` custom in Kotlin. I pacchetti pub.dev di terze parti per queste funzionalità critiche sono **vietati** — risultano non mantenuti o incompatibili con SDK 33+. I link nella sezione Riferimenti vanno usati come ispirazione logica, **non** come dipendenze.

### Modularity
Il motore shader e il motore audio devono essere isolati. Uno evolve senza toccare l'altro.

---

## 📜 ISTRUZIONI OPERATIVE E ROADMAP

Prima di scrivere una singola riga di codice, crea `ROADMAP.md` nella root. Aggiorna ogni voce con `[x]` al completamento. **Non procedere alla sezione successiva senza aver consolidato e testato l'attuale.**

---

## 🏛 SEZIONE 0: DECISIONI ARCHITETTURALI (PRE-SVILUPPO)

**Obiettivo:** Fissare tutte le scelte tecnologiche prima di scrivere codice, eliminando ogni ambiguità interpretativa per le sezioni successive.

### Decisioni Vincolanti

| Categoria | Scelta | Motivazione |
|---|---|---|
| State Management | Riverpod | Reattività, DI integrata, testabilità |
| Dependency Injection | Riverpod Providers | Nessun container esterno aggiuntivo |
| Audio Capture | MethodChannel + EventChannel nativo custom | Controllo totale, zero dipendenze fragili |
| Overlay | MethodChannel nativo custom (WindowManager Kotlin) | Compatibilità garantita SDK 33+ |
| Font | Google Fonts — 'Antonio' | Identità visiva LCARS |
| Shader Loading | `FragmentProgram.fromAsset()` con warm-up esplicito | Previene jank al primo frame |
| Testing | `flutter_test` + `mocktail` | Copertura Use Cases e Service layer |
| Kotlin Async | Kotlin Coroutines | Gestione thread audio non-blocking |

### Struttura delle Cartelle (Clean Architecture)

```
/lib
  /core
    /di              → Riverpod providers globali
    /error           → Failure, Exception, ErrorHandler
    /utils           → Costanti, estensioni, helpers
  /features
    /audio_engine
      /data          → NativeAudioCaptureService (MethodChannel + EventChannel)
      /domain        → AudioEntity, FFTData, AudioCaptureRepository (abstract), Use Cases
      /presentation  → AudioStateNotifier, audioProvider
    /overlay_ui
      /data          → NativeOverlayService (MethodChannel)
      /domain        → OverlayEntity, OverlayRepository (abstract), Use Cases
      /presentation  → OverlayStateNotifier, overlayProvider
    /shader_engine
      /data          → ShaderRepository, WavefrontLoader (warm-up)
      /domain        → ShaderParams, WavefrontUniforms
      /presentation  → ShaderStateNotifier, shaderProvider
    /interaction
      /domain        → InteractionController, BendingUseCase, BassGainUseCase
      /presentation  → PadStateNotifier, interactionProvider
  /shared
    /widgets         → LCARS Design System (Sezione 3)
    /theme           → LcarsTheme, LcarsColors, LcarsTypography
/android
  /app/src/main/kotlin
    → NativeAudioCapture.kt
    → OverlayManager.kt
    → MediaProjectionHandler.kt
    → NeuralisForegroundService.kt
/assets
  /shaders           → wavefront.frag
/test
  /unit              → Use Cases, Service mock
  /widget            → Widget test componenti LCARS
/docs
  → ARCHITECTURE.md
```

### Task Sezione 0
- [ ] Creare `ROADMAP.md` completo
- [ ] Creare `docs/ARCHITECTURE.md` con questa tabella e struttura cartelle
- [ ] Definire tutte le interfacce astratte (`abstract class`) dei Service **prima** di qualsiasi implementazione concreta
- [ ] Configurare struttura cartelle

---

## 🛠 SEZIONE 1: INFRASTRUTTURA, OVERLAY E PERMESSI

**Obiettivo:** Setup del Core e gestione corretta di tutti i permessi Android 13+.

### Permessi — `AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION"/>
```

### Foreground Service Notification ⚠️ CRITICO per Android 13+

Android 13+ termina qualsiasi Foreground Service privo di notifica persistente visibile. Implementa obbligatoriamente `NeuralisForegroundService.kt` con notifica permanente:

```kotlin
// Caratteristiche obbligatorie della notifica
Titolo canale : "Neuralis System"
ID canale     : "neuralis_overlay_channel"
Titolo notif. : "Neuralis — System Active"
Priorità      : IMPORTANCE_LOW  (non disturba l'utente)
Tipo servizio : FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
```

### MediaProjection Flow ⚠️ CRITICO — Rispettare l'ordine esatto

Il permesso MediaProjection richiede un `Activity Result` **prima** di avviare qualsiasi service. Implementare in questo ordine senza eccezioni:

```
1. L'utente preme "Avvia Cattura Interna" nella UI Flutter
2. Flutter chiama MethodChannel → Kotlin avvia MediaProjectionManager.createScreenCaptureIntent()
3. Il dialogo di sistema viene mostrato all'utente
4. Kotlin riceve il callback onActivityResult()
   - Se RESULT_CANCELED → emetti errore al layer Presentation
   - Se RESULT_OK → procedi al passo 5
5. Avvia NeuralisForegroundService passando MediaProjectionData come Intent extra
6. Il service inizializza AudioRecord con sorgente AudioPlaybackCaptureConfiguration
7. Emetti conferma "INTERNAL_AUDIO_READY" via EventChannel a Flutter
```

### PermissionService — `/lib/core`

Interfaccia astratta con implementazione concreta iniettata via Riverpod:

```dart
abstract class PermissionService {
  Future<bool> requestOverlayPermission();   // ACTION_MANAGE_OVERLAY_PERMISSION
  Future<bool> requestAudioPermission();     // RECORD_AUDIO
  Future<bool> requestMediaProjection();     // Flow Activity Result descritto sopra
  Future<PermissionsState> checkAllPermissions(); // Stato aggregato di tutti i permessi
}
```

### Navigazione App ↔ Overlay

- **App principale:** Schermata di configurazione, controllo permessi, selezione modalità audio
- **Overlay operativo:** Neural Wavefront attivo, pad di interazione, status bar LCARS

### Task Sezione 1
- [ ] `AndroidManifest.xml` con tutti i permessi
- [ ] `NeuralisForegroundService.kt` con notifica persistente (canale + titolo + tipo)
- [ ] `PermissionService` abstract class + implementazione concreta
- [ ] MediaProjection flow completo in 7 passi con gestione RESULT_CANCELED
- [ ] Navigazione App ↔ Overlay
- [ ] Unit test: `PermissionService` mockato con `mocktail` — test ogni permesso, test stato aggregato

---

## 🔊 SEZIONE 2: ENGINE AUDIO & GESTIONE DRM (FALLBACK LOGIC)

**Obiettivo:** Estrazione FFT avanzata con resilienza ai blocchi DRM delle piattaforme streaming.

### Implementazione Nativa — `NativeAudioCapture.kt`

Esposto tramite:
- `MethodChannel("neuralis/audio")` → comandi (start, stop, setMode)
- `EventChannel("neuralis/audio_stream")` → stream continuo dati FFT

Tre modalità di cattura:

| Modalità | Sorgente | Descrizione |
|---|---|---|
| `Internal` | `AudioPlaybackCapture` via `MediaProjection` | Audio di sistema (es. Spotify, YouTube) |
| `External` | `AudioRecord` via `MIC` | Microfono ambientale |
| `Hybrid` | Entrambi in parallelo | Somma pesata dei due segnali |

### FFT Processing

```kotlin
// Pipeline di elaborazione per ogni buffer audio:
1. Applica Hanning Window al buffer grezzo        // riduce spectral leakage
2. Esegui FFT (dimensione consigliata: 1024 campioni)
3. Calcola magnitudine per ogni bin: sqrt(re² + im²)
4. Raggruppa i bin in 32 bande logaritmiche       // percettivamente uniformi
5. Normalizza ogni banda in [0.0, 1.0]            // rispetto al picco storico
6. Invia float[32] via EventChannel a Flutter
```

### Logica Enterprise Anti-DRM — Fallback Automatico ⚠️

```
AudioCaptureService — monitoraggio RMS continuo in modalità Internal / Hybrid:

  calcola rms_corrente = sqrt(mean(samples²)) per ogni buffer
  aggiorna rms_media su finestra mobile di 3 secondi

  SE rms_media < SOGLIA_SILENZIO (es. 0.001) PER PIÙ DI 3 SECONDI:
    1. Imposta modalità = External (Mic)
    2. Riavvia AudioRecord con sorgente MIC
    3. Emetti DrmBlockedEvent via EventChannel
    4. Il layer Presentation mostra LcarsWarningBanner:
       "⚠ AUDIO INTERNO BLOCCATO — ATTIVAZIONE SENSORE MIC AMBIENTALE"

  NOTA: usare rms_media < SOGLIA e NON rms == 0
        Il silenzio DRM non è mai matematicamente zero — è rumore sotto soglia.
```

### Task Sezione 2
- [ ] `NativeAudioCapture.kt` con MethodChannel + EventChannel
- [ ] Hanning Window + FFT a 32 bande logaritmiche normalizzate
- [ ] Tre modalità: Internal, External, Hybrid
- [ ] Monitoraggio RMS con finestra mobile 3s e soglia configurabile
- [ ] Failover automatico DRM con emissione `DrmBlockedEvent`
- [ ] Warning UI LCARS al failover
- [ ] Unit test: `AudioCaptureService` con mock EventChannel, test trigger RMS sotto soglia, test switch modalità

---

## 🎨 SEZIONE 3: NEURALIS LCARS DESIGN SYSTEM

**Obiettivo:** Framework UI modulare e riutilizzabile che definisce l'identità visiva di Neuralis.

### Palette Colori — `LcarsColors`

```dart
class LcarsColors {
  static const atomic   = Color(0xFFFF9900); // Arancio — colore primario, alert
  static const tan      = Color(0xFFFFCC66); // Giallo   — secondario, highlight
  static const purple   = Color(0xFFCC99CC); // Viola    — accento, info
  static const blueGray = Color(0xFF9999CC); // Blu/Grig — UI neutro, wireframe
  static const darkBg   = Color(0xFF000000); // Nero     — sfondo overlay
  static const panelBg  = Color(0xFF0A0A1A); // Blu nott — sfondo pannello
}
```

### Typography — `LcarsTypography`

- Font: **'Antonio'** via `google_fonts`
- Stile: uppercase, letter-spacing `2.0–4.0`, weight variabile per gerarchia
- Niente font di sistema — ogni testo UI usa Antonio

### Widget Modulari — `/lib/shared/widgets`

| Widget | Tipo | Descrizione |
|---|---|---|
| `LcarsElbow` | `CustomPainter` | Angolo asimmetrico a L, orientamento parametrizzabile (topLeft, topRight, bottomLeft, bottomRight) |
| `LcarsButton` | `StatefulWidget` | Bordo sinistro spesso, label uppercase Antonio, animazione colore su stato attivo/inattivo |
| `LcarsPanel` | `Widget` | Container con header colorato e body scuro semitrasparente |
| `LcarsStatusBar` | `Widget` | Label + valore + indicatore OK / WARNING / ERROR con colori semantici |
| `LcarsWarningBanner` | `AnimatedWidget` | Banner per eventi critici (DRM failover), testo lampeggiante, colore `atomic` |

### Task Sezione 3
- [ ] `LcarsColors`, `LcarsTypography`, `LcarsTheme` definiti e applicati globalmente
- [ ] `LcarsElbow` con CustomPainter, tutti e 4 gli orientamenti
- [ ] `LcarsButton` con stati animati attivo/inattivo
- [ ] `LcarsPanel` e `LcarsStatusBar` con colori semantici
- [ ] `LcarsWarningBanner` con animazione lampeggio per failover DRM
- [ ] Widget test per ogni componente

---

## 🌌 SEZIONE 4: NEURAL WAVEFRONT ENGINE (SHADERS GLSL)

**Obiettivo:** Rendering GLSL ad alte prestazioni, audio-reattivo, integrato nel ciclo di vita Flutter.

### Shader Warm-Up ⚠️ CRITICO — Eseguire durante l'init, mai on-demand

```dart
// In ShaderRepository.init() — chiamato durante lo splash screen
// PRIMA di navigare all'overlay, mai al primo frame di rendering

class ShaderRepository {
  late FragmentProgram _program;
  late FragmentShader _shader;

  Future<void> init() async {
    _program = await FragmentProgram.fromAsset('assets/shaders/wavefront.frag');
    _shader  = _program.fragmentShader();
    // Shader pronto — passarlo al widget CustomPainter via provider
  }

  FragmentShader get shader => _shader;

  void dispose() => _shader.dispose();
}
```

### File: `assets/shaders/wavefront.frag` — Specifica Completa

```glsl
#include <flutter/runtime_effect.glsl>

// Uniforms — aggiornati ogni frame dal layer Presentation
uniform float uTime;                  // secondi dall'avvio, per animazione rotazione
uniform vec2  uResolution;            // dimensioni canvas in pixel
uniform float uAudioFrequency[32];    // 32 bande FFT normalizzate [0.0, 1.0]
uniform vec2  uBending;               // swipe NavPad: x orizzontale, y verticale [-1.0, 1.0]

out vec4 fragColor;

// ── IMPLEMENTAZIONE RICHIESTA ──────────────────────────────────────────────
//
// 1. MESH WIREFRAME 3D PROCEDURALE
//    Genera una griglia NxN di linee in spazio 3D (N consigliato: 16)
//    Proietta in 2D con prospettiva semplice (divisione per z)
//
// 2. VERTEX DISPLACEMENT audio-reattivo sull'asse Y
//    - Bande 0–7   (basse)  → displacement righe centrali della griglia
//    - Bande 8–15  (medio-basse) → displacement zona intermedia
//    - Bande 16–23 (medio-alte) → displacement zona esterna
//    - Bande 24–31 (alte)   → displacement bordi estremi
//    Ampiezza displacement: uAudioFrequency[banda] * scaleFactor
//
// 3. ROTAZIONE 3D ANIMATA
//    Applica rotazione lenta sull'asse Y basata su uTime (effetto "floating")
//    Velocità consigliata: 0.3 rad/s
//
// 4. ABERRAZIONE CROMATICA DINAMICA
//    Attivata quando length(uBending) > 0.1
//    - Canale R: campionato con offset +uBending * chromaStrength
//    - Canale G: campionato senza offset
//    - Canale B: campionato con offset -uBending * chromaStrength
//    chromaStrength proporzionale a length(uBending)
//
// 5. PALETTE COLORI
//    - Linee wireframe base : #9999CC (LcarsColors.blueGray)
//    - Picchi di frequenza  : #FF9900 (LcarsColors.atomic)
//    - Sfondo               : #000000 trasparente (overlay)
//    - Transizione colore   : interpolazione lineare tra blueGray e atomic
//                             basata sul valore uAudioFrequency della banda
// ──────────────────────────────────────────────────────────────────────────
```

### Task Sezione 4
- [ ] `ShaderRepository` con warm-up in fase init (non on-demand)
- [ ] `wavefront.frag` completo: mesh wireframe 3D, displacement, rotazione, aberrazione cromatica
- [ ] Uniforms aggiornati ogni frame: `uTime`, `uResolution`, `uAudioFrequency[32]`, `uBending`
- [ ] Transizione colore blueGray → atomic sui picchi FFT
- [ ] `pubspec.yaml`: shader registrato in `flutter.shaders`
- [ ] Test: ShaderRepository.init() non lancia eccezioni, shader non null dopo warm-up

---

## 🕹️ SEZIONE 5: BUSINESS LOGIC DEI PAD & INTERAZIONE

**Obiettivo:** Mappare le interazioni tattili sui parametri dello shader in modo completamente isolato dalla UI e testabile in unit test.

### `InteractionController` — `/lib/features/interaction/domain`

Classe pura di dominio: **nessuna dipendenza Flutter o UI**. Gestisce lo stato dei pad e calcola i parametri da inviare allo shader. Esposta via Riverpod `StateNotifierProvider<InteractionController, InteractionState>`.

```dart
class InteractionState {
  final double bassGain;    // [0.5, 3.0] — default 1.0
  final Offset bending;     // [-1.0, 1.0] su entrambi gli assi — default Offset.zero
}
```

### BassPad

- **Funzione:** Moltiplicatore di guadagno (`bassGain`) applicato alle bande FFT 0–7 prima della trasmissione allo shader
- **Range:** `0.5` (attenuazione) → `3.0` (boost massimo)
- **Comportamento pressione:** Pressione continua → gain sale verso 3.0 con curva esponenziale
- **Comportamento rilascio:** Ritorno progressivo a `1.0` in 300ms con curva ease-out
- **Feedback visivo:** Il widget `LcarsButton` cambia colore da `blueGray` a `atomic` proporzionalmente al gain

### NavPad (Bending)

- **Funzione:** Mapping swipe 2D → `uBending` (vec2) per aberrazione cromatica e deformazione shader
- **Swipe orizzontale** → `uBending.x` in `[-1.0, 1.0]`
- **Swipe verticale** → `uBending.y` in `[-1.0, 1.0]`
- **Soglia aberrazione:** `length(uBending) > 0.1` → aberrazione cromatica attiva nello shader
- **Ritorno al rilascio:** Interpolazione ease-out a `(0.0, 0.0)` in 500ms
- **Implementazione:** `GestureDetector.onPanUpdate` normalizza il delta rispetto alle dimensioni del widget

### Task Sezione 5
- [ ] `InteractionController` con `BendingState` e `BassGainState` — zero dipendenze UI
- [ ] `BassPad` widget con curva esponenziale gain e ease-out al rilascio (300ms)
- [ ] `NavPad` widget con GestureDetector, normalizzazione delta e ease-out al rilascio (500ms)
- [ ] Feedback visivo BassPad: colore proporzionale al gain
- [ ] Unit test `InteractionController`:
  - test mapping swipe → bending normalizzato
  - test gain range [0.5, 3.0] non superabile
  - test ritorno a zero dopo rilascio
  - test soglia aberrazione `length > 0.1`

---

## 🚀 SEZIONE 6: OTTIMIZZAZIONE, LIFECYCLE E BUILD

**Obiettivo:** Stabilità enterprise, zero memory leak, predisposizione per espansioni future.

### Lifecycle Management ⚠️ CRITICO — Ordine di dispose obbligatorio

```
AppLifecycleObserver.onDetached() / widget.dispose():

  1. interactionController.dispose()     // ferma animazioni pad
  2. shaderRepository.dispose()          // rilascia FragmentShader
  3. audioCaptureService.stop()          // chiude AudioRecord nativo
  4. overlayService.hide()               // rimuove View da WindowManager
  5. NeuralisForegroundService.stopSelf() // termina il service Android

Gestione stati lifecycle (via WidgetsBindingObserver):
  - AppLifecycleState.paused   → pausa audio capture, shader in idle
  - AppLifecycleState.resumed  → riprende audio capture, shader attivo
  - AppLifecycleState.detached → esegue dispose chain completa
```

### `pubspec.yaml` — Dipendenze Approvate

```yaml
name: neuralis
description: Neural LCARS Overlay System

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.x.x       # State management + DI — unica soluzione
  google_fonts: ^6.x.x           # Font 'Antonio'
  permission_handler: ^11.x.x    # Runtime permissions Android

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.x.x               # Mock per unit test

flutter:
  shaders:
    - assets/shaders/wavefront.frag
  assets:
    - assets/shaders/
```

> ⛔ **VIETATO aggiungere:** `flutter_audio_visualizer`, `system_alert_window`, o qualsiasi pacchetto nativo non elencato sopra. Tutta la comunicazione nativa è custom via MethodChannel/EventChannel.

### Predisposizione Future Espansioni

Lascia le seguenti interfacce astratte vuote e documentate in `/lib/features/audio_engine/domain/`:

```dart
// TODO(future): implementare con Spotify Web API / Last.fm API
abstract class MetadataRepository {
  Future<TrackMetadata?> getCurrentTrackMetadata();
  Stream<TrackMetadata?> watchCurrentTrack();
}
```

Segna tutti i punti di estensione con `// TODO(future): descrizione espansione`.

### Task Sezione 6
- [ ] `AppLifecycleObserver` implementato con tutti e 3 gli stati lifecycle
- [ ] Dispose chain completa e ordinata per tutte le risorse
- [ ] `pubspec.yaml` finalizzato e verificato (nessuna dipendenza non approvata)
- [ ] `MetadataRepository` abstract class predisposta
- [ ] Test di integrazione: ciclo completo init → overlay attivo → paused → resumed → dispose

---

## 🔗 APPENDICE: LINK TECNICI DI RIFERIMENTO

Tutti i link sono da usare come **riferimento logico e ispirazione implementativa**. Non aggiungere dipendenze non approvate.

### Architettura
| Risorsa | Link |
|---|---|
| Clean Architecture (Uncle Bob) | https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html |
| Riverpod — Documentazione ufficiale | https://riverpod.dev/docs/introduction/getting_started |
| Riverpod — StateNotifier | https://riverpod.dev/docs/providers/state_notifier_provider |
| Riverpod — Testing | https://riverpod.dev/docs/essentials/testing |
| Flutter — Documentazione ufficiale | https://docs.flutter.dev |

### Infrastruttura Android
| Risorsa | Link |
|---|---|
| Android `SYSTEM_ALERT_WINDOW` | https://developer.android.com/reference/android/Manifest.permission#SYSTEM_ALERT_WINDOW |
| Flutter Platform Channels | https://docs.flutter.dev/platform-integration/platform-channels |
| Android Foreground Service | https://developer.android.com/guide/components/foreground-services |
| MediaProjection API | https://developer.android.com/media/grow/media-projection |
| system_alert_window (logica overlay, NON dipendenza) | https://pub.dev/packages/system_alert_window |

### Audio Engine
| Risorsa | Link |
|---|---|
| Android AudioRecord API | https://developer.android.com/reference/android/media/AudioRecord |
| MediaProjection Audio Capture (Android 10+) | https://developer.android.com/guide/topics/media/av-capture#capture-audio-playback |
| flutter_audio_visualizer (logica FFT, NON dipendenza) | https://pub.dev/packages/flutter_audio_visualizer |
| FFT / Hanning Window | https://en.wikipedia.org/wiki/Hann_function |

### Design System LCARS
| Risorsa | Link |
|---|---|
| LCARS SDK / Proporzioni e palette | https://www.thelcars.com |
| lcars-stylus (comportamento componenti) | https://github.com/joernweissenborn/lcars-stylus |
| Google Fonts — Antonio | https://fonts.google.com/specimen/Antonio |
| Flutter CustomPainter | https://api.flutter.dev/flutter/rendering/CustomPainter-class.html |

### Shader Engine
| Risorsa | Link |
|---|---|
| Flutter Fragment Shaders (doc ufficiale) | https://docs.flutter.dev/ui/design/graphics/fragment-shaders |
| flutter-custom-shaders (esempi pratici) | https://github.com/renancaraujo/flutter-custom-shaders |
| Audio-Shader-Studio (logica displacement) | https://github.com/karimnaaji/audioshader |
| GLSL Reference — Khronos | https://www.khronos.org/opengl/wiki/Fragment_Shader |

### Interazione & Performance
| Risorsa | Link |
|---|---|
| Flutter GestureDetector | https://api.flutter.dev/flutter/widgets/GestureDetector-class.html |
| Flutter Animations (ease-out) | https://docs.flutter.dev/ui/animations |
| Flutter WidgetsBindingObserver | https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html |
| Flutter Performance Best Practices | https://docs.flutter.dev/perf/best-practices |
| mocktail | https://pub.dev/packages/mocktail |

---

## 🚩 AVVIO PROGETTO — Sequenza Obbligatoria

Agente, procedi **nell'ordine esatto** indicato. Attendi conferma esplicita prima di procedere al passo successivo.

```
PASSO 1 → Genera ROADMAP.md completo con tutte le sezioni e checkbox
PASSO 2 → Genera docs/ARCHITECTURE.md con tabella decisioni e struttura cartelle
PASSO 3 → Crea la struttura delle cartelle Clean Architecture
PASSO 4 → Genera pubspec.yaml con le sole dipendenze approvate
PASSO 5 → Definisci tutte le interfacce astratte (abstract class) dei Service
           PRIMA di qualsiasi implementazione concreta
```

Se l'agente tenta di scrivere codice implementativo prima del Passo 5, interrompilo con:
> *"Fermati. Completa il passo corrente e attendi conferma prima di procedere."*

---

*Neuralis — Neural LCARS Overlay System*
*Master Prompt V.1.2 — Enterprise Edition — Definitivo*

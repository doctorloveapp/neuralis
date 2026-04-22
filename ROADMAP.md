# 🛸 NEURALIS — ROADMAP

### Neural LCARS Overlay System — Enterprise Edition V.1.2

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
- [ ] Definire tutte le interfacce astratte (`abstract class`) dei Service prima di qualsiasi implementazione
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

- [ ] `AndroidManifest.xml` con tutti i permessi
- [ ] `NeuralisForegroundService.kt` con notifica persistente (canale + titolo + tipo)
- [ ] `MediaProjectionHandler.kt` con flow completo in 7 passi
- [ ] `OverlayManager.kt` con WindowManager
- [ ] `PermissionService` abstract class + implementazione concreta
- [ ] MediaProjection flow con gestione `RESULT_CANCELED`
- [ ] Navigazione App ↔ Overlay
- [ ] Stringhe i18n per UI permessi (`app_en.arb` + `app_it.arb`)
- [ ] Unit test: `PermissionService` mockato con `mocktail` — test ogni permesso, test stato aggregato

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

- [ ] `NativeAudioCapture.kt` con MethodChannel + EventChannel
- [ ] Hanning Window + FFT a 32 bande logaritmiche normalizzate
- [ ] Tre modalità: Internal, External, Hybrid
- [ ] Monitoraggio RMS con finestra mobile 3s e soglia configurabile
- [ ] Failover automatico DRM con emissione `DrmBlockedEvent`
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

- [ ] `LcarsColors`, `LcarsTypography`, `LcarsTheme` definiti e applicati globalmente
- [ ] `LcarsElbow` con `CustomPainter`, tutti e 4 gli orientamenti
- [ ] `LcarsButton` con stati animati attivo/inattivo
- [ ] `LcarsPanel` e `LcarsStatusBar` con colori semantici
- [ ] `LcarsWarningBanner` con animazione lampeggio per failover DRM
- [ ] Tutte le stringhe widget via i18n (`context.l10n`)
- [ ] Widget test per ogni componente

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

- [ ] `ShaderRepository` con warm-up in fase init (non on-demand)
- [ ] `wavefront.frag` completo: mesh wireframe 3D, displacement, rotazione, aberrazione cromatica
- [ ] Uniforms aggiornati ogni frame
- [ ] Transizione colore blueGray → atomic sui picchi FFT
- [x] `pubspec.yaml`: shader registrato in `flutter.shaders`
- [ ] Riverpod provider: `shaderProvider` (AsyncNotifier)
- [ ] Test: `ShaderRepository.init()` non lancia eccezioni, shader non null dopo warm-up

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

- [ ] `InteractionController` con `InteractionState` — zero dipendenze UI
- [ ] `BassPad` widget con curva esponenziale gain e ease-out (300ms)
- [ ] `NavPad` widget con GestureDetector, normalizzazione delta, ease-out (500ms)
- [ ] Feedback visivo BassPad: colore proporzionale al gain
- [ ] Riverpod provider: `interactionProvider` (Notifier)
- [ ] Stringhe i18n per label pad
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
- [ ] `MetadataRepository` abstract class predisposta
- [ ] `splash_logo.png` generato da `logo_neuralis.png`
- [ ] App icon configurata con `logo_neuralis.png`
- [ ] Test di integrazione: ciclo completo init → overlay → paused → resumed → dispose

---

## 📊 PROGRESSO GLOBALE

| Sezione | Stato | Note |
|---|---|---|
| Sezione 0 — Architettura | 🔄 In corso | ROADMAP ✅, ARCHITECTURE ✅, Cartelle ✅, i18n ✅, pubspec ✅ — mancano interfacce |
| Sezione 1 — Infrastruttura | ⬜ Non iniziata | |
| Sezione 2 — Audio Engine | ⬜ Non iniziata | |
| Sezione 3 — LCARS Design | ⬜ Non iniziata | |
| Sezione 4 — Shader Engine | ⬜ Non iniziata | |
| Sezione 5 — Interazione | ⬜ Non iniziata | |
| Sezione 6 — Lifecycle | ⬜ Non iniziata | |

---

*Neuralis — Neural LCARS Overlay System*
*Roadmap V.1.2 — Aggiornata con decisioni confermate*

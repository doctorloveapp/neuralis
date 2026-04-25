# 🎛 Neuralis — Piano Operativo Implementation Presets

Questo documento definisce l'architettura e i parametri esatti per l'implementazione di un sistema di **Preset Dinamici** in Neuralis. L'obiettivo è superare la palette LCARS standard fornendo esperienze visive fluide, professionali, futuristiche e psichedeliche, manipolando le equazioni matematiche del rendering e la fisica dei pad.

---

## 🏗 FASE 1: Modifiche Architetturali (Infrastruttura Presets)

Attualmente i parametri sono costanti hardcoded nel file `.frag` e nel controller. Per renderli dinamici:

1. **State Management (`PresetNotifier`)**
   - Creare un `enum NeuralisPreset { synthwave, quantum, cyber, nebula, hyperspace }`.
   - Creare un Riverpod Notifier `presetProvider` che gestisce lo stato del preset attivo.
2. **Aggiornamento Shader (`wavefront.frag`)**
   - Convertire le costanti di colore (`COL_BASE`, `COL_TEAL`, ecc.) e di geometria/sensibilità in `uniform vec3` e `uniform float`.
   - Aggiungere un nuovo array di uniformi al `ShaderRepositoryImpl` che inietta i parametri del layout basandosi sul preset attivo in Flutter.
3. **Aggiornamento `InteractionController`**
   - Esporre modifier dinamici per `_maxBassGain`, `_bassRiseSpeed` e il `_bendingDecaySpeed` ricevendo lo stato dal `presetProvider`.

---

## 🎨 FASE 2: Specifiche Tecniche dei 5 Nuovi Preset

Di seguito i setup calcolati matematicamente per massimizzare la resa psichedelica e professionale.

### 1. SYNTHWAVE OVERDRIVE (Retrofuturismo Psichedelico)

*Un tuffo in uno spazio cibernetico anni '80 ad altissima saturazione. Contrasti estremi tra il vuoto e neon abbaglianti.*

- **Shader Colors (`vec3`)**:
  - `COL_BASE`: `(0.10, 0.00, 0.15)` (Viola nerastro profondo)
  - `COL_TEAL`: `(1.00, 0.05, 0.60)` (Hot Pink / Magenta)
  - `COL_ATOMIC`: `(0.00, 0.90, 1.00)` (Neon Cyan al picco)
- **Geometria & Dislocazione (`wavefront.frag`)**:
  - `MESH_W`: 1.10 (Mesh vastissima, sborda in orizzontale)
  - `FOV`: 1.10 (Prospettiva distorta "fish-eye")
  - `LW`: 0.006 (Linee più marcate stile neon)
  - *Sensibilità Audio:* `tBase` * 7.0 (molto reattivo ai medi)
- **Fisica Controller (`interaction_controller.dart`)**:
  - `_maxBassGain`: 10.0 (Picco aggressivo)
  - `_bassDecaySpeed`: 8.0 (Rilascio secco e ritmato)
  - *NavPad Aberration*: `abr = bendLen * 0.050` (Effetto distorsione VHS altissimo)

### 2. QUANTUM ANOMALY (Psichedelia Liquida e Organica)

*Movimenti organici, morbidi, come se la mesh fluttuasse in un fluido quantico bio-luminoso. Elevata aberrazione.*

- **Shader Colors (`vec3`)**:
  - `COL_BASE`: `(0.00, 0.15, 0.10)` (Verde palude oscuro)
  - `COL_TEAL`: `(0.00, 1.00, 0.50)` (Spring Green / Lime)
  - `COL_ATOMIC`: `(0.95, 1.00, 0.80)` (Bianco perlaceo brillante)
- **Geometria & Dislocazione (`wavefront.frag`)**:
  - `COLS` x `ROWS`: 24 x 16 (Griglia molto fitta per movimenti fluidi - Costo GPU moderato)
  - `CAM_DIST`: 2.8, `MESH_D`: 2.4 (Effetto tunnel più morbido)
  - *Animazione Onda*: `wave0 = sin(uTime * 0.40 + z0 * 4.0) * 0.050;` (Onde primarie lente ma ad alta frequenza spaziale)
  - *Sensibilità Audio:* `tBase` * 3.5 (Colorazione liquida, picchi rari)
- **Fisica Controller (`interaction_controller.dart`)**:
  - `_maxBassGain`: 6.0
  - `_bassDecaySpeed`: 1.5 (Rilascio lentissimo, effetto "Reverb/Swell" sui bassi)

### 3. CYBER-NEURO (Matrix Hacker Vibe)

*Rigido, matematico, precisissimo. Per l'utente che cerca il monitoraggio perfetto dei dati FFT puro con stile dark.*

- **Shader Colors (`vec3`)**:
  - `COL_BASE`: `(0.02, 0.02, 0.02)` (Nero quasi totale)
  - `COL_TEAL`: `(0.10, 0.50, 0.15)` (Verde scuro monitor)
  - `COL_ATOMIC`: `(0.40, 1.00, 0.20)` (Verde fosforo terminale)
- **Geometria & Dislocazione (`wavefront.frag`)**:
  - `FOV`: 0.45 (Proiettivo quasi Ortografico, piatto ed analitico)
  - `MESH_W`: 0.50 (Centrato, preciso)
  - `LW`: 0.002 (Wireframe tagliente, sottilissimo)
  - *Animazione Onda*: `wave0 = 0.0` (Spazio in idle completamente statico e piatto, si muove solo con l'audio)
- **Fisica Controller (`interaction_controller.dart`)**:
  - `_maxBassGain`: 4.0 (Nessun clipping estremo)
  - `_bassRiseSpeed`: 12.0 (Snap istantaneo della frequenza)
  - `Numero Bande Basse`: 4 (Isola solo il Kick-drum puro)

### 4. NEBULA CORE (Deep Space Float)

*Astratto e rilassante, per l'ascolto ambientale. Transizioni di colore lunghissime e lente, mesh lontana ed elegante.*

- **Shader Colors (`vec3`)**:
  - `COL_BASE`: `(0.05, 0.05, 0.25)` (Blu cosmico)
  - `COL_TEAL`: `(0.40, 0.10, 0.80)` (Viola Galattico)
  - `COL_ATOMIC`: `(1.00, 0.50, 0.30)` (Arancio Sole)
- **Geometria & Dislocazione (`wavefront.frag`)**:
  - `CAM_DIST`: 3.5 (Camera lontanissima)
  - `MESH_W`: 0.85
  - *Displacement Audio:* `d0 = audioBandAt(sym0) * 0.20` (Montagne morbide, colline basse)
  - *Transizione Ciano/Viola:* `tMid` threshold spinta a `0.2` per accendere subito il viola galattico.
- **Fisica Controller (`interaction_controller.dart`)**:
  - `_maxBassGain`: 3.0 (Molto pacato)
  - `Sensibilità Bending`: `* 2.0` (L'aberrazione cromatica richiede uno swipe completo per essere notata)

### 5. HYPERSPACE JUMP (Maximum Impact & Speed)

*Modalità party estrema: lampeggi continui, velocità di mesh esaltante, alto carico sensoriale.*

- **Shader Colors (`vec3`)**:
  - `COL_BASE`: `(0.00, 0.00, 0.00)` (Nero assoluto per massimizzare il contrasto neon)
  - `COL_TEAL`: `(0.00, 0.80, 1.00)` (Azzurro elettrico)
  - `COL_ATOMIC`: `(1.00, 0.00, 0.20)` (Rosso/Cremisi Red Alert)
  - `COL_WHITE`: `(1.00, 1.00, 1.00)` (Flash bianco puro per clip audio)
- **Geometria & Dislocazione (`wavefront.frag`)**:
  - `CAM_DIST`: 2.0, `MESH_D`: 1.8 (Camera vicinissima alla griglia, sensazione di immersione totale)
  - `FOV`: 0.90
  - *Animazione Onda*: `wave0 = sin(uTime * 1.50 + z0 * 1.5) * 0.080;` (Scroll iper-veloce asse Z)
  - *Displacement Y:* `* 0.85` (Risposta in altitudine spinta ai limiti dello schermo)
- **Fisica Controller (`interaction_controller.dart`)**:
  - `_maxBassGain`: 12.0 (Spinta devastante per brani EDM/Techno)
  - `_bendingDecaySpeed`: 8.0 (Ritorno istantaneo del navpad elastico)
  - `Numero Bande Basse`: 12 (Coinvolge dai Sub-bass fino alle frequenze medie per i lead synth)

---

## 📋 FASE 3: Roadmap di Implementazione

1. **Modifica Shader (`wavefront.frag`)**: Sostituire le definizioni `const vec3` con l'header `uniform vec3 uColorBase;`, `uniform vec3 uColorTeal;`, etc. e rimappare in C++ (`ShaderRepositoryImpl.dart`).
2. **Provider & State Management**: Iniettare `PresetNotifier` nel root.
3. **UI Aggiornamento**: Aggiungere un piccolo interruttore "CYBER / MATRIX / NEBULA" nella `OverlayDashboard`, sopra il blocco dei sensori Pad, con pulsanti stile LCARS.
4. **Test di Clipping**: Eseguire brani con alto RMS (es. EDM) con Preset Hyperspace Jump per testare anomalie visive su S23 ed elaborare un clamp lato Dart qualora le Y sbordino.

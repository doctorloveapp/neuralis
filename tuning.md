# 🎛 Neuralis — Guida ai Parametri di Tuning

> Questo documento elenca **tutti i parametri modificabili** di Neuralis,
> con range sicuri, effetti visivi e avvertenze.
> Non serve toccare altro codice: modifica solo i valori indicati qui.

---

## 1. GLSL SHADER — `assets/shaders/wavefront.frag`

Questo file è il cuore visivo di Neuralis. Ogni modifica richiede
`flutter run` per ricompilare lo shader (il file viene compilato in SPIR-V al build).

### 🔲 Dimensioni Griglia

```glsl
const int   COLS = 16;   // Colonne verticali della mesh  [8 .. 32]
const int   ROWS = 12;   // Righe orizzontali della mesh  [6 .. 24]
```

| Parametro | Default | Min | Max | Effetto |
|---|---|---|---|---|
| `COLS` | `16` | `8` | `32` | + colonne = mesh più fine, - FPS |
| `ROWS` | `12` | `6` | `24` | + righe = mesh più profonda, - FPS |

> ⚠️ **Performance**: `COLS × ROWS` = iterazioni per pixel. Su S23, il limite confortevole è ~300 (es. 16×12=192 ✅, 24×16=384 ⚠️, 32×20=640 ❌).

---

### 📐 Geometria Camera & Mesh

```glsl
const float CAM_DIST = 2.2;   // Distanza camera dalla mesh     [1.5 .. 4.0]
const float MESH_D   = 2.0;   // Profondità mesh (asse Z)       [0.8 .. 3.0]
const float MESH_W   = 0.72;  // Semi-larghezza mesh (asse X)   [0.15 .. 1.2]
const float FOV      = 0.85;  // Campo visivo prospettica        [0.40 .. 1.20]
```

| Parametro | Effetto Visivo |
|---|---|
| `CAM_DIST` ↑ | Mesh appare più piccola e lontana |
| `CAM_DIST` ↓ | Mesh appare più grande (non andare sotto `MESH_D + 0.3`) |
| `MESH_W` ↑ | Mesh più larga — esce fuori schermo per effetto drammatico |
| `MESH_W` ↓ | Mesh più stretta e centrata |
| `MESH_D` ↑ | Griglia più profonda (tunnel più lungo) |
| `FOV` ↑ | Prospettiva più accentuata, distorsione ai bordi |
| `FOV` ↓ | Effetto quasi-ortografico, piatto |

> ⚠️ **REGOLA CRITICA**: `CAM_DIST` deve essere **sempre > `MESH_D` + 0.2**  
> Altrimenti la mesh va dietro la camera → bianco totale (divisione per zero).

**Esempio ingrandimento mesh:**
```glsl
MESH_W = 0.90;  FOV = 1.00;  CAM_DIST = 2.5;  // Mesh molto imponente
MESH_W = 0.50;  FOV = 0.75;  CAM_DIST = 2.0;  // Mesh bilanciata
MESH_W = 0.25;  FOV = 0.60;  CAM_DIST = 1.8;  // Mesh piccola centrata
```

---

### ➖ Larghezza Linee

```glsl
const float LW = 0.004;   // Larghezza linee (spazio UV)  [0.001 .. 0.012]
```

| Valore | Effetto |
|---|---|
| `0.002` | Linee sottilissime, quasi invisibili |
| `0.004` | Default — buon compromesso visibilità/eleganza |
| `0.007` | Linee spesse, look "neon" |
| `0.012` | Linee molto grosse (stile retrò) |

---

### 🎵 Reattività Audio (Displacement Y)

```glsl
// Riga nel loop: float d0 = audioBandAt(sym0) * 0.50;
//                                                 ^^^^
//                                        Questo è il fattore Y
```

Trova questa riga nel file e modifica il moltiplicatore `0.50`:

| Valore | Effetto |
|---|---|
| `0.10` | Mesh quasi piatta, minima risposta audio |
| `0.25` | Risposta moderata |
| `0.50` | Default — picchi ben visibili |
| `0.80` | Risposta estrema — la mesh "esplode" |
| `1.20` | Esplosione totale (rischio clip) |

> 💡 **Suggerimento**: con BassPad premuto il gain arriva a 8.0 — se il displacement base è già 0.80, il risultato è `0.80 × 8.0 = 6.4` (clamped a 1.0 dallo shader). Mantieni il valore base più basso per avere gamma dinamica.

---

### 🎨 Colori LCARS

Questi sono i colori della palette. Formato: `vec3(R, G, B)` con valori **0.0–1.0**.

```glsl
// ── Colori di base ──────────────────────────────────────
const vec3 COL_BASE    = vec3(0.050, 0.080, 0.180);  // Blu notte profondo
const vec3 COL_TEAL    = vec3(0.000, 0.780, 0.850);  // Ciano LCARS
const vec3 COL_ATOMIC  = vec3(1.000, 0.600, 0.000);  // Arancione (#FF9900)
const vec3 COL_PURPLE  = vec3(0.750, 0.400, 1.000);  // Viola (#BF66FF)
const vec3 COL_WHITE   = vec3(0.950, 0.950, 1.000);  // Bianco freddo

// ── Colore NavPad (bending) ─────────────────────────────
// Modificato da bendLen * [questo fattore]:
// baseCol = mix(baseCol, COL_PURPLE, bendLen * 0.60);
//                                              ^^^^  range [0.0 .. 1.0]
```

**Convertire colore HEX → vec3:**
```
#FF9900 → vec3(255/255, 153/255, 0/255) → vec3(1.000, 0.600, 0.000)
#00CCFF → vec3(0/255, 204/255, 255/255) → vec3(0.000, 0.800, 1.000)
#9966FF → vec3(153/255, 102/255, 255/255) → vec3(0.600, 0.400, 1.000)
#FF3366 → vec3(255/255, 51/255, 102/255) → vec3(1.000, 0.200, 0.400)
```

**Colori LCARS consigliati:**
| Nome | HEX | vec3 |
|---|---|---|
| Atomic Orange | `#FF9900` | `vec3(1.000, 0.600, 0.000)` |
| Blue-Gray | `#9999CC` | `vec3(0.600, 0.600, 0.800)` |
| Tan | `#FFCC99` | `vec3(1.000, 0.800, 0.600)` |
| Purple | `#9966CC` | `vec3(0.600, 0.400, 0.800)` |
| Teal | `#00CCFF` | `vec3(0.000, 0.800, 1.000)` |
| Red Alert | `#FF4444` | `vec3(1.000, 0.267, 0.267)` |
| Lime | `#99FF33` | `vec3(0.600, 1.000, 0.200)` |

---

### 🌈 Soglie Colore (Sensibilità Audio)

Questa sezione controlla quando e quanto velocemente il colore cambia con l'audio:

```glsl
// Nel loop principale, cerca queste righe:

float tBase   = clamp(energy * 5.0, 0.0, 1.0);   // 5.0 = sensibilità base
//                              ^^^
// RANGE CONSIGLIATO: 2.0 .. 10.0
// 2.0 = transizione lenta, solo ai picchi
// 5.0 = default — visibile a volumi medi
// 10.0 = tutto arancione anche a volumi bassi

float tMid    = clamp((tBase - 0.4) * 4.0, 0.0, 1.0);  // Soglia ciano
//                              ^^^   ^^^
// 0.4 = quando inizia il ciano (0.0..0.9)
// 4.0 = velocità transizione ciano (1.0..8.0)

float tPeak   = clamp((tBase - 0.75) * 4.0, 0.0, 1.0); // Soglia arancione→bianco
//                               ^^^^
// 0.75 = quando inizia il bianco (0.5..0.95)
```

---

### ✨ Aberrazione Cromatica (NavPad)

```glsl
float abr = bendLen * 0.030;
//                    ^^^^
// RANGE: 0.000 (disabilitata) .. 0.060 (estrema)
// 0.010 = sottile
// 0.030 = default — chiaramente visibile
// 0.050 = molto intensa (effetto VHS)
```

---

### 🌊 Animazione (Breathing Wave)

```glsl
// Nel loop, cerca:
float wave0 = sin(uTime * 0.65 + z0 * 2.4) * 0.030;
//                         ^^^^          ^^^   ^^^^
//                    velocità        freq Z  ampiezza
```

| Parametro | Effetto |
|---|---|
| `uTime * 0.65` → velocità | Aumenta: onda più rapida. Dim: più lenta |
| `z0 * 2.4` → frequenza Z | Aumenta: più "onde" lungo la profondità |
| `* 0.030` → ampiezza | Aumenta: mesh ondeggia di più (0.0..0.1) |

```glsl
float tiltAmt = sin(uTime * 0.12) * 0.06;
//                          ^^^^    ^^^^
//                    velocità   ampiezza inclinazione piano
```

---

## 2. INTERACTION CONTROLLER — `lib/features/interaction/presentation/interaction_controller.dart`

### 🥁 BassPad

```dart
static const double _maxBassGain    = 8.0;  // Gain massimo     [1.5 .. 15.0]
static const double _bassRiseSpeed  = 6.0;  // Velocità salita  [2.0 .. 12.0]
static const double _bassDecaySpeed = 5.0;  // Velocità discesa [1.0 .. 10.0]
```

| Parametro | Effetto |
|---|---|
| `_maxBassGain` | Moltiplicatore massimo delle bande FFT basse. `8.0` = mesh "esplode". `15.0` = esplosione totale |
| `_bassRiseSpeed` | Velocità di salita. `6.0` ≈ 0.25s al picco. Aumenta per risposta istantanea |
| `_bassDecaySpeed` | Velocità di discesa al rilascio. `5.0` ≈ 300ms. Diminuisci per effetto "riverb" |

**Esempio configurazioni:**
```dart
// Risposta immediata e secca:
_maxBassGain = 6.0;  _bassRiseSpeed = 10.0;  _bassDecaySpeed = 8.0;

// Esplosiva e lenta (effetto "swell"):
_maxBassGain = 12.0;  _bassRiseSpeed = 3.0;  _bassDecaySpeed = 1.5;
```

### 🧭 NavPad

```dart
// In onNavPadUpdate():
final newX = (current.bendingX + normalizedDx * 5.4).clamp(-1.0, 1.0);
//                                                ^^^
//                                       Sensibilità bending [1.0 .. 10.0]
```

```dart
static const double _bendingDecaySpeed = 3.2;  // Ritorno elastico [1.0 .. 8.0]
```

| Parametro | Effetto |
|---|---|
| Moltiplicatore `5.4` | Quanto velocemente il bending raggiunge ±1.0. `2.0` = preciso. `8.0` = iper-reattivo |
| `_bendingDecaySpeed` | Velocità ritorno a zero. `1.0` ≈ 1s (morbido). `8.0` ≈ 100ms (snappy) |

---

## 3. AUDIO NOTIFIER — `lib/features/audio_engine/presentation/audio_notifier.dart`

### 🎛 Bande Basse Influenzate dal BassPad

```dart
// In _routeToShader():
for (int i = 0; i < 8 && i < bands.length; i++) {
//                    ^
//              Numero di bande basse amplificate [1 .. 32]
```

| Valore | Effetto |
|---|---|
| `4` | Solo le frequenze più basse (kick drum) |
| `8` | Default — bassi + bassi-medi |
| `16` | Metà dello spettro amplificata |
| `32` | Tutto lo spettro amplificato |

---

## 4. UI — `lib/features/overlay_ui/presentation/screens/overlay_dashboard.dart`

### 📦 Dimensioni Pad

```dart
// Classe _BassPad → AnimatedContainer:
width:  100,    // Larghezza BassPad [60 .. 160]
height: 64,     // Altezza BassPad   [40 .. 100]

// Classe _NavPad → AnimatedContainer:
height: 64,     // Altezza NavPad    [40 .. 100]

// Classe _BottomPadRow → Container:
height: 100,    // Altezza riga pads [72 .. 140]
```

---

## 5. RIFERIMENTO RAPIDO — RICETTE

### 🔥 "Maximum Impact" (Preset Concerto)
```glsl
// wavefront.frag
MESH_W = 0.90;  FOV = 1.00;  CAM_DIST = 2.5;  LW = 0.005;
// displacement: * 0.70
// energy: * 8.0
```
```dart
// interaction_controller.dart
_maxBassGain = 12.0;  _bassRiseSpeed = 8.0;  _bassDecaySpeed = 3.0;
// sensibilità NavPad: * 8.0
```

### 🌊 "Ambient" (Preset Meditazione)
```glsl
// wavefront.frag
MESH_W = 0.45;  FOV = 0.70;  CAM_DIST = 2.2;  LW = 0.003;
// displacement: * 0.20
// energy: * 3.0
```
```dart
// interaction_controller.dart
_maxBassGain = 3.0;  _bassRiseSpeed = 2.0;  _bassDecaySpeed = 1.0;
// sensibilità NavPad: * 2.0
```

### 🎯 "Precision" (Preset Monitor)
```glsl
// wavefront.frag
COLS = 24;  ROWS = 16;  // Griglia più fine (check FPS!)
MESH_W = 0.55;  FOV = 0.80;  LW = 0.003;
// displacement: * 0.35
// energy: * 4.0
```

---

## ⚠️ Regole di Sicurezza

1. **Non abbassare mai `CAM_DIST` sotto `MESH_D + 0.2`** → schermo bianco
2. **Non alzare `COLS × ROWS` sopra 400** → calo FPS grave su mobile
3. **I colori vec3 vanno da 0.0 a 1.0** — valori fuori range vengono clampati ma possono causare glitch
4. **`_maxBassGain` sopra 15.0** → le bande vengono tutte clampate a 1.0 (nessun effetto aggiuntivo)
5. **Aberrazione `abr > 0.080`** → distorsione estrema che può coprire la mesh

---

*Neuralis Tuning Guide v1.0 — 2026-04-25*

#include <flutter/runtime_effect.glsl>

// ============================================================================
// Neuralis — wavefront.frag
// Neural LCARS Overlay System — Shader del Wavefront Procedurale
//
// Uniforms (ordine OBBLIGATORIO per compatibilità con WavefrontPainter.dart):
//   Index 0      → uTime             (float)  secondi dall'avvio
//   Index 1-2    → uResolution       (vec2)   dimensioni canvas in pixel
//   Index 3-34   → uAudioFrequency   (float[32]) bande FFT [0.0, 1.0]
//   Index 35-36  → uBending          (vec2)   input NavPad [-1.0, 1.0]
//
// Pipeline:
//   1. UV normalizzate + aspect ratio
//   2. Griglia wireframe 3D procedurale (proiezione prospettica semplice /z)
//   3. Displacement Y mappato sulle 32 bande FFT (centro=bassi, bordi=alti)
//   4. Aberrazione cromatica RGB split (intensità ∝ |uBending|)
//   5. Color blend dinamico: blueGray (#9999CC) ↔ atomic (#FF9900)
// ============================================================================

uniform float uTime;
uniform vec2  uResolution;
uniform float uAudioFrequency[32];
uniform vec2  uBending;

out vec4 fragColor;

// ── Palette LCARS ────────────────────────────────────────────────────────────
const vec3 COL_BLUEGRAY = vec3(0.600, 0.600, 0.800); // #9999CC
const vec3 COL_ATOMIC   = vec3(1.000, 0.600, 0.000); // #FF9900
const vec3 COL_BG       = vec3(0.000, 0.000, 0.000); // #000000 overlay bg

// ── Costanti mesh ─────────────────────────────────────────────────────────────
const int   GRID_COLS  = 32;   // colonne griglia (1 per banda FFT)
const int   GRID_ROWS  = 20;   // righe griglia
const float FOV        = 0.7;  // campo visivo prospettica
const float CAM_Z      = 2.2;  // distanza camera dalla mesh
const float MESH_DEPTH = 2.5;  // estensione Z della mesh (profondità)
const float LINE_WIDTH = 0.012; // larghezza delle linee wireframe

// ── Helper: distanza di un punto da un segmento 2D ───────────────────────────
float distToSegment(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    vec2 ap = p - a;
    float t  = clamp(dot(ap, ab) / dot(ab, ab), 0.0, 1.0);
    return length(ap - t * ab);
}

// ── Campiona la banda FFT appropriata per la colonna X della mesh ─────────────
// Le 32 bande coprono l'asse X della mesh: banda 0 = centro sinistra,
// banda 31 = bordo destro. Il displacement è simmetrico rispetto al centro.
float getBandDisplacement(float normX) {
    // normX in [0.0, 1.0]: mappa sull'indice di banda
    float idx  = normX * float(GRID_COLS - 1);
    int   iLow = int(floor(idx));
    int   iHi  = min(iLow + 1, GRID_COLS - 1);
    float frac = fract(idx);
    return mix(uAudioFrequency[iLow], uAudioFrequency[iHi], frac);
}

// ── Proiezione prospettica 3D → 2D ────────────────────────────────────────────
// p3 → coordinate 3D mesh
// Ritorna la posizione 2D sullo schermo (UV normalizzate)
vec2 project(vec3 p3) {
    float z    = CAM_Z - p3.z;                 // distanza dalla camera
    float scale = FOV / max(z, 0.001);         // divisione prospettica
    return p3.xy * scale;                      // proiezione centrata
}

// ── Intensità aberrazione cromatica ───────────────────────────────────────────
float bendMagnitude() {
    return clamp(length(uBending) * 1.2, 0.0, 1.0);
}

// ── Colore del wireframe interpolato con energia audio ────────────────────────
vec3 wireColor(float energy) {
    // energy = valore FFT medio nell'intorno del punto
    return mix(COL_BLUEGRAY, COL_ATOMIC, clamp(energy * 1.5, 0.0, 1.0));
}

// ─────────────────────────────────────────────────────────────────────────────
// main
// ─────────────────────────────────────────────────────────────────────────────
void main() {
    // ── 1. UV normalizzate centrate, corrette per aspect ratio ───────────────
    vec2 fragCoord = FlutterFragCoord().xy;
    float aspect   = uResolution.x / uResolution.y;
    vec2  uv       = (fragCoord / uResolution - 0.5) * vec2(aspect, 1.0);

    // ── Aberrazione cromatica: offsets RGB proporzionali a |uBending| ────────
    float abr      = bendMagnitude() * 0.018;
    vec2  chromR   = uv + uBending * abr;
    vec2  chromB   = uv - uBending * abr;
    // (chromG = uv, canale centrale non spostato)

    // ── 2. Inizializza accumulatori colore per i 3 canali (aberr. cromatica) ─
    float accumR = 0.0, accumG = 0.0, accumB = 0.0;
    float accumW = 0.0; // peso totale (per normalizzazione)

    // Variazione lenta del piano della mesh nel tempo
    float meshTilt = sin(uTime * 0.15) * 0.08;   // inclinazione oscillante

    // ── 3. Rasterizzazione wireframe 3D ──────────────────────────────────────
    // Per ogni cella della griglia, tracciamo i 4 spigoli del quad.
    // Ogni vertice ha una posizione 3D calcolata con displacement FFT.

    for (int row = 0; row < GRID_ROWS; row++) {
        for (int col = 0; col < GRID_COLS; col++) {

            // Coordinate normalizate della cella [0.0, 1.0]
            float nx0 = float(col)     / float(GRID_COLS);
            float nx1 = float(col + 1) / float(GRID_COLS);
            float nz0 = float(row)     / float(GRID_ROWS);
            float nz1 = float(row + 1) / float(GRID_ROWS);

            // Posizioni X nel range [-1.0, 1.0]
            float x0 = nx0 * 2.0 - 1.0;
            float x1 = nx1 * 2.0 - 1.0;

            // Posizioni Z nel range [0.0, MESH_DEPTH]
            float z0 = nz0 * MESH_DEPTH;
            float z1 = nz1 * MESH_DEPTH;

            // Displacement Y da FFT: usa posizione X assoluta (simmetria dal centro)
            float symNx0 = abs(nx0 * 2.0 - 1.0); // simmetria rispetto al centro
            float symNx1 = abs(nx1 * 2.0 - 1.0);
            float disp00 = getBandDisplacement(1.0 - symNx0) * 0.5;
            float disp10 = getBandDisplacement(1.0 - symNx1) * 0.5;
            float disp01 = disp00;
            float disp11 = disp10;

            // Ondulazione base nel tempo (breathing effect)
            float wave0 = sin(uTime * 0.8 + z0 * 2.0) * 0.04;
            float wave1 = sin(uTime * 0.8 + z1 * 2.0) * 0.04;

            // Inclinazione piano globale
            float tilt0 = z0 * meshTilt;
            float tilt1 = z1 * meshTilt;

            // Coordinate 3D dei 4 vertici del quad
            vec3 v00 = vec3(x0, disp00 + wave0 + tilt0, z0);
            vec3 v10 = vec3(x1, disp10 + wave0 + tilt0, z0);
            vec3 v01 = vec3(x0, disp01 + wave1 + tilt1, z1);
            vec3 v11 = vec3(x1, disp11 + wave1 + tilt1, z1);

            // Proiezione prospettica 2D
            vec2 p00 = project(v00);
            vec2 p10 = project(v10);
            vec2 p01 = project(v01);
            vec2 p11 = project(v11);

            // Energia media del quad (per colorazione)
            float energy = (disp00 + disp10 + disp01 + disp11) * 0.25;

            // Larghezza linea dipende da Z (foreshortening)
            float lw = LINE_WIDTH * (FOV / max(CAM_Z - z0, 0.001));

            // ── Rasterizza i 4 spigoli del quad ───────────────────────────
            // Usiamo le 3 UV diverse per l'aberrazione cromatica.
            // Spigolo: orizzontale superiore (v00→v10)
            float dR0 = distToSegment(chromR, p00, p10);
            float dG0 = distToSegment(uv,     p00, p10);
            float dB0 = distToSegment(chromB, p00, p10);

            // Spigolo: verticale sinistra (v00→v01)
            float dR1 = distToSegment(chromR, p00, p01);
            float dG1 = distToSegment(uv,     p00, p01);
            float dB1 = distToSegment(chromB, p00, p01);

            // (Solo per l'ultima riga/colonna tracciamo i bordi opposti)
            float dR2 = 1.0, dG2 = 1.0, dB2 = 1.0;
            float dR3 = 1.0, dG3 = 1.0, dB3 = 1.0;
            if (row == GRID_ROWS - 1) {
                dR2 = distToSegment(chromR, p01, p11);
                dG2 = distToSegment(uv,     p01, p11);
                dB2 = distToSegment(chromB, p01, p11);
            }
            if (col == GRID_COLS - 1) {
                dR3 = distToSegment(chromR, p10, p11);
                dG3 = distToSegment(uv,     p10, p11);
                dB3 = distToSegment(chromB, p10, p11);
            }

            // Intensità linea (smooth step anti-aliasing)
            float lineR = smoothstep(lw, lw * 0.3, min(min(dR0, dR1), min(dR2, dR3)));
            float lineG = smoothstep(lw, lw * 0.3, min(min(dG0, dG1), min(dG2, dG3)));
            float lineB = smoothstep(lw, lw * 0.3, min(min(dB0, dB1), min(dB2, dB3)));

            // Fade su Z (le linee lontane svaniscono)
            float zFade = 1.0 - smoothstep(MESH_DEPTH * 0.5, MESH_DEPTH, z0);

            // Colore della linea (interpolato energia audio)
            vec3 col = wireColor(energy);

            accumR += col.r * lineR * zFade;
            accumG += col.g * lineG * zFade;
            accumB += col.b * lineB * zFade;
            accumW += max(max(lineR, lineG), lineB) * zFade;
        }
    }

    // ── 4. Composizione finale ───────────────────────────────────────────────
    vec3 wireCol = vec3(
        clamp(accumR, 0.0, 1.0),
        clamp(accumG, 0.0, 1.0),
        clamp(accumB, 0.0, 1.0)
    );

    // Sfondo nero trasparente + wireframe
    float alpha = clamp(accumW * 1.5, 0.0, 0.92);
    fragColor   = vec4(wireCol, alpha);
}

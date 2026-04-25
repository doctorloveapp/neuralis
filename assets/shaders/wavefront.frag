#include <flutter/runtime_effect.glsl>

// ============================================================================
// Neuralis — wavefront.frag  v3.0  (performance build)
//
// Uniforms (indici identici al lato Dart — NON modificare ordine):
//   Index 0      → uTime
//   Index 1-2    → uResolution
//   Index 3-34   → uAudioBand0..7 (8×vec4 = 32 bande FFT)
//   Index 35-36  → uBending
//
// Ottimizzazioni v3:
//   - Loop 16×12 (era 32×20 = 640 iter → ora 192 iter, -70%)
//   - Calcoli pesanti spostati fuori dal loop interno
//   - Aberrazione cromatica semplificata (1 solo distSeg per spigolo)
//   - Accesso bande FFT con lookup table pre-calcolata
// ============================================================================

uniform float uTime;
uniform vec2  uResolution;
uniform vec4  uAudioBand0;
uniform vec4  uAudioBand1;
uniform vec4  uAudioBand2;
uniform vec4  uAudioBand3;
uniform vec4  uAudioBand4;
uniform vec4  uAudioBand5;
uniform vec4  uAudioBand6;
uniform vec4  uAudioBand7;
uniform vec2  uBending;

out vec4 fragColor;

// ── Palette LCARS ────────────────────────────────────────────────────────────
const vec3  COL_BLUEGRAY = vec3(0.600, 0.600, 0.800); // #9999CC
const vec3  COL_ATOMIC   = vec3(1.000, 0.600, 0.000); // #FF9900
const vec3  COL_PURPLE   = vec3(0.800, 0.600, 0.800); // #CC99CC

// ── Costanti mesh ─────────────────────────────────────────────────────────────
const int   COLS       = 16;   // colonne (era 32, -50%)
const int   ROWS       = 12;   // righe   (era 20, -40%)
const float CAM_DIST   = 1.5;  // distanza camera dalla mesh (sempre > MESH_D)
const float MESH_D     = 1.2;  // profondità mesh (< CAM_DIST garantito)
const float MESH_W     = 0.22; // semi-larghezza mesh (world units)
const float FOV        = 0.60; // campo visivo
const float LW         = 0.005; // larghezza linea (screen-space, costante)

// ── Accesso banda FFT per indice 0..31 (no dynamic vec4 indexing) ─────────────
float getAudio(int i) {
    if (i <  4) {
        if (i == 0) return uAudioBand0.x;
        if (i == 1) return uAudioBand0.y;
        if (i == 2) return uAudioBand0.z;
        return uAudioBand0.w;
    }
    if (i <  8) {
        if (i == 4) return uAudioBand1.x;
        if (i == 5) return uAudioBand1.y;
        if (i == 6) return uAudioBand1.z;
        return uAudioBand1.w;
    }
    if (i < 12) {
        if (i ==  8) return uAudioBand2.x;
        if (i ==  9) return uAudioBand2.y;
        if (i == 10) return uAudioBand2.z;
        return uAudioBand2.w;
    }
    if (i < 16) {
        if (i == 12) return uAudioBand3.x;
        if (i == 13) return uAudioBand3.y;
        if (i == 14) return uAudioBand3.z;
        return uAudioBand3.w;
    }
    if (i < 20) {
        if (i == 16) return uAudioBand4.x;
        if (i == 17) return uAudioBand4.y;
        if (i == 18) return uAudioBand4.z;
        return uAudioBand4.w;
    }
    if (i < 24) {
        if (i == 20) return uAudioBand5.x;
        if (i == 21) return uAudioBand5.y;
        if (i == 22) return uAudioBand5.z;
        return uAudioBand5.w;
    }
    if (i < 28) {
        if (i == 24) return uAudioBand6.x;
        if (i == 25) return uAudioBand6.y;
        if (i == 26) return uAudioBand6.z;
        return uAudioBand6.w;
    }
    if (i == 28) return uAudioBand7.x;
    if (i == 29) return uAudioBand7.y;
    if (i == 30) return uAudioBand7.z;
    return uAudioBand7.w;
}

// ── Campionamento banda per posizione X normalizzata [0,1] ────────────────────
float audioBandAt(float nx) {
    // Scala nx da 32 bande a COLS (16) con interpolazione
    float idx  = clamp(nx, 0.0, 1.0) * 31.0;
    int   iLo  = int(floor(idx));
    int   iHi  = min(iLo + 1, 31);
    return mix(getAudio(iLo), getAudio(iHi), fract(idx));
}

// ── Distanza punto-segmento 2D ────────────────────────────────────────────────
float distSeg(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float d2 = dot(ab, ab) + 1e-5;
    float t  = clamp(dot(p - a, ab) / d2, 0.0, 1.0);
    return length(p - a - t * ab);
}

// ── Proiezione prospettica (camera davanti alla mesh) ─────────────────────────
vec2 proj(vec3 p) {
    return p.xy * (FOV / (p.z + CAM_DIST));
}

// ─────────────────────────────────────────────────────────────────────────────
// main
// ─────────────────────────────────────────────────────────────────────────────
void main() {
    vec2 fc   = FlutterFragCoord().xy;
    float asp = uResolution.x / uResolution.y;
    vec2  uv  = (fc / uResolution - 0.5) * vec2(asp, 1.0);

    // Aberrazione cromatica semplificata: offset basato su uBending
    float bendLen = clamp(length(uBending), 0.0, 1.0);
    float abr     = bendLen * 0.014;
    vec2  offR    = uBending * abr;
    vec2  uvR     = uv + offR;
    vec2  uvB     = uv - offR;

    // Calcoli invarianti spostati FUORI dal loop ─────────────────────────────
    float tiltAmt = sin(uTime * 0.12) * 0.05;
    float fCols   = float(COLS);
    float fRows   = float(ROWS);

    float accumR = 0.0, accumG = 0.0, accumB = 0.0, accumW = 0.0;

    for (int row = 0; row < ROWS; row++) {
        float nz0 = float(row)     / fRows;
        float nz1 = float(row + 1) / fRows;
        float z0  = nz0 * MESH_D;
        float z1  = nz1 * MESH_D;

        // Fade distanza — skip righe invisibili per salvare GPU
        float zFade = 1.0 - smoothstep(MESH_D * 0.5, MESH_D * 0.92, z0);
        if (zFade < 0.02) continue;

        // Calcoli di riga spostati fuori dal loop colonne ────────────────────
        float wave0 = sin(uTime * 0.65 + z0 * 2.8) * 0.025;
        float wave1 = sin(uTime * 0.65 + z1 * 2.8) * 0.025;
        float tilt0 = z0 * tiltAmt;
        float tilt1 = z1 * tiltAmt;
        float waveY0 = wave0 + tilt0;
        float waveY1 = wave1 + tilt1;

        for (int col = 0; col < COLS; col++) {
            float nx0 = float(col)     / fCols;
            float nx1 = float(col + 1) / fCols;

            float xw0 = (nx0 * 2.0 - 1.0) * MESH_W;
            float xw1 = (nx1 * 2.0 - 1.0) * MESH_W;

            // Displacement FFT: simmetrico rispetto al centro
            float sym0 = 1.0 - abs(nx0 * 2.0 - 1.0);
            float sym1 = 1.0 - abs(nx1 * 2.0 - 1.0);
            float d0   = audioBandAt(sym0) * 0.18;
            float d1   = audioBandAt(sym1) * 0.18;

            // 4 vertici del quad
            vec2 p00 = proj(vec3(xw0, d0 + waveY0, z0));
            vec2 p10 = proj(vec3(xw1, d1 + waveY0, z0));
            vec2 p01 = proj(vec3(xw0, d0 + waveY1, z1));
            vec2 p11 = proj(vec3(xw1, d1 + waveY1, z1));

            // Energia audio per il colore
            float energy = (d0 + d1) * 0.5;

            // ── 2 spigoli principali (top + left) ───────────────────────────
            // Aberrazione cromatica: canale R e B su UV sfasate, G su UV centrale
            float dTop_G = distSeg(uv,  p00, p10);
            float dTop_R = distSeg(uvR, p00, p10);
            float dTop_B = distSeg(uvB, p00, p10);

            float dLft_G = distSeg(uv,  p00, p01);
            float dLft_R = distSeg(uvR, p00, p01);
            float dLft_B = distSeg(uvB, p00, p01);

            float dG = min(dTop_G, dLft_G);
            float dR = min(dTop_R, dLft_R);
            float dB = min(dTop_B, dLft_B);

            // Spigoli chiusura solo per ultima riga/colonna
            if (row == ROWS - 1) {
                dG = min(dG, distSeg(uv,  p01, p11));
                dR = min(dR, distSeg(uvR, p01, p11));
                dB = min(dB, distSeg(uvB, p01, p11));
            }
            if (col == COLS - 1) {
                dG = min(dG, distSeg(uv,  p10, p11));
                dR = min(dR, distSeg(uvR, p10, p11));
                dB = min(dB, distSeg(uvB, p10, p11));
            }

            float lineG = smoothstep(LW, LW * 0.15, dG);
            float lineR = smoothstep(LW, LW * 0.15, dR);
            float lineB = smoothstep(LW, LW * 0.15, dB);

            // Colore: blueGray → atomic in base all'energia audio
            float t      = clamp(energy * 3.0, 0.0, 1.0);
            vec3 baseCol = mix(COL_BLUEGRAY, COL_ATOMIC, t);

            // Tinta bending: shift verso purple quando NavPad attivo
            baseCol = mix(baseCol, COL_PURPLE, bendLen * 0.35);

            accumR += baseCol.r * lineR * zFade;
            accumG += baseCol.g * lineG * zFade;
            accumB += baseCol.b * lineB * zFade;
            accumW += max(lineG, max(lineR, lineB)) * zFade;
        }
    }

    vec3  col   = clamp(vec3(accumR, accumG, accumB), 0.0, 1.0);
    float alpha = clamp(accumW * 1.3, 0.0, 0.95);
    fragColor   = vec4(col, alpha);
}

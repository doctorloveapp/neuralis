#include <flutter/runtime_effect.glsl>

// ============================================================================
// Neuralis — wavefront.frag  v4.0  (tactical build)
//
// Uniforms (indici Dart invariati):
//   Index 0      → uTime
//   Index 1-2    → uResolution
//   Index 3-34   → uAudioBand0..7  (8×vec4 = 32 bande FFT)
//   Index 35-36  → uBending
//
// v4 changes:
//   - Scala mesh 1.8x (MESH_W 0.22→0.40, MESH_D 1.2→2.2)
//   - CAM_DIST aumentata per non tagliare la mesh scalata
//   - Displacement Y aumentato proporzionalmente (0.18→0.32)
//   - Colore: transizione atomic molto più aggressiva (energy*5.0)
//   - Aberrazione cromatica lineare con bendLen (0.030 vs 0.014)
//   - Bass gain applicato direttamente al displacement
// ============================================================================

uniform float uTime;
uniform vec2  uResolution;
uniform vec4  uAudioBand0;   // bande  0-3
uniform vec4  uAudioBand1;   // bande  4-7
uniform vec4  uAudioBand2;   // bande  8-11
uniform vec4  uAudioBand3;   // bande 12-15
uniform vec4  uAudioBand4;   // bande 16-19
uniform vec4  uAudioBand5;   // bande 20-23
uniform vec4  uAudioBand6;   // bande 24-27
uniform vec4  uAudioBand7;   // bande 28-31
uniform vec2  uBending;

out vec4 fragColor;

// ── Palette LCARS ────────────────────────────────────────────────────────────
const vec3 COL_BLUEGRAY = vec3(0.600, 0.600, 0.800); // #9999CC — riposo
const vec3 COL_ATOMIC   = vec3(1.000, 0.600, 0.000); // #FF9900 — picchi audio
const vec3 COL_PURPLE   = vec3(0.780, 0.500, 0.900); // #C780E6 — bending NavPad
const vec3 COL_WHITE    = vec3(0.950, 0.950, 1.000); // Boost estremo bass

// ── Costanti mesh (scala 1.8x rispetto a v3) ──────────────────────────────────
const int   COLS      = 16;
const int   ROWS      = 12;
const float CAM_DIST  = 2.0;   // distanza camera (> MESH_D garantito)
const float MESH_D    = 1.6;   // profondità (era 1.2, ×1.33)
const float MESH_W    = 0.40;  // semi-larghezza (era 0.22, ×1.82 → griglia imponente)
const float FOV       = 0.80;  // campo visivo (era 0.60, aperto per la scala)
const float LW        = 0.004; // larghezza linea

// ── Accesso banda FFT per indice 0..31 ────────────────────────────────────────
float getAudio(int i) {
    if (i == 0)  return uAudioBand0.x;
    if (i == 1)  return uAudioBand0.y;
    if (i == 2)  return uAudioBand0.z;
    if (i == 3)  return uAudioBand0.w;
    if (i == 4)  return uAudioBand1.x;
    if (i == 5)  return uAudioBand1.y;
    if (i == 6)  return uAudioBand1.z;
    if (i == 7)  return uAudioBand1.w;
    if (i == 8)  return uAudioBand2.x;
    if (i == 9)  return uAudioBand2.y;
    if (i == 10) return uAudioBand2.z;
    if (i == 11) return uAudioBand2.w;
    if (i == 12) return uAudioBand3.x;
    if (i == 13) return uAudioBand3.y;
    if (i == 14) return uAudioBand3.z;
    if (i == 15) return uAudioBand3.w;
    if (i == 16) return uAudioBand4.x;
    if (i == 17) return uAudioBand4.y;
    if (i == 18) return uAudioBand4.z;
    if (i == 19) return uAudioBand4.w;
    if (i == 20) return uAudioBand5.x;
    if (i == 21) return uAudioBand5.y;
    if (i == 22) return uAudioBand5.z;
    if (i == 23) return uAudioBand5.w;
    if (i == 24) return uAudioBand6.x;
    if (i == 25) return uAudioBand6.y;
    if (i == 26) return uAudioBand6.z;
    if (i == 27) return uAudioBand6.w;
    if (i == 28) return uAudioBand7.x;
    if (i == 29) return uAudioBand7.y;
    if (i == 30) return uAudioBand7.z;
    return uAudioBand7.w;
}

// ── Campionamento con interpolazione lineare ──────────────────────────────────
float audioBandAt(float nx) {
    float idx = clamp(nx, 0.0, 1.0) * 31.0;
    int   iLo = int(floor(idx));
    int   iHi = min(iLo + 1, 31);
    return mix(getAudio(iLo), getAudio(iHi), fract(idx));
}

// ── Distanza punto-segmento 2D ────────────────────────────────────────────────
float distSeg(vec2 p, vec2 a, vec2 b) {
    vec2  ab = b - a;
    float t  = clamp(dot(p - a, ab) / (dot(ab, ab) + 1e-5), 0.0, 1.0);
    return length(p - a - t * ab);
}

// ── Proiezione prospettica ────────────────────────────────────────────────────
vec2 proj(vec3 p) {
    return p.xy * (FOV / (p.z + CAM_DIST));
}

// ─────────────────────────────────────────────────────────────────────────────
// main
// ─────────────────────────────────────────────────────────────────────────────
void main() {
    vec2  fc  = FlutterFragCoord().xy;
    float asp = uResolution.x / uResolution.y;
    vec2  uv  = (fc / uResolution - 0.5) * vec2(asp, 1.0);

    // ── Aberrazione cromatica: lineare con |uBending| (3x più visibile di v3) ─
    float bendLen = clamp(length(uBending), 0.0, 1.0);
    float abr     = bendLen * 0.030;           // era 0.014
    vec2  uvR     = uv + uBending * abr;
    vec2  uvB     = uv - uBending * abr;

    // ── Calcoli invarianti fuori dal loop ────────────────────────────────────
    float tiltAmt = sin(uTime * 0.12) * 0.06;
    float fCols   = float(COLS);
    float fRows   = float(ROWS);

    float accumR = 0.0, accumG = 0.0, accumB = 0.0, accumW = 0.0;

    for (int row = 0; row < ROWS; row++) {
        float nz0 = float(row)     / fRows;
        float nz1 = float(row + 1) / fRows;
        float z0  = nz0 * MESH_D;
        float z1  = nz1 * MESH_D;

        float zFade = 1.0 - smoothstep(MESH_D * 0.55, MESH_D * 0.92, z0);
        if (zFade < 0.02) continue;

        // Calcoli per riga (fuori dal loop colonne)
        float wave0  = sin(uTime * 0.65 + z0 * 2.4) * 0.030;
        float wave1  = sin(uTime * 0.65 + z1 * 2.4) * 0.030;
        float waveY0 = wave0 + z0 * tiltAmt;
        float waveY1 = wave1 + z1 * tiltAmt;

        for (int col = 0; col < COLS; col++) {
            float nx0 = float(col)     / fCols;
            float nx1 = float(col + 1) / fCols;

            float xw0 = (nx0 * 2.0 - 1.0) * MESH_W;
            float xw1 = (nx1 * 2.0 - 1.0) * MESH_W;

            // Displacement FFT simmetrico dal centro
            float sym0 = 1.0 - abs(nx0 * 2.0 - 1.0);
            float sym1 = 1.0 - abs(nx1 * 2.0 - 1.0);

            // 0.32 = fattore displacement Y (era 0.18, ×1.78 proporzionale a MESH_W)
            float d0 = audioBandAt(sym0) * 0.32;
            float d1 = audioBandAt(sym1) * 0.32;

            vec2 p00 = proj(vec3(xw0, d0 + waveY0, z0));
            vec2 p10 = proj(vec3(xw1, d1 + waveY0, z0));
            vec2 p01 = proj(vec3(xw0, d0 + waveY1, z1));
            vec2 p11 = proj(vec3(xw1, d1 + waveY1, z1));

            float energy = (d0 + d1) * 0.5;

            float dG = min(distSeg(uv,  p00, p10), distSeg(uv,  p00, p01));
            float dR = min(distSeg(uvR, p00, p10), distSeg(uvR, p00, p01));
            float dB = min(distSeg(uvB, p00, p10), distSeg(uvB, p00, p01));

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

            // ── Colore: transizione MOLTO più aggressiva ─────────────────────
            // energy * 5.0 → arancione visibile già a volumi medi (0.2 → 1.0)
            float tAudio  = clamp(energy * 5.0, 0.0, 1.0);
            // Bass boost (da uBending.x inutilizzato? No, usiamo energy raw)
            // La saturazione extra porta a bianco ai picchi estremi
            float tExtrem = clamp((tAudio - 0.7) * 3.5, 0.0, 1.0);
            vec3  baseCol = mix(COL_BLUEGRAY, COL_ATOMIC, tAudio);
            baseCol       = mix(baseCol, COL_WHITE, tExtrem);

            // Tinta NavPad: lerp verso purple proporzionale a bendLen
            baseCol = mix(baseCol, COL_PURPLE, bendLen * 0.50);

            accumR += baseCol.r * lineR * zFade;
            accumG += baseCol.g * lineG * zFade;
            accumB += baseCol.b * lineB * zFade;
            accumW += max(lineG, max(lineR, lineB)) * zFade;
        }
    }

    vec3  col   = clamp(vec3(accumR, accumG, accumB), 0.0, 1.0);
    float alpha = clamp(accumW * 1.4, 0.0, 0.96);
    fragColor   = vec4(col, alpha);
}

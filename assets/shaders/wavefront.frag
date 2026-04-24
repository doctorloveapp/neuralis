#include <flutter/runtime_effect.glsl>

// ============================================================================
// Neuralis — wavefront.frag  v2.0
//
// Uniforms (indici identici al lato Dart):
//   Index 0      → uTime
//   Index 1-2    → uResolution
//   Index 3-34   → uAudioBand0..7 (8×vec4 = 32 bande FFT)
//   Index 35-36  → uBending
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

const vec3  COL_BLUEGRAY = vec3(0.600, 0.600, 0.800);
const vec3  COL_ATOMIC   = vec3(1.000, 0.600, 0.000);
const int   GRID_COLS    = 32;
const int   GRID_ROWS    = 20;
// Camera al z=0, mesh si estende in z positivo (lontano dalla camera).
// CAM_OFFSET = distanza minima camera-fronte della mesh (sempre > 0).
const float CAM_OFFSET   = 1.2;
const float MESH_DEPTH   = 2.0;  // DEVE essere < qualsiasi soglia catastrofica
const float MESH_WIDTH   = 0.28; // semi-larghezza mesh in world units
const float FOV          = 0.65;
const float LINE_WIDTH   = 0.004;

// ── Accesso componente vec4 senza dynamic indexing ───────────────────────────
float getComp(vec4 v, int c) {
    if (c == 0) return v.x;
    if (c == 1) return v.y;
    if (c == 2) return v.z;
    return v.w;
}

float getAudioBand(int i) {
    int b = i / 4;
    int c = i - b * 4;
    vec4 v;
    if      (b == 0) v = uAudioBand0;
    else if (b == 1) v = uAudioBand1;
    else if (b == 2) v = uAudioBand2;
    else if (b == 3) v = uAudioBand3;
    else if (b == 4) v = uAudioBand4;
    else if (b == 5) v = uAudioBand5;
    else if (b == 6) v = uAudioBand6;
    else             v = uAudioBand7;
    return getComp(v, c);
}

// ── Distanza punto-segmento 2D ────────────────────────────────────────────────
float distSeg(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a, ap = p - a;
    float t = clamp(dot(ap, ab) / (dot(ab, ab) + 0.0001), 0.0, 1.0);
    return length(ap - t * ab);
}

// ── Campionamento banda per colonna X ────────────────────────────────────────
float audioBandAt(float normX) {
    float idx  = clamp(normX, 0.0, 1.0) * float(GRID_COLS - 1);
    int   iLow = int(floor(idx));
    int   iHi  = min(iLow + 1, GRID_COLS - 1);
    return mix(getAudioBand(iLow), getAudioBand(iHi), fract(idx));
}

// ── Proiezione prospettica (camera a z negativo, mesh in z positivo) ─────────
// z = p3.z + CAM_OFFSET è SEMPRE > 0: nessuna divisione per zero.
vec2 project(vec3 p) {
    float z = p.z + CAM_OFFSET;
    return p.xy * (FOV / z);
}

// ── Colore wireframe ──────────────────────────────────────────────────────────
vec3 wireColor(float energy) {
    return mix(COL_BLUEGRAY, COL_ATOMIC, clamp(energy * 2.0, 0.0, 1.0));
}

// ─────────────────────────────────────────────────────────────────────────────
void main() {
    vec2 fc     = FlutterFragCoord().xy;
    float asp   = uResolution.x / uResolution.y;
    vec2  uv    = (fc / uResolution - 0.5) * vec2(asp, 1.0);

    float abr   = clamp(length(uBending) * 1.2, 0.0, 1.0) * 0.016;
    vec2  chromR = uv + uBending * abr;
    vec2  chromB = uv - uBending * abr;

    float accumR = 0.0, accumG = 0.0, accumB = 0.0, accumW = 0.0;
    float tilt   = sin(uTime * 0.12) * 0.06;

    for (int row = 0; row < GRID_ROWS; row++) {
        float nz0 = float(row)     / float(GRID_ROWS);
        float nz1 = float(row + 1) / float(GRID_ROWS);
        float z0  = nz0 * MESH_DEPTH;
        float z1  = nz1 * MESH_DEPTH;

        // Fade linee lontane
        float zFade = 1.0 - smoothstep(MESH_DEPTH * 0.45, MESH_DEPTH * 0.9, z0);
        if (zFade < 0.01) continue;

        float wave0 = sin(uTime * 0.7 + z0 * 2.5) * 0.03;
        float wave1 = sin(uTime * 0.7 + z1 * 2.5) * 0.03;

        for (int col = 0; col < GRID_COLS; col++) {
            float nx0 = float(col)     / float(GRID_COLS);
            float nx1 = float(col + 1) / float(GRID_COLS);

            float xw0 = (nx0 * 2.0 - 1.0) * MESH_WIDTH;
            float xw1 = (nx1 * 2.0 - 1.0) * MESH_WIDTH;

            // Displacement FFT simmetrico: banda 0 = centro, 31 = bordi
            float sym0 = 1.0 - abs(nx0 * 2.0 - 1.0);
            float sym1 = 1.0 - abs(nx1 * 2.0 - 1.0);
            float d00  = audioBandAt(sym0) * 0.22;
            float d10  = audioBandAt(sym1) * 0.22;

            vec3 v00 = vec3(xw0, d00 + wave0 + z0 * tilt, z0);
            vec3 v10 = vec3(xw1, d10 + wave0 + z0 * tilt, z0);
            vec3 v01 = vec3(xw0, d00 + wave1 + z1 * tilt, z1);
            vec3 v11 = vec3(xw1, d10 + wave1 + z1 * tilt, z1);

            vec2 p00 = project(v00);
            vec2 p10 = project(v10);
            vec2 p01 = project(v01);
            vec2 p11 = project(v11);

            float energy = (d00 + d10) * 0.5;
            float lw     = LINE_WIDTH;

            // Spigolo orizzontale superiore
            float dR0 = distSeg(chromR, p00, p10);
            float dG0 = distSeg(uv,     p00, p10);
            float dB0 = distSeg(chromB, p00, p10);
            // Spigolo verticale sinistro
            float dR1 = distSeg(chromR, p00, p01);
            float dG1 = distSeg(uv,     p00, p01);
            float dB1 = distSeg(chromB, p00, p01);
            // Bordi opposti solo per ultima riga/colonna
            float dR2 = 1.0, dG2 = 1.0, dB2 = 1.0;
            float dR3 = 1.0, dG3 = 1.0, dB3 = 1.0;
            if (row == GRID_ROWS - 1) {
                dR2 = distSeg(chromR, p01, p11);
                dG2 = distSeg(uv,     p01, p11);
                dB2 = distSeg(chromB, p01, p11);
            }
            if (col == GRID_COLS - 1) {
                dR3 = distSeg(chromR, p10, p11);
                dG3 = distSeg(uv,     p10, p11);
                dB3 = distSeg(chromB, p10, p11);
            }

            float lineR = smoothstep(lw, lw * 0.2, min(min(dR0, dR1), min(dR2, dR3)));
            float lineG = smoothstep(lw, lw * 0.2, min(min(dG0, dG1), min(dG2, dG3)));
            float lineB = smoothstep(lw, lw * 0.2, min(min(dB0, dB1), min(dB2, dB3)));

            vec3 lineCol = wireColor(energy);
            accumR += lineCol.r * lineR * zFade;
            accumG += lineCol.g * lineG * zFade;
            accumB += lineCol.b * lineB * zFade;
            accumW += max(max(lineR, lineG), lineB) * zFade;
        }
    }

    vec3  wireCol = clamp(vec3(accumR, accumG, accumB), 0.0, 1.0);
    float alpha   = clamp(accumW * 1.4, 0.0, 0.94);
    fragColor     = vec4(wireCol, alpha);
}

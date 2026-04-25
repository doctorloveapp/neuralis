#include <flutter/runtime_effect.glsl>

// ============================================================================
// Neuralis — wavefront.frag  v7.1  (Multiverse Preset + Terrain + CamDist)
//
// Uniform layout (indici Dart — NON modificare ordine):
//   0        → uTime
//   1-2      → uResolution
//   3-34     → uAudioBand0..7  (8×vec4 = 32 float)
//   35-36    → uBending        (x=rotazione, y=tilt)
//   37-39    → uColorBase      (vec3)
//   40-42    → uColorMid       (vec3)
//   43-45    → uColorPeak      (vec3)
//   46       → uFov
//   47       → uMeshW
//   48       → uLineWeight
//   49       → uWaveSpeed
//   50       → uCamDist
// ============================================================================

uniform float uTime;
uniform vec2  uResolution;
uniform vec4  uAudioBand0; uniform vec4  uAudioBand1;
uniform vec4  uAudioBand2; uniform vec4  uAudioBand3;
uniform vec4  uAudioBand4; uniform vec4  uAudioBand5;
uniform vec4  uAudioBand6; uniform vec4  uAudioBand7;
uniform vec2  uBending;
uniform vec3  uColorBase;
uniform vec3  uColorMid;
uniform vec3  uColorPeak;
uniform float uFov;
uniform float uMeshW;
uniform float uLineWeight;
uniform float uWaveSpeed;
uniform float uCamDist;    // distanza camera dal piano mesh (>= MESH_D + 0.3)

out vec4 fragColor;

// ── Costanti fisse ────────────────────────────────────────────────────────────
const int   COLS        = 16;
const int   ROWS        = 14;
const float MESH_D      = 1.8;
const float VERT_SPREAD = 1.20;
const float DISP_Y      = 0.55;

// ── FFT lookup ────────────────────────────────────────────────────────────────
float getAudio(int i) {
    if (i== 0) return uAudioBand0.x; if (i== 1) return uAudioBand0.y;
    if (i== 2) return uAudioBand0.z; if (i== 3) return uAudioBand0.w;
    if (i== 4) return uAudioBand1.x; if (i== 5) return uAudioBand1.y;
    if (i== 6) return uAudioBand1.z; if (i== 7) return uAudioBand1.w;
    if (i== 8) return uAudioBand2.x; if (i== 9) return uAudioBand2.y;
    if (i==10) return uAudioBand2.z; if (i==11) return uAudioBand2.w;
    if (i==12) return uAudioBand3.x; if (i==13) return uAudioBand3.y;
    if (i==14) return uAudioBand3.z; if (i==15) return uAudioBand3.w;
    if (i==16) return uAudioBand4.x; if (i==17) return uAudioBand4.y;
    if (i==18) return uAudioBand4.z; if (i==19) return uAudioBand4.w;
    if (i==20) return uAudioBand5.x; if (i==21) return uAudioBand5.y;
    if (i==22) return uAudioBand5.z; if (i==23) return uAudioBand5.w;
    if (i==24) return uAudioBand6.x; if (i==25) return uAudioBand6.y;
    if (i==26) return uAudioBand6.z; if (i==27) return uAudioBand6.w;
    if (i==28) return uAudioBand7.x; if (i==29) return uAudioBand7.y;
    if (i==30) return uAudioBand7.z; return uAudioBand7.w;
}

float audioBandAt(float nx) {
    float idx = clamp(nx,0.0,1.0)*31.0;
    int iLo = int(floor(idx)); int iHi = min(iLo+1,31);
    return mix(getAudio(iLo), getAudio(iHi), fract(idx));
}

// ── Terrain Engine: onde composte organiche ───────────────────────────────────
// uWaveSpeed = 0.0 → CYBER statico; 2.8 → HYPERSPACE velocissimo
float terrainY(float nx, float nz, float fftVal) {
    float t    = uTime * uWaveSpeed;
    float xArg = nx * 6.283 + t;
    float zArg = nz * 4.712 + t * 0.7;

    // Onda principale: FFT × sin(x+t) × cos(z+t)
    float mainWave = fftVal * sin(xArg) * cos(zArg);

    // Rumore organico ai bordi (fluttua lentamente indipendente dal basso)
    float edgeFactor  = 1.0 - abs(nx * 2.0 - 1.0);
    float borderNoise = (1.0 - edgeFactor)
                      * sin(nx * 12.5 + uTime * 0.3)
                      * cos(nz *  9.4 + uTime * 0.25)
                      * 0.08;

    // Valle centrale: audio più evidente al centro
    float centralAmp = 0.3 + edgeFactor * 0.7;
    return (mainWave * centralAmp + borderNoise) * DISP_Y;
}

float distSeg(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    return length(p - a - clamp(dot(p-a,ab)/(dot(ab,ab)+1e-5),0.0,1.0)*ab);
}

// ── Proiezione: rotazione Y-axis (NavPad swipe) + uCamDist per preset ─────────
vec2 proj(vec3 p) {
    float angle = uBending.x * 0.55;
    float cosA  = cos(angle); float sinA = sin(angle);
    float dz    = p.z - MESH_D * 0.5;
    float rx    = p.x * cosA - dz * sinA;
    float rz    = dz * cosA + p.x * sinA + MESH_D * 0.5;
    return vec2(rx, p.y) * (uFov / max(rz + uCamDist, 0.15));
}

// ── Colore preset-driven con slow evolution ────────────────────────────────────
vec3 presetColor(float energy, float zNorm, float huePhase, float agitation) {
    vec3 calmCol  = mix(uColorBase, uColorMid, huePhase);
    float tPeak   = clamp((agitation - 0.4) * 3.2, 0.0, 1.0);
    vec3  hotCol  = mix(uColorMid, uColorPeak, tPeak);
    float tLocal  = clamp(energy * 4.5 + agitation * 2.0, 0.0, 1.0);
    vec3  col     = mix(calmCol, hotCol, tLocal);
    col = mix(col, uColorBase * 0.3, zNorm * 0.35);
    return col;
}

// ─────────────────────────────────────────────────────────────────────────────
void main() {
    vec2  fc  = FlutterFragCoord().xy;
    float asp = uResolution.x / uResolution.y;
    vec2  uv  = (fc / uResolution - 0.5) * vec2(asp, 1.0);

    // Energia totale istantanea
    float totalE = (dot(uAudioBand0,vec4(0.25)) + dot(uAudioBand1,vec4(0.25))
                  + dot(uAudioBand2,vec4(0.25)) + dot(uAudioBand3,vec4(0.25))
                  + dot(uAudioBand4,vec4(0.25)) + dot(uAudioBand5,vec4(0.25))
                  + dot(uAudioBand6,vec4(0.25)) + dot(uAudioBand7,vec4(0.25))) / 8.0;

    // Ciclo lento palette (~80s period) — calma vs agitazione
    float huePhase = sin(uTime * 0.079) * 0.5 + 0.5;

    float fCols = float(COLS); float fRows = float(ROWS);
    float accumR = 0.0, accumG = 0.0, accumB = 0.0, accumW = 0.0;

    for (int row = 0; row < ROWS; row++) {
        float nz0 = float(row)     / fRows;
        float nz1 = float(row + 1) / fRows;
        float z0  = nz0 * MESH_D;

        float zFade = 1.0 - smoothstep(MESH_D * 0.55, MESH_D * 0.92, z0);
        if (zFade < 0.02) continue;

        // Rampa verticale (fix mesh piatta) + tilt NavPad Y
        float yRamp0 = (nz0 - 0.25) * VERT_SPREAD + uBending.y * 0.25;
        float yRamp1 = ((nz0 + 1.0/fRows) - 0.25) * VERT_SPREAD + uBending.y * 0.25;

        for (int col = 0; col < COLS; col++) {
            float nx0 = float(col)     / fCols;
            float nx1 = float(col + 1) / fCols;
            float xw0 = (nx0 * 2.0 - 1.0) * uMeshW;
            float xw1 = (nx1 * 2.0 - 1.0) * uMeshW;

            float fft0 = audioBandAt(nx0);
            float fft1 = audioBandAt(nx1);
            float dy00 = terrainY(nx0, nz0, fft0);
            float dy10 = terrainY(nx1, nz0, fft1);
            float dy01 = terrainY(nx0, nz0 + 1.0/fRows, fft0);
            float dy11 = terrainY(nx1, nz0 + 1.0/fRows, fft1);

            vec2 p00 = proj(vec3(xw0, dy00 + yRamp0, z0));
            vec2 p10 = proj(vec3(xw1, dy10 + yRamp0, z0));
            vec2 p01 = proj(vec3(xw0, dy01 + yRamp1, z0 + MESH_D/fRows));
            vec2 p11 = proj(vec3(xw1, dy11 + yRamp1, z0 + MESH_D/fRows));

            float energy = (fft0 + fft1) * 0.5;

            float dG = min(distSeg(uv, p00, p10), distSeg(uv, p00, p01));
            if (row == ROWS-1) dG = min(dG, distSeg(uv, p01, p11));
            if (col == COLS-1) dG = min(dG, distSeg(uv, p10, p11));

            float lw   = uLineWeight;
            float line = smoothstep(lw, lw * 0.15, dG);

            vec3 col3 = presetColor(energy, nz0, huePhase, totalE);
            accumR += col3.r * line * zFade;
            accumG += col3.g * line * zFade;
            accumB += col3.b * line * zFade;
            accumW += sqrt(line) * zFade;
        }
    }

    vec3  col   = clamp(vec3(accumR, accumG, accumB), 0.0, 1.0);
    float alpha = clamp(accumW * 1.1, 0.0, 0.97);
    fragColor   = vec4(col, alpha);
}

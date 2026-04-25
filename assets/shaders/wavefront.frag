#include <flutter/runtime_effect.glsl>

// Neuralis — wavefront.frag v6.0
// Fix: rampa Y verticale, rotazione NavPad, colori slow-evolving LCARS

uniform float uTime;
uniform vec2  uResolution;
uniform vec4  uAudioBand0; uniform vec4  uAudioBand1;
uniform vec4  uAudioBand2; uniform vec4  uAudioBand3;
uniform vec4  uAudioBand4; uniform vec4  uAudioBand5;
uniform vec4  uAudioBand6; uniform vec4  uAudioBand7;
uniform vec2  uBending;   // .x=rotazione NavPad  .y=tilt verticale

out vec4 fragColor;

// ── Palette LCARS ─────────────────────────────────────────────────────────────
const vec3 COL_DEEP    = vec3(0.030, 0.050, 0.150); // blu abissale (riposo)
const vec3 COL_TEAL    = vec3(0.000, 0.780, 0.900); // ciano #00C7E6
const vec3 COL_LAVEND  = vec3(0.600, 0.500, 0.950); // lavanda #9980F2
const vec3 COL_ATOMIC  = vec3(1.000, 0.600, 0.000); // atomic orange #FF9900
const vec3 COL_WHITE   = vec3(0.930, 0.950, 1.000); // bianco freddo

// ── Costanti (vedi tuning.md per range sicuri) ────────────────────────────────
const int   COLS        = 16;
const int   ROWS        = 12;
const float CAM_DIST    = 2.5;  // SICUREZZA: deve essere > MESH_D + 0.3
const float MESH_D      = 1.8;
const float MESH_W      = 0.72;
const float FOV         = 0.90;
const float LW          = 0.004;
const float VERT_SPREAD = 1.20; // rampa Y: 0.0=piatto, 1.2=default, 2.0=verticale esagerato
const float DISP_Y      = 0.50; // displacement audio (vedi tuning.md)

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

float distSeg(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b-a;
    return length(p-a-clamp(dot(p-a,ab)/(dot(ab,ab)+1e-5),0.0,1.0)*ab);
}

// Proiezione con rotazione Y-axis NavPad (uBending.x)
vec2 proj(vec3 p) {
    float angle = uBending.x * 0.55; // max ~31° rotazione
    float cosA  = cos(angle);
    float sinA  = sin(angle);
    // Ruota intorno al centro della mesh (z = MESH_D/2)
    float dz = p.z - MESH_D * 0.5;
    float rx  = p.x * cosA - dz * sinA;
    float rz  = dz * cosA + p.x * sinA + MESH_D * 0.5;
    float dist = max(rz + CAM_DIST, 0.15);
    return vec2(rx, p.y) * (FOV / dist);
}

// Colore LCARS slow-evolving:
// - huePhase: ciclo lento autonomo (~80s) = calma
// - agitation: energia totale istantanea = agitazione
// - energy: energia locale della cella
vec3 lcarsColor(float energy, float zNorm, float huePhase, float agitation) {
    // Fase calma: oscilla tra teal e lavanda
    vec3 calmCol  = mix(COL_TEAL, COL_LAVEND, huePhase);
    // Fase attiva: atomic → bianco
    float tPeak   = clamp((agitation - 0.45) * 3.0, 0.0, 1.0);
    vec3  hotCol  = mix(COL_ATOMIC, COL_WHITE, tPeak);
    // Blend locale: energia della cella guida transizione calma→caldo
    float tLocal  = clamp(energy * 4.5 + agitation * 1.8, 0.0, 1.0);
    vec3  col     = mix(calmCol, hotCol, tLocal);
    // Z-depth: righe lontane più scure/fredde
    col = mix(col, COL_DEEP, zNorm * 0.40);
    return col;
}

void main() {
    vec2  fc  = FlutterFragCoord().xy;
    float asp = uResolution.x / uResolution.y;
    vec2  uv  = (fc / uResolution - 0.5) * vec2(asp, 1.0);

    // ── Energia globale (calma/agitazione) ───────────────────────────────────
    float totalE = (dot(uAudioBand0,vec4(0.25)) + dot(uAudioBand1,vec4(0.25))
                  + dot(uAudioBand2,vec4(0.25)) + dot(uAudioBand3,vec4(0.25))
                  + dot(uAudioBand4,vec4(0.25)) + dot(uAudioBand5,vec4(0.25))
                  + dot(uAudioBand6,vec4(0.25)) + dot(uAudioBand7,vec4(0.25))) / 8.0;

    // Ciclo lento autonomo palette ~80s (calma = colori freddi oscillanti)
    float huePhase = sin(uTime * 0.079) * 0.5 + 0.5;

    // Calcoli invarianti
    float fCols   = float(COLS);
    float fRows   = float(ROWS);
    float tiltAmt = sin(uTime * 0.12) * 0.05;

    float accumR = 0.0, accumG = 0.0, accumB = 0.0, accumW = 0.0;

    for (int row = 0; row < ROWS; row++) {
        float nz0 = float(row)     / fRows;
        float nz1 = float(row + 1) / fRows;
        float z0  = nz0 * MESH_D;
        float z1  = nz1 * MESH_D;

        float zFade = 1.0 - smoothstep(MESH_D * 0.55, MESH_D * 0.90, z0);
        if (zFade < 0.02) continue;

        // ── RAMPA VERTICALE: fronte basso, retro alto ─────────────────────────
        // Questo è il fix principale per l'appiattimento verticale.
        // Offset Y: row 0 (front) → basso, row ROWS-1 (back) → alto
        float yBase0 = (nz0 - 0.25) * VERT_SPREAD + uBending.y * 0.25;
        float yBase1 = (nz1 - 0.25) * VERT_SPREAD + uBending.y * 0.25;

        float wave0  = sin(uTime * 0.65 + z0 * 2.4) * 0.025;
        float wave1  = sin(uTime * 0.65 + z1 * 2.4) * 0.025;
        float tilt0  = z0 * tiltAmt;
        float tilt1  = z1 * tiltAmt;

        for (int col = 0; col < COLS; col++) {
            float nx0 = float(col)     / fCols;
            float nx1 = float(col + 1) / fCols;

            float xw0 = (nx0 * 2.0 - 1.0) * MESH_W;
            float xw1 = (nx1 * 2.0 - 1.0) * MESH_W;

            float sym0 = 1.0 - abs(nx0 * 2.0 - 1.0);
            float sym1 = 1.0 - abs(nx1 * 2.0 - 1.0);
            float d0   = audioBandAt(sym0) * DISP_Y;
            float d1   = audioBandAt(sym1) * DISP_Y;

            vec2 p00 = proj(vec3(xw0, d0 + yBase0 + wave0 + tilt0, z0));
            vec2 p10 = proj(vec3(xw1, d1 + yBase0 + wave0 + tilt0, z0));
            vec2 p01 = proj(vec3(xw0, d0 + yBase1 + wave1 + tilt1, z1));
            vec2 p11 = proj(vec3(xw1, d1 + yBase1 + wave1 + tilt1, z1));

            float energy = (d0 + d1) * 0.5;

            float dG = min(distSeg(uv, p00, p10), distSeg(uv, p00, p01));
            float dB = dG;
            float dR = dG;

            if (row == ROWS-1) dG = min(dG, distSeg(uv, p01, p11));
            if (col == COLS-1) dG = min(dG, distSeg(uv, p10, p11));
            dR = dG; dB = dG;

            float line = smoothstep(LW, LW * 0.15, dG);

            vec3 col3 = lcarsColor(energy / DISP_Y, nz0, huePhase, totalE);

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

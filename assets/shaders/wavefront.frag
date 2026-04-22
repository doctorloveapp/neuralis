#include <flutter/runtime_effect.glsl>

// Neuralis — Neural Wavefront Engine
// Placeholder — sarà implementato nella Sezione 4

uniform float uTime;
uniform vec2 uResolution;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;
  fragColor = vec4(0.0, 0.0, 0.0, 0.0);
}

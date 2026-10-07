#version 450
#extension GL_GOOGLE_include_directive : require

#include <shadertoy.glsl>
#include <noise.glsl>

float sdf_circle(vec2 p, float r)     { return length(p) - r; }
float op_subtract(float d1, float d2) { return max(d1, -d2); }

// crescent: a disc with a slightly smaller, shifted disc taken out
float sdf_moon(vec2 p, float r) {
  return op_subtract(sdf_circle(p, r), sdf_circle(p - vec2(0.35 * r, 0.15 * r), 0.85 * r));
}

// ridge line of mountain layer i (0 = far, 2 = near), in p units
float ridge(float x, float i) {
  float speed = 0.02 + 0.05 * i;   // nearer layers scroll faster: parallax
  float freq  = 0.8 + 0.6 * i;     // nearer layers are more jagged
  float h = fbm(vec2(x * freq + iTime * speed + 5.0, 13.7 * i + 3.0), u.octaves);
  return (-0.05 - 0.30 * i) + (0.60 - 0.07 * i) * h;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 p = (2.0 * fragCoord - iResolution.xy) / iResolution.y;   // y up, as in ShaderToy

  // sky: deep blue overhead, warm at the horizon
  vec3 col = mix(vec3(0.05, 0.06, 0.18), vec3(0.45, 0.25, 0.35), smoothstep(0.8, -0.6, p.y));

  // stars: one hash per 3x3-pixel cell, 0.4% of cells lit, each twinkling at its own phase
  uvec2 cell  = uvec2(ivec2(floor(fragCoord / 3.0)) + 1000);
  float s     = hash(cell);
  float phase = hash(cell + uvec2(7u, 0u)) * 6.2831853;
  col += step(0.996, s) * (0.6 + 0.4 * sin(iTime * 3.0 + phase));

  // moon: follows the mouse while the button is held, drifts on its own otherwise
  vec2 mc = (iMouse.z > 0.0) ? (2.0 * iMouse.xy - iResolution.xy) / iResolution.y
                             : vec2(-0.6 + 0.10 * sin(0.3 * iTime), 0.55 + 0.05 * cos(0.3 * iTime));
  float dm = sdf_moon(p - mc, 0.18);
  float wm = fwidth(dm);
  col += vec3(0.9, 0.85, 0.6) * 0.25 * exp(-8.0 * max(dm, 0.0));      // glow
  col  = mix(col, vec3(1.0, 0.96, 0.82), smoothstep(wm, -wm, dm));    // disc

  // mountains, painted far to near so nearer layers cover farther ones
  int   id     = 0;
  float dFront = 0.0;
  for (int i = 0; i < 3; ++i) {
    float fi = float(i);
    float d  = p.y - ridge(p.x, fi);          // < 0 below the ridge
    float w  = fwidth(d);
    vec3  lc = mix(vec3(0.33, 0.36, 0.52), vec3(0.03, 0.04, 0.08), fi / 2.0);   // haze: far is lighter
    col = mix(col, lc, smoothstep(w, -w, d));
    if (d < 0.0) id = i + 1;
    dFront = d;
  }

  // debug views
  if      (iMode == 1u) col = (dm < 0.0 ? vec3(1.0, 0.6, 0.3) : vec3(0.4, 0.6, 1.0)) * fract(dm * 10.0);
  else if (iMode == 2u) col = vec3(clamp(dFront * 0.5 + 0.5, 0.0, 1.0));
  else if (iMode == 3u) col = vec3(float(id) / 3.0);

  fragColor = vec4(col, 1.0);
}
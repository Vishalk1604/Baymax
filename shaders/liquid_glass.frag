// =============================================================================
// Liquid glass — single-pass backdrop refraction shader.
//
// Used as `ImageFilter.shader` inside a BackdropFilter, so:
//   * sampler 0 is the backdrop, and floats 0–1 (uSize) are its size; Flutter
//     sets both.
//   * FlutterFragCoord() is in global physical pixels.
//   * On OpenGLES the backdrop texture is upside down.
//
// Up to three rounded rectangles are merged with a smooth minimum, so shapes
// that come close flow together like liquid (tab-bar droplet, touch bulges).
// The surface is modelled as a lens: flat in the middle, curving down over
// `bevel` pixels at the rim. That curvature bends the backdrop (refraction),
// splits colour slightly at the rim (dispersion) and catches two lights.
// Geometry is analytic, with no offscreen passes, so it runs on both Impeller
// backends (Vulkan and OpenGLES).
// =============================================================================
#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;     // backdrop size in physical px (set by Flutter)
uniform vec4 uShapeA;   // x, y, w, h — global physical px
uniform vec4 uShapeB;
uniform vec4 uShapeC;
uniform vec4 uRadii;    // corner radius A, B, C (px), shape count
uniform vec4 uGlass;    // bevel (px), refraction (px), dispersion (0..1), blend (px)
uniform vec4 uLight;    // angle to light (rad), specular (0..1), rim width (px), sheen (0..1)
uniform vec4 uTint;     // rgb + strength (straight alpha)
uniform vec4 uMisc;     // saturation, edge anti-alias (px), brightness, shadow (0..1)
uniform vec4 uFrost;    // frost radius (px); y, z, w unused

uniform sampler2D uTexture;

out vec4 fragColor;

float sdRoundRect(vec2 p, vec4 rect, float radius) {
  vec2 halfSize = rect.zw * 0.5;
  vec2 q = abs(p - (rect.xy + halfSize)) - halfSize;
  float r = min(radius, min(halfSize.x, halfSize.y));
  q += r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Polynomial smooth minimum: merges two distance fields with a fillet of k px.
float smin(float a, float b, float k) {
  if (k <= 0.0) return min(a, b);
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

float scene(vec2 p) {
  float d = sdRoundRect(p, uShapeA, uRadii.x);
  if (uRadii.w > 1.5) d = smin(d, sdRoundRect(p, uShapeB, uRadii.y), uGlass.w);
  if (uRadii.w > 2.5) d = smin(d, sdRoundRect(p, uShapeC, uRadii.z), uGlass.w);
  return d;
}

vec3 backdrop(vec2 px) {
  vec2 uv = clamp(px / uSize, vec2(0.0), vec2(1.0));
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uTexture, uv).rgb;
}

// Frosted glass without a separate blur pass: a blur composed with this
// filter hands the shader a cropped texture, which breaks the global
// coordinate mapping. 17 taps on a golden-angle (Vogel) disc.
vec3 frosted(vec2 px, float radius) {
  vec3 sum = backdrop(px);
  for (int i = 1; i <= 16; i++) {
    float fi = float(i);
    float r = radius * sqrt(fi / 16.0);
    float a = fi * 2.39996323;
    sum += backdrop(px + vec2(cos(a), sin(a)) * r);
  }
  return sum / 17.0;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float d = scene(p);

  float aa = max(uMisc.y, 0.5);
  float coverage = clamp(0.5 - d / aa, 0.0, 1.0);
  if (coverage <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  // Outward normal of the (merged) shape from the distance-field gradient.
  vec2 grad = vec2(scene(p + vec2(1.0, 0.0)) - scene(p - vec2(1.0, 0.0)),
                   scene(p + vec2(0.0, 1.0)) - scene(p - vec2(0.0, 1.0)));
  float gl = length(grad);
  vec2 n = gl > 1e-4 ? grad / gl : vec2(0.0);

  // Lens profile: 0 deep inside, rising to 1 at the rim along a circular bevel.
  float bevel = max(uGlass.x, 1.0);
  float inside = clamp(-d / bevel, 0.0, 1.0);
  float edge = 1.0 - inside;
  float slope = edge * edge;

  // Refraction pulls samples inward near the rim; dispersion fans the
  // channels apart a little so the rim picks up a faint spectrum.
  vec2 disp = -n * slope * uGlass.y;
  vec3 col;
  if (uFrost.x > 0.5) {
    col = frosted(p + disp, uFrost.x);
  } else if (uGlass.z > 0.001) {
    col.r = backdrop(p + disp * (1.0 + uGlass.z)).r;
    col.g = backdrop(p + disp).g;
    col.b = backdrop(p + disp * (1.0 - uGlass.z)).b;
  } else {
    col = backdrop(p + disp);
  }

  // Glass reads a touch clearer and more saturated than what's behind it.
  float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
  col = mix(vec3(lum), col, uMisc.x) * uMisc.z;
  col = mix(col, uTint.rgb, uTint.a);

  // Soft contact darkening just inside the rim on the side away from the
  // light, which gives the slab some thickness.
  vec2 toLight = vec2(cos(uLight.x), sin(uLight.x));
  float facing = dot(n, toLight);
  float rimBand = 1.0 - smoothstep(0.0, max(uLight.z, 0.5), -d);
  col *= 1.0 - uMisc.w * rimBand * max(-facing, 0.0) * 0.35;

  // Specular rim: a bright key light and a dimmer bounce on the far edge.
  float spec = rimBand * (pow(max(facing, 0.0), 2.5) + 0.4 * pow(max(-facing, 0.0), 2.5));
  // Broad top sheen over the body of the first shape.
  float sheenT = clamp((p.y - uShapeA.y) / max(uShapeA.w, 1.0), 0.0, 1.0);
  float sheen = uLight.w * (1.0 - sheenT) * (1.0 - sheenT) * 0.12;
  col += vec3(spec * uLight.y + sheen + slope * 0.06);

  col = clamp(col, 0.0, 1.0);
  fragColor = vec4(col * coverage, coverage);
}

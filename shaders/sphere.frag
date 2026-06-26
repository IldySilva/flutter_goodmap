#version 460 core

#include <flutter/runtime_effect.glsl>

out vec4 fragColor;

// Float uniforms must precede samplers.
uniform float uResolutionX;
uniform float uResolutionY;
uniform float uCenterX;
uniform float uCenterY;
uniform float uRadius;
uniform float uRotationX;   // latitude facing the viewer (radians)
uniform float uRotationZ;   // longitude facing the viewer (radians)
uniform float uDetailMinLon;
uniform float uDetailMaxLon;
uniform float uDetailMinLat;
uniform float uDetailMaxLat;
uniform float uHasDetail;
// Day/night terminator uniforms (indices 12-15).
uniform float uSunDirX;       // Sun direction in geographic coords (X)
uniform float uSunDirY;       // Sun direction in geographic coords (Y)
uniform float uSunDirZ;       // Sun direction in geographic coords (Z)
uniform float uEnableDayNight; // 1.0 = enabled, 0.0 = disabled

uniform sampler2D uTexture;       // base world atlas
uniform sampler2D uDetailTexture;  // high-res detail atlas

const float PI = 3.14159265359;
const float TWO_PI = 6.28318530718;
const float HALF_PI = 1.57079632679;

// Matches SphereProjection._rotateZ / _rotateY exactly.
vec3 rotZ(vec3 p, float a) {
  float c = cos(a);
  float s = sin(a);
  return vec3(c * p.x - s * p.y, s * p.x + c * p.y, p.z);
}

vec3 rotY(vec3 p, float a) {
  float c = cos(a);
  float s = sin(a);
  return vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 pos = fragCoord - vec2(uCenterX, uCenterY);

  float dist = length(pos);

  // Anti-aliased edge.
  float edgeWidth = 1.5;
  float edgeAlpha = 1.0 - smoothstep(uRadius - edgeWidth, uRadius + edgeWidth * 0.5, dist);
  if (edgeAlpha <= 0.001) {
    fragColor = vec4(0.0);
    return;
  }

  // Clamp to just inside the sphere for a stable depth at the rim.
  float effDist = min(dist, uRadius - 0.5);
  float depth = sqrt(max(0.0, uRadius * uRadius - effDist * effDist));
  vec2 effPos = pos;
  if (dist > effDist) {
    effPos = pos * (effDist / dist);
  }

  // Screen -> sphere point (x = depth toward viewer, y = screenX, z = -screenY).
  vec3 spherePoint = vec3(depth, effPos.x, -effPos.y);

  // Inverse rotation (matches SphereProjection._applyInverseRotation):
  // rotateY(-rotationX) then rotateZ(+rotationZ).
  vec3 v = rotZ(rotY(spherePoint, -uRotationX), uRotationZ);

  float lat = asin(clamp(v.z / uRadius, -1.0, 1.0));
  float lon = atan(v.y, v.x);

  vec4 color;
  bool useDetail = false;
  if (uHasDetail > 0.5) {
    bool inLat = (lat >= uDetailMinLat && lat <= uDetailMaxLat);
    bool inLon = uDetailMaxLon >= uDetailMinLon
        ? (lon >= uDetailMinLon && lon <= uDetailMaxLon)
        : (lon >= uDetailMinLon || lon <= uDetailMaxLon);
    if (inLat && inLon) {
      useDetail = true;
      vec2 detailUv;
      float diff = lon - uDetailMinLon;
      if (diff < 0.0) {
        diff += TWO_PI;
      }
      float span = uDetailMaxLon - uDetailMinLon;
      if (span < 0.0) {
        span += TWO_PI;
      }
      detailUv.x = diff / span;
      detailUv.y = (uDetailMaxLat - lat) / (uDetailMaxLat - uDetailMinLat);
      color = texture(uDetailTexture, detailUv);
    }
  }

  if (!useDetail) {
    vec2 uv;
    uv.x = (lon + PI) / TWO_PI;     // -180..180 -> 0..1
    uv.y = (HALF_PI - lat) / PI;    // 90..-90 -> 0..1
    color = texture(uTexture, uv);
  }

  // Day / Night Terminator ------------------------------------------------
  // Darkens the night side of the globe based on the solar angle.
  // uSunDir is the sun's unit direction in geographic (earth-centred) coords:
  //   x = cos(decl)*cos(subLon), y = cos(decl)*sin(subLon), z = sin(decl)
  if (uEnableDayNight > 0.5) {
    // Surface normal at (lat, lon) in geographic coords.
    vec3 surfaceNormal = vec3(cos(lat) * cos(lon),
                              cos(lat) * sin(lon),
                              sin(lat));
    vec3 sunDir = normalize(vec3(uSunDirX, uSunDirY, uSunDirZ));
    float dotSun = dot(surfaceNormal, sunDir);

    // Smooth twilight band (~11 degrees wide either side of the terminator).
    float daylight = smoothstep(-0.11, 0.11, dotSun);

    // 20% ambient on the night side so landmasses are still faintly visible.
    color.rgb *= (0.20 + 0.80 * daylight);
  }

  // Premultiplied alpha for clean compositing at the AA edge.
  color.rgb *= edgeAlpha;
  color.a *= edgeAlpha;
  fragColor = color;
}

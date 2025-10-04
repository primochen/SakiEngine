#version 460 core
#include <flutter/runtime_effect.glsl>

uniform float progress;
uniform vec2 uSize;
uniform vec2 u_imageFrom_dimensions;
uniform vec2 u_imageTo_dimensions;
uniform vec2 uOffset;
uniform sampler2D imageFrom;
uniform sampler2D imageTo;
uniform float overallAlpha;

out vec4 fragColor;

void main() {
    vec2 uv = (FlutterFragCoord().xy - uOffset) / uSize;

    // --- Bilinear filtering for imageFrom ---
    vec2 from_texSize = u_imageFrom_dimensions;
    vec2 from_texelSize = 1.0 / from_texSize;
    vec2 from_f = fract(uv * from_texSize);

    vec4 from_t00 = texture(imageFrom, uv);
    vec4 from_t10 = texture(imageFrom, uv + vec2(from_texelSize.x, 0.0));
    vec4 from_t01 = texture(imageFrom, uv + vec2(0.0, from_texelSize.y));
    vec4 from_t11 = texture(imageFrom, uv + vec2(from_texelSize.x, from_texelSize.y));

    vec4 from_interpX1 = mix(from_t00, from_t10, from_f.x);
    vec4 from_interpX2 = mix(from_t01, from_t11, from_f.x);
    vec4 from_color = mix(from_interpX1, from_interpX2, from_f.y);

    // --- Bilinear filtering for imageTo ---
    vec2 to_texSize = u_imageTo_dimensions;
    vec2 to_texelSize = 1.0 / to_texSize;
    vec2 to_f = fract(uv * to_texSize);

    vec4 to_t00 = texture(imageTo, uv);
    vec4 to_t10 = texture(imageTo, uv + vec2(to_texelSize.x, 0.0));
    vec4 to_t01 = texture(imageTo, uv + vec2(0.0, to_texelSize.y));
    vec4 to_t11 = texture(imageTo, uv + vec2(to_texelSize.x, to_texelSize.y));
    
    vec4 to_interpX1 = mix(to_t00, to_t10, to_f.x);
    vec4 to_interpX2 = mix(to_t01, to_t11, to_f.x);
    vec4 to_color = mix(to_interpX1, to_interpX2, to_f.y);

    fragColor = mix(from_color, to_color, progress) * overallAlpha;
}

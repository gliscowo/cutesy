#version 330 core

uniform sampler2D uInput;
uniform vec2 uInputResolution;

uniform float uDirections;
uniform float uQuality;
uniform float uSize;

in vec4 vColor;
out vec4 fragColor;

// shader adapted from https://www.shadertoy.com/view/Xltfzj

void main() {
    #define TAU 6.28318530718

    vec2 Radius = uSize / uInputResolution.xy;

    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = gl_FragCoord.xy / uInputResolution.xy;
    // Pixel colour
    vec4 color = texture(uInput, uv);

    // Blur calculations
    for (float d = 0.0; d < TAU; d += TAU / uDirections) {
        for (float i = 1.0 / uQuality; i <= 1.0; i += 1.0 / uQuality) {
            color += texture(uInput, uv + vec2(cos(d), sin(d)) * Radius * i);
        }
    }

    // Output to screen
    fragColor = (color / (uQuality * uDirections)) * vColor;
}

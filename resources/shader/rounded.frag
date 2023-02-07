// shader adapted from https://www.shadertoy.com/view/WtdSDs

#version 330 core

uniform vec2 uLocation;
uniform vec2 uSize;
uniform float uRadius;

in vec4 vColor;
out vec4 fragColor;

float roundedBoxSDF(vec2 CenterPosition, vec2 Size, float Radius) {
    return length(max(abs(CenterPosition) - Size + Radius, 0.0)) - Radius;
}

void main() {
    float distance = roundedBoxSDF(gl_FragCoord.xy - vec2(0, 0.5) - uLocation - (uSize / 2.0), (uSize - 2) / 2.0, uRadius);
    float smoothedAlpha = 1.0 - smoothstep(0.0, 2.0, distance);

    fragColor = vec4(vColor.rgb, vColor.a * smoothedAlpha);
}
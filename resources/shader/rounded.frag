#version 330 core

uniform vec2 uLocation;
uniform vec2 uSize;
uniform float uRadius;

in vec4 vColor;
out vec4 fragColor;

// from https://iquilezles.org/articles/distfunctions
float roundedBoxSDF(vec2 CenterPosition, vec2 Size, float Radius) {
    return length(max(abs(CenterPosition)-Size+Radius,0.0))-Radius;
}

void main() {
    float distance = roundedBoxSDF(gl_FragCoord.xy - 1 - uLocation - ((uSize - 2) / 2.0f), (uSize - 2) / 2.0f, uRadius);

    float smoothedAlpha = 1.0f - smoothstep(0.0f, 2.0f, distance);
    fragColor = vec4(vColor.rgb, vColor.a * smoothedAlpha);
}
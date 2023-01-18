#version 330 core

in vec2 texCoords;
in vec3 textColor;

layout(location = 0, index = 0) out vec4 fragColor;
layout(location = 0, index = 1) out vec4 fragColorMask;

uniform sampler2D sText;

void main() {
    fragColor = vec4(textColor, 1);
    fragColorMask = vec4(texture(sText, texCoords));
}
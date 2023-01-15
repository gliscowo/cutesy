#version 330 core

in vec2 texCoords;
in vec3 textColor;

out vec4 FragColor;

uniform sampler2D sText;

void main()
{
    FragColor = vec4(textColor, texture(sText, texCoords).r);
}
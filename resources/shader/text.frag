#version 330 core

in vec2 TexCoords;
out vec4 color;

uniform sampler2D sText;
uniform vec3 uTextColor;

void main()
{
    color = vec4(uTextColor, texture(sText, TexCoords).r);
}
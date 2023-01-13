#version 330 core

in vec2 TexCoords;
out vec4 FragColor;

uniform sampler2D sText;
uniform vec3 uTextColor;

void main()
{
    FragColor = vec4(uTextColor, texture(sText, TexCoords).r);
}
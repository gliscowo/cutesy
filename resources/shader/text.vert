#version 330 core

in vec4 aVertex; // <vec2 pos, vec2 tex>
out vec2 TexCoords;

uniform mat4 uProjection;

void main()
{
    gl_Position = uProjection * vec4(aVertex.xy, 0.0, 1.0);
    TexCoords = aVertex.zw;
}
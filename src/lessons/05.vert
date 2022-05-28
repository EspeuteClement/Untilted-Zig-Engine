#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aOffset;
layout (location = 2) in vec2 aSize;
layout (location = 3) in vec2 aUV0;
layout (location = 4) in vec2 aUV1;

uniform mat4 uCamera;

out vec2 fUV;

void main()
{
    gl_Position = uCamera * vec4(aPos * aSize + aOffset, 0.0, 1.0);
    fUV = mix(aUV0, aUV1, aPos);
}
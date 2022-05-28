#version 330 core
out vec4 FragColor;

in vec2 fUV;

void main()
{
    FragColor = vec4(fUV.x,fUV.y, fUV.y, 1.0);
}
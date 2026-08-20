#version 450

layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 color;

layout(binding = 2) uniform sampler2D sourceTexture;
layout(binding = 9, std140) uniform PixelData {
   vec4 tint;
};
uniform float exposure;

void main()
{
   color = texture(sourceTexture, uv) * tint * exposure;
}

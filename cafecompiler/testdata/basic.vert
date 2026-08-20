#version 450

layout(location = 0) in vec2 position;
layout(location = 5) in vec2 offset;
layout(location = 0) out vec2 uv;

layout(binding = 4, std140) uniform VertexData {
   vec4 scale;
};

void main()
{
   uv = position;
   gl_Position = vec4(position * scale.xy + offset, 0.0, 1.0);
}

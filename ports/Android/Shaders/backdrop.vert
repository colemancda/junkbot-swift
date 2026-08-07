#version 450
// Textured-quad pipeline (backdrop image, background/foreground decals, Junkbot's chest emblem) -
// counterpart of `Metal3DShaderSource.swift`'s `backdrop_vertex_main`. Positions arrive already in
// world space (built on the CPU each draw, same as the Metal path's `drawTexturedQuad`), so
// `modelViewProjection` here is really just the camera's view-projection.

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inUV;

layout(location = 0) out vec2 outUV;

layout(binding = 0) uniform Uniforms {
    mat4 modelViewProjection;
} uniforms;

void main() {
    gl_Position = uniforms.modelViewProjection * vec4(inPosition, 1.0);
    outUV = inUV;
}

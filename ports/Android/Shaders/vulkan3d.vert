#version 450
// Main entity/brick pipeline vertex shader - counterpart of `Metal3DShaderSource.swift`'s
// `vertex_main`. Positions/normals arrive already baked into *world* space (see
// `Vulkan3DManager.swift`'s doc comment, same CPU-side approach `Metal3DManager.swift` uses), so
// `viewProjection` is the only transform left to apply here.

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec4 inColor;

layout(location = 0) out vec3 outNormal;
layout(location = 1) out vec4 outColor;

layout(binding = 0) uniform Uniforms {
    mat4 viewProjection;
} uniforms;

void main() {
    gl_Position = uniforms.viewProjection * vec4(inPosition, 1.0);
    outNormal = inNormal;
    outColor = inColor;
}

#version 450
// Counterpart of `Metal3DShaderSource.swift`'s `backdrop_fragment_main` - plain texture sample, no
// lighting (matches `Scene3DManager`'s `.constant`-lit, ambient-zeroed backdrop material: shows
// the image's exact pixel colors).

layout(location = 0) in vec2 inUV;
layout(location = 0) out vec4 outColor;

layout(binding = 1) uniform sampler2D tex;

void main() {
    outColor = texture(tex, inUV);
}

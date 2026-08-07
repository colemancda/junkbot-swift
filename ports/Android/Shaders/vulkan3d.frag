#version 450
// Lighting ported from the same source `Metal3DShaderSource.swift`'s `fragment_main` documents:
// the original JS reference's own three.js scene setup (`three-stuff/3d-main.js`'s `setupScene`,
// ~line 107) - `THREE.AmbientLight(0xdedede, 0.8)` added flatly, `THREE.DirectionalLight(0xffffff,
// 0.8)` at `(-1000, 3200, 1500)` (aimed at the origin) scaled by `N.L`. Kept in sync with that
// file if the reference lighting ever changes - see its doc comment for the full rationale
// (matches `SceneBuilder.swift`'s SceneKit port of the same light; no per-part roughness/
// metalness term, since the baked vertex format carries no material data, same simplification
// `LDrawMSLSource.swift`/`Metal3DShaderSource.swift` both already made).

layout(location = 0) in vec3 inNormal;
layout(location = 1) in vec4 inColor;

layout(location = 0) out vec4 outColor;

void main() {
    vec3 sunDirection = normalize(vec3(-1000.0, 3200.0, 1500.0));
    vec3 ambientColor = vec3(0xde, 0xde, 0xde) / 255.0 * 0.8;
    vec3 sunColor = vec3(1.0, 1.0, 1.0) * 0.8;

    vec3 n = normalize(inNormal);
    float ndotl = max(dot(n, sunDirection), 0.0);
    vec3 light = ambientColor + sunColor * ndotl;

    outColor = vec4(inColor.rgb * light, inColor.a);
}

#if canImport(Metal)
/// Lighting ported from the original JS reference's own three.js scene setup
/// (`three-stuff/3d-main.js`'s `setupScene`, ~line 107): `THREE.AmbientLight(0xdedede, 0.8)` plus
/// `THREE.DirectionalLight(0xffffff, 0.8)` positioned at `(-1000, 3200, 1500)` (aimed at the
/// origin, matching `tools/Junkbot3D/Sources/Junkbot3D/SceneBuilder.swift`'s SceneKit port of the
/// same light, and this file's `sunDirection` below). three.js's (non-"physically correct") light
/// model adds the ambient term flatly and multiplies the directional term by `N·L` - reproduced
/// exactly here (`ambient + directional * NdotL`) rather than the two made-up "key/fill" terms
/// this shader used before, which had no reference behind their weights. `LDrawLoader.js`'s solid-
/// part materials also carry `roughness`/`metalness` (a real PBR specular term) - not reproduced
/// here, since the baked vertex format (`Metal3DVertex`) only carries position/normal/color, no
/// per-part material data; this stays a pure Lambertian diffuse term, same simplification the
/// original (pre-Metal) `LDrawMSLSource.swift` this file replaced also made.
///
/// Vertex positions/normals arriving here are already in *world* space (baked in by
/// `Metal3DManager` on the CPU each frame, since every entity needs its own transform but this
/// pipeline draws one combined vertex buffer per frame - see that file's doc comment) - `uniforms`
/// only carries the camera's view-projection matrix, and `normalMatrix` is passed as identity.
let Metal3DShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float4 color    [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldNormal;
    float4 color;
};

struct Uniforms {
    float4x4 modelViewProjection;
    float4x4 normalMatrix;
};

vertex VertexOut vertex_main(
    VertexIn in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    VertexOut out;
    out.position = uniforms.modelViewProjection * float4(in.position, 1.0);
    out.worldNormal = normalize((uniforms.normalMatrix * float4(in.normal, 0.0)).xyz);
    out.color = in.color;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    // `normalize(lightPosition - origin)`, i.e. the direction *toward* the light - matches
    // `3d-main.js`'s `directionalLight.position.set(-1000, 3200, 1500)` aimed at the scene origin.
    float3 sunDirection = normalize(float3(-1000.0, 3200.0, 1500.0));
    float3 ambientColor = float3(0xde, 0xde, 0xde) / 255.0 * 0.8;
    float3 sunColor = float3(1.0, 1.0, 1.0) * 0.8;

    float3 n = normalize(in.worldNormal);
    float ndotl = max(dot(n, sunDirection), 0.0);
    float3 light = ambientColor + sunColor * ndotl;

    float3 rgb = in.color.rgb * light;
    return float4(rgb, in.color.a);
}

// A small, separate textured-quad pipeline for the level backdrop image - the shared triangle
// pipeline above only carries per-vertex color, no UV, so the backdrop needs its own tiny shader
// rather than extending the vendored one. Matches `Scene3DManager`'s `.constant`-lit, ambient-
// zeroed backdrop material: shows the image's exact pixel colors, unaffected by scene lighting.
struct BackdropVertexIn {
    float3 position [[attribute(0)]];
    float2 uv       [[attribute(1)]];
};

struct BackdropVertexOut {
    float4 position [[position]];
    float2 uv;
};

struct BackdropUniforms {
    float4x4 modelViewProjection;
};

vertex BackdropVertexOut backdrop_vertex_main(
    BackdropVertexIn in [[stage_in]],
    constant BackdropUniforms &uniforms [[buffer(1)]]
) {
    BackdropVertexOut out;
    out.position = uniforms.modelViewProjection * float4(in.position, 1.0);
    out.uv = in.uv;
    return out;
}

fragment float4 backdrop_fragment_main(
    BackdropVertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    sampler s [[sampler(0)]]
) {
    return tex.sample(s, in.uv);
}
"""
#endif

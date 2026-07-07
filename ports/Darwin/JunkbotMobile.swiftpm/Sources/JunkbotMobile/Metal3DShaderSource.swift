#if canImport(Metal)
/// Two-directional-light diffuse shading (key 0.75 + fill 0.25 + 0.2 flat ambient) over per-vertex
/// color - copied verbatim from `swift-lego-draw`'s `LDrawMetal` product's `LDrawMSLSource.swift`
/// (not imported as a package dependency: the macOS Xcode target and the iOS `JunkbotMobile.swiftpm`
/// manifest are two separate build graphs, so a copy here avoids wiring a new SwiftPM dependency
/// into both). Vertex positions/normals arriving here are already in *world* space (baked in by
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
    float3 keyDir  = normalize(float3( 1.0,  2.0,  1.5));
    float3 fillDir = normalize(float3(-1.0, -0.5, -1.0));

    float3 n = normalize(in.worldNormal);
    // Weights tuned up from swift-lego-draw's original demo-viewer values (ambient 0.2, key 0.75,
    // fill 0.25): that combination always multiplies the base color by well under 1.0 on most
    // faces (max realistic sum ~1.1, only on a face pointed straight at the key light), so colors
    // read uniformly darker/duller than their true saturation - unlike the SceneKit path's
    // `.physicallyBased` material + strong ambient, which usually lands close to (or above) 1.0.
    // A high flat ambient floor keeps colors close to true almost everywhere; the smaller
    // directional terms add just enough shading for depth cues without darkening the base color
    // much.
    float key    = max(dot(n, keyDir),  0.0) * 0.35;
    float fill   = max(dot(n, fillDir), 0.0) * 0.15;
    float ambient = 0.8;

    float3 rgb = in.color.rgb * (ambient + key + fill);
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

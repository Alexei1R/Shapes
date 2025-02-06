#include <metal_stdlib>
using namespace metal;

struct ModelVertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
    float3 tangent [[attribute(3)]];
    float3 bitangent [[attribute(4)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 normal;
    float2 texCoords;
};

struct Uniforms {
    float4x4 viewProjectionMatrix;
    float4x4 model;
    float time;
};

vertex VertexOut model_vertex_main(
    ModelVertexIn in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    VertexOut out;
    
    float4 worldPosition = uniforms.model * float4(in.position, 1.0);
    out.position = uniforms.viewProjectionMatrix * worldPosition;
    
    // Transform normal to world space
    float3x3 normalMatrix = float3x3(uniforms.model[0].xyz, uniforms.model[1].xyz, uniforms.model[2].xyz);
    out.normal = normalize(normalMatrix * in.normal);
    out.texCoords = in.texCoords;
    
    return out;
}

fragment float4 model_fragment_main(VertexOut in [[stage_in]]) {
    // Simple lighting calculation
    float3 lightDir = normalize(float3(1.0, 1.0, -1.0));
    float3 normal = normalize(in.normal);
    float diffuse = max(0.0, dot(normal, lightDir));
    
    // Base color with simple lighting
    float3 color = float3(0.8, 0.8, 0.8) * (diffuse * 0.7 + 0.3);
    return float4(color, 1.0);
}

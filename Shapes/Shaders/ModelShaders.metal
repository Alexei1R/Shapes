#include <metal_stdlib>
using namespace metal;

struct ModelVertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
    float3 tangent [[attribute(3)]];
    float3 bitangent [[attribute(4)]];
    float4 jointIndices [[attribute(5)]];
    float4 jointWeights [[attribute(6)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 normal;
    float2 texCoords;
    float3 worldPos;
    float3 viewPos;
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
    
    // For now, we'll just use the regular transform without joint influences
    float4 worldPosition = uniforms.model * float4(in.position, 1.0);
    out.position = uniforms.viewProjectionMatrix * worldPosition;
    out.worldPos = worldPosition.xyz;
    
    // Transform normal to world space
    float3x3 normalMatrix = float3x3(uniforms.model[0].xyz,
                                    uniforms.model[1].xyz,
                                    uniforms.model[2].xyz);
    out.normal = normalize(normalMatrix * in.normal);
    out.texCoords = in.texCoords;
    
    // Calculate view space position for lighting
    float4 viewPos = uniforms.viewProjectionMatrix * worldPosition;
    out.viewPos = viewPos.xyz / viewPos.w;
    
    return out;
}

fragment float4 model_fragment_main(VertexOut in [[stage_in]]) {
    // Lighting parameters
    float3 lightPos = float3(10.0, 500.0, -500.0);
    float3 lightColor = float3(1.0, 1.0, 1.0);
    float3 baseColor = float3(0.7, 0.7, 0.7);
    
    // Ambient
    float3 ambient = baseColor * 0.2;
    
    // Diffuse
    float3 normal = normalize(in.normal);
    float3 lightDir = normalize(lightPos - in.worldPos);
    float diff = max(dot(normal, lightDir), 0.0);
    float3 diffuse = baseColor * lightColor * diff;
    
    // Specular
    float3 viewDir = normalize(-in.viewPos);
    float3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32.0);
    float3 specular = lightColor * spec * 0.5;
    
    // Final color
    float3 finalColor = ambient + diffuse + specular;
    
    return float4(finalColor, 1.0);
}

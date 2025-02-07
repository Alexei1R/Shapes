//#include <metal_stdlib>
//using namespace metal;
//
//struct ModelVertexIn {
//    float3 position [[attribute(0)]];
//    float3 normal [[attribute(1)]];
//    float2 texCoords [[attribute(2)]];
//    float3 tangent [[attribute(3)]];
//    float3 bitangent [[attribute(4)]];
//};
//
//struct VertexOut {
//    float4 position [[position]];
//    float3 normal;
//    float2 texCoords;
//    float3 worldPos;  // Added for debugging
//    float3 localPos;  // Added for debugging
//};
//
//struct Uniforms {
//    float4x4 viewProjectionMatrix;
//    float4x4 model;
//    float time;
//};
//
//vertex VertexOut model_vertex_main(
//    ModelVertexIn in [[stage_in]],
//    constant Uniforms &uniforms [[buffer(1)]]
//) {
//    VertexOut out;
//    
//    // Store local position for debugging
//    out.localPos = in.position;
//    
//    // Transform vertices
//    float4 localPos = float4(in.position, 1.0);
//    float4 worldPosition = uniforms.model * localPos;
//    out.worldPos = worldPosition.xyz;  // Store world position for debugging
//    out.position = uniforms.viewProjectionMatrix * worldPosition;
//    
//    // Transform normal to world space
//    float3x3 normalMatrix = float3x3(uniforms.model[0].xyz,
//                                    uniforms.model[1].xyz,
//                                    uniforms.model[2].xyz);
//    out.normal = normalize(normalMatrix * in.normal);
//    out.texCoords = in.texCoords;
//    
//    return out;
//}
//
//fragment float4 model_fragment_main(VertexOut in [[stage_in]]) {
//    // Enhanced visualization for debugging
//    float3 lightDir = normalize(float3(1.0, 1.0, -1.0));
//    float3 normal = normalize(in.normal);
//    float diffuse = max(0.0, dot(normal, lightDir));
//    
//    // Color based on position and normal for debugging
//    float3 positionColor = fract(in.worldPos * 0.5 + 0.5);
//    float3 normalColor = (normal * 0.5) + 0.5;
//    float3 debugColor = mix(positionColor, normalColor, 0.5);
//    
//    // Final color with position and normal visualization
//    float3 finalColor = mix(float3(0.8, 0.8, 0.8), debugColor, 0.7) * (diffuse * 0.7 + 0.3);
//    
//    return float4(finalColor, 1.0);
//}



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
    float3 worldPos;
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
    
    // Transform position
    float4 worldPosition = uniforms.model * float4(in.position, 1.0);
    out.position = uniforms.viewProjectionMatrix * worldPosition;
    out.worldPos = worldPosition.xyz;
    
    // Transform normal to world space
    float3x3 normalMatrix = float3x3(uniforms.model[0].xyz,
                                    uniforms.model[1].xyz,
                                    uniforms.model[2].xyz);
    out.normal = normalize(normalMatrix * in.normal);
    out.texCoords = in.texCoords;
    
    return out;
}



fragment float4 model_fragment_main(VertexOut in [[stage_in]]) {
 
    float3 lightDir = normalize(float3(10.0, 500.0, -500.0));
    float3 lightColor = float3(1.0, 1.0, 1.0);
    float3 baseColor = float3(0.7, 0.7, 0.7); // Gray color for the cube

    float3 ambient = baseColor * 0.2;
    
    float3 normal = normalize(in.normal);
    float diff = max(dot(normal, lightDir), 0.0);
    float3 diffuse = baseColor * lightColor * diff;
    
    float3 viewDir = normalize(float3(0.0, 0.0, -1.0) - in.worldPos);
    float3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32.0);
    float3 specular = lightColor * spec;
    
    // Final color
    float3 finalColor = ambient + diffuse + specular;
    
    return float4(finalColor, 1.0);
}

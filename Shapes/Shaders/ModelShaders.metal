#include <metal_stdlib>
using namespace metal;

struct ModelVertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
    float3 tangent [[attribute(3)]];
    float3 bitangent [[attribute(4)]];
    ushort4 jointIndices [[attribute(5)]];
    float4 jointWeights [[attribute(6)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 normal;
    float2 texCoords;
    float3 worldPos;
    float jointWeight;
    float3 debugJoint; 
};

struct ModelUniforms {
    float4x4 viewProjectionMatrix;
    float4x4 modelMatrix;
    float time;
    int hasAnimation;
    int jointIndex;
};

vertex VertexOut model_vertex_main(
    ModelVertexIn in [[stage_in]],
    constant ModelUniforms &uniforms [[buffer(1)]],
    constant float4x4 *jointMatrices [[buffer(2)]]
) {
    VertexOut out;
    
    // Initialize skinning matrix with identity
    float4x4 skinMatrix = float4x4(1.0);
    float totalWeight = 0.0;
    
    // Calculate skinning matrix with weight normalization
    for(int i = 0; i < 4; i++) {
        uint jointIndex = in.jointIndices[i];
        float weight = in.jointWeights[i];
        if (weight > 0) {
            totalWeight += weight;
            skinMatrix += jointMatrices[jointIndex] * weight;
        }
    }
    
    // Normalize weights if needed
    if (totalWeight > 0) {
        skinMatrix = skinMatrix / totalWeight;
    }
    
    // Apply skinning transformation in model space
    float4 skinnedPosition = skinMatrix * float4(in.position, 1.0);
    
    // Transform to world space
    float4 worldPosition = uniforms.modelMatrix * skinnedPosition;
    out.worldPos = worldPosition.xyz;
    
    // Transform to clip space
    out.position = uniforms.viewProjectionMatrix * worldPosition;
    
    // Transform normal
    float3x3 normalMatrix = float3x3(
        skinMatrix[0].xyz,
        skinMatrix[1].xyz,
        skinMatrix[2].xyz
    );
    float3x3 modelNormalMatrix = float3x3(
        uniforms.modelMatrix[0].xyz,
        uniforms.modelMatrix[1].xyz,
        uniforms.modelMatrix[2].xyz
    );
    out.normal = normalize(modelNormalMatrix * normalMatrix * in.normal);
    
    out.texCoords = in.texCoords;
    out.jointWeight = 0.0;
    
    
    // Get the weight for the selected joint
        float weight = 0.0;
        for (int i = 0; i < 4; i++) {
            if (int(in.jointIndices[i]) == uniforms.jointIndex) {
                weight = in.jointWeights[i];
                break;
            }
        }
        out.jointWeight = weight;
    
    return out;
}

fragment float4 model_fragment_main(VertexOut in [[stage_in]]) {
    // Light properties
    float3 lightPos = float3(2.0, 5.0, 2.0);
    float3 lightColor = float3(1.0);
    float3 baseColor = float3(0.7, 0.7, 0.8);
    
    // Ambient
    float3 ambient = baseColor * 0.2;
    
    // Diffuse
    float3 normal = normalize(in.normal);
    float3 lightDir = normalize(lightPos - in.worldPos);
    float diff = max(dot(normal, lightDir), 0.0);
    float3 diffuse = baseColor * lightColor * diff;
    
    // Final color
    float3 result = ambient + diffuse;
    
    
    // Highlight vertices affected by the selected joint
    float3 jointColor = float3(1.0, 1.0, 0.0); // Red for selected joint
    result = mix(result, jointColor, in.jointWeight);
    
    return float4(result, 1.0);
}

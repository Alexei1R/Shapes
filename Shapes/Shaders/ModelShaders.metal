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
    float3 viewPos;
    float jointWeight;
};

struct Uniforms {
    float4x4 viewProjectionMatrix;
    float4x4 model;
    float time;
    int jointIndex;
};

constant int MAX_JOINTS = 64;

vertex VertexOut model_vertex_main(
    ModelVertexIn in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]],
    constant float4x4 *jointMatrices [[buffer(2)]]
) {
    VertexOut out;
    
    // Calculate skinning matrix
    float4x4 skinMatrix = float4x4(0.0);
    for(int i = 0; i < 4; i++) {
        int jointIndex = in.jointIndices[i];
        float weight = in.jointWeights[i];
        skinMatrix += jointMatrices[jointIndex] * weight;
    }
    
    // Apply skinning
    float4 skinnedPosition = skinMatrix * float4(in.position, 1.0);
    float4 worldPosition = uniforms.model * skinnedPosition;
    out.position = uniforms.viewProjectionMatrix * worldPosition;
    out.worldPos = worldPosition.xyz;
    
    // Transform normal by skinning matrix
    float3x3 normalMatrix = float3x3(
        normalize(skinMatrix[0].xyz),
        normalize(skinMatrix[1].xyz),
        normalize(skinMatrix[2].xyz)
    );
    out.normal = normalize(normalMatrix * in.normal);
    out.texCoords = in.texCoords;
    
    float4 viewPos = uniforms.viewProjectionMatrix * worldPosition;
    out.viewPos = viewPos.xyz / viewPos.w;
    
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
    float3 lightPos = float3(0.0, 5.0, 5.0);
    float3 lightColor = float3(1.0, 1.0, 1.0);
    float3 baseColor = float3(0.7, 0.7, 0.7);
    
    float3 ambient = baseColor * 0.2;
    
    float3 normal = normalize(in.normal);
    float3 lightDir = normalize(lightPos - in.worldPos);
    float diff = max(dot(normal, lightDir), 0.0);
    float3 diffuse = baseColor * lightColor * diff;
    
    float3 viewDir = normalize(-in.viewPos);
    float3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32.0);
    float3 specular = lightColor * spec * 0.5;
    
    float3 finalColor = ambient + diffuse + specular;
    
    // Highlight vertices affected by the selected joint
    float3 jointColor = float3(1.0, 0.0, 0.0); // Red for selected joint
    finalColor = mix(finalColor, jointColor, in.jointWeight);
    
    return float4(finalColor, 1.0);
}

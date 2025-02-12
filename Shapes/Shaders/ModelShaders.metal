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

constant int MAX_JOINTS = 65;

vertex VertexOut model_vertex_main(
    ModelVertexIn in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]],
    constant float4x4 *jointMatrices [[buffer(2)]]
) {
    VertexOut out;
    
    // Calculate skinned position
    float4 skinnedPosition = float4(0.0);
    float4 skinnedNormal = float4(0.0);
    
    for(int i = 0; i < 4; i++) {
        int jointIndex = int(in.jointIndices[i]);
        float weight = in.jointWeights[i];
        
        if(jointIndex >= 0 && jointIndex < MAX_JOINTS && weight > 0.0) {
            float4x4 jointMatrix = jointMatrices[jointIndex];
            skinnedPosition += (jointMatrix * float4(in.position, 1.0)) * weight;
            skinnedNormal += (jointMatrix * float4(in.normal, 0.0)) * weight;
        }
    }
    
    // Ensure w component is 1.0 for position
    skinnedPosition.w = 1.0;
    
    float4 worldPosition = uniforms.model * skinnedPosition;
    out.position = uniforms.viewProjectionMatrix * worldPosition;
    out.worldPos = worldPosition.xyz;
    
    float3x3 normalMatrix = float3x3(uniforms.model[0].xyz,
                                   uniforms.model[1].xyz,
                                   uniforms.model[2].xyz);
    out.normal = normalize(normalMatrix * skinnedNormal.xyz);
    out.texCoords = in.texCoords;
    
    float4 viewPos = uniforms.viewProjectionMatrix * worldPosition;
    out.viewPos = viewPos.xyz / viewPos.w;
    
    // Highlight selected joint influence
    float selectedWeight = 0.0;
    for (int i = 0; i < 4; i++) {
        if (int(in.jointIndices[i]) == uniforms.jointIndex) {
            selectedWeight = in.jointWeights[i];
            break;
        }
    }
    out.jointWeight = selectedWeight;
    
    return out;
}

fragment float4 model_fragment_main(VertexOut in [[stage_in]]) {
    float3 lightPos = float3(0.0, 0.0, 500.0);
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

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
    float4x4 skinMatrix = float4x4(0.0);
    for (int i = 0; i < 4; i++) {
        uint jointIdx = in.jointIndices[i];
        float weight = in.jointWeights[i];
        skinMatrix += jointMatrices[jointIdx] * weight;
    }
    
    float4 skinnedPosition = skinMatrix * float4(in.position, 1.0);
    float4 worldPosition = uniforms.modelMatrix * skinnedPosition;
    out.worldPos = worldPosition.xyz;
    out.position = uniforms.viewProjectionMatrix * worldPosition;
    
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
    
    float weightForSelected = 0.0;
    for (int i = 0; i < 4; i++) {
        if (int(in.jointIndices[i]) == uniforms.jointIndex) {
            weightForSelected = in.jointWeights[i];
            break;
        }
    }
    out.jointWeight = weightForSelected;
    
    return out;
}

fragment float4 model_fragment_main(VertexOut in [[stage_in]]) {
    float3 lightPos = float3(2.0, 5.0, 2.0);
    float3 lightColor = float3(1.0);
    float3 baseColor = float3(0.7, 0.7, 0.8);
    
    float3 ambient = baseColor * 0.2;
    float3 normal = normalize(in.normal);
    float3 lightDir = normalize(lightPos - in.worldPos);
    float diff = max(dot(normal, lightDir), 0.0);
    float3 diffuse = baseColor * lightColor * diff;
    
    float3 result = ambient + diffuse;
    float3 jointColor = float3(1.0, 1.0, 0.0);
    result = mix(result, jointColor, in.jointWeight);
    
    return float4(result, 1.0);
}

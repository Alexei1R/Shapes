//
//  ModelShaders.metal
//  Shapes
//
//  Created by rusu alexei on 05.02.2025.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float2 texCoords;
};

vertex VertexOut model_vertex_main(VertexIn in [[stage_in]], constant float4x4 &modelViewProjection [[buffer(1)]]) {
    VertexOut out;
    out.position = modelViewProjection * float4(in.position, 1.0);
    out.color = in.color;
    out.texCoords = in.texCoords;
    return out;
}

fragment float4 model_fragment_main(VertexOut in [[stage_in]]) {
    return in.color;
}

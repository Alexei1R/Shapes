//
//  Shader.metal
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//


#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

struct Uniforms {
    float4x4 viewProjectionMatrix;
    float4x4 model;
    float time;
};



//VERTEX
vertex VertexOut vertex_main(
    VertexIn in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    VertexOut out;
    out.position = uniforms.viewProjectionMatrix * uniforms.model * float4(in.position, 1.0);
    out.color = in.color;
    return out;
}


//FRAGMENT
fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    return in.color;
}



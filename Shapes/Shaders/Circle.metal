//
//  Circle.metal
//  Shapes
//
//  Created by rusu alexei on 13.02.2025.
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float2 uv;
};

struct Circle {
    float3 position;
    float4 color;
    float radius;
};

struct Uniforms {
    float4x4 viewProjectionMatrix;
};

vertex VertexOut circle_vertex_main(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant float2* vertices [[buffer(0)]],
    constant Uniforms& uniforms [[buffer(1)]],
    constant Circle* circles [[buffer(2)]]
) {
    VertexOut out;
    
    float2 pos = vertices[vertexID];
    Circle circle = circles[instanceID];
    
    // Calculate billboard vertices in world space
    float3 worldPos = circle.position + float3(pos * circle.radius, 0.0);
    out.position = uniforms.viewProjectionMatrix * float4(worldPos, 1.0);
    
    // Pass UV coordinates for circle rendering
    out.uv = pos;
    out.color = circle.color;
    
    return out;
}

fragment float4 circle_fragment_main(VertexOut in [[stage_in]]) {
    // Calculate distance from center
    float dist = length(in.uv);
    
    // Discard fragments outside the circle
    if (dist > 1.0) {
        discard_fragment();
    }
    
    // Add some anti-aliasing
    float alpha = 1.0 - smoothstep(0.9, 1.0, dist);
    return float4(in.color.rgb, in.color.a * alpha);
}

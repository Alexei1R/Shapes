//
//  Grid.metal
//  Shapes
//
//  Created by rusu alexei on 14.02.2025.
//


#include <metal_stdlib>
using namespace metal;

struct GridVertexOut {
    float4 position [[position]];
    float4 color;
    float thickness [[point_size]];
};

struct GridUniforms {
    float4x4 viewProjectionMatrix;
    float4x4 modelMatrix;
    float gridSize;
    float gridSpacing;
};

vertex GridVertexOut grid_vertex_main(uint vertexID [[vertex_id]],
                                    constant GridUniforms& uniforms [[buffer(0)]]) {
    GridVertexOut out;
    
    float size = uniforms.gridSize;
    float spacing = uniforms.gridSpacing;
    float numLines = (size * 2.0) / spacing;
    
    // Calculate line positions
    float lineIndex = float(vertexID) / 2.0;
    bool isVertical = fmod(float(vertexID), 4.0) < 2.0;
    bool isEnd = fmod(float(vertexID), 2.0) == 1.0;
    
    float lineOffset = (fmod(lineIndex, numLines) * spacing) - size;
    
    // Generate grid vertices
    float3 position;
    if (isVertical) {
        position = float3(lineOffset, 0.0, isEnd ? size : -size);
    } else {
        position = float3(isEnd ? size : -size, 0.0, lineOffset);
    }
    
    // Transform position
    float4 worldPos = uniforms.modelMatrix * float4(position, 1.0);
    out.position = uniforms.viewProjectionMatrix * worldPos;
    
    // Color based on proximity to axes
    float axisThreshold = spacing * 0.1; // Increased threshold for thicker main axes
    float3 gridColor = float3(0.8, 0.8, 0.8); // Brighter white for grid lines
    
    if (abs(position.x) < axisThreshold) {
        out.color = float4(1.0, 0.2, 0.2, 1.0); // Solid bright red for X axis
        out.thickness = 3.0; // Thicker axis line
    } else if (abs(position.z) < axisThreshold) {
        out.color = float4(0.2, 1.0, 0.2, 1.0); // Solid bright green for Z axis
        out.thickness = 3.0; // Thicker axis line
    } else {
        out.color = float4(gridColor, 0.6); // More opaque white grid lines
        out.thickness = 1.5; // Thicker grid lines
    }
    
    return out;
}

fragment float4 grid_fragment_main(GridVertexOut in [[stage_in]]) {
    return in.color;
}

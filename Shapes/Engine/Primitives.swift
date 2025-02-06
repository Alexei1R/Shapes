//
//  Primitives.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import Foundation

struct Vertex {
    let position: vec3f
    let color: vec4f
}



struct CubeMesh {
    
    
    
    
    // Define cube vertices (each face has a different color)
    static let vertices = [
        // Front face (red)
        Vertex(position: vec3f(-0.5, -0.5,  0.5), color: vec4f(1, 0, 0, 1)),  // 0
        Vertex(position: vec3f( 0.5, -0.5,  0.5), color: vec4f(1, 0, 0, 1)),  // 1
        Vertex(position: vec3f( 0.5,  0.5,  0.5), color: vec4f(1, 0, 0, 1)),  // 2
        Vertex(position: vec3f(-0.5,  0.5,  0.5), color: vec4f(1, 0, 0, 1)),  // 3
        
        // Back face (green)
        Vertex(position: vec3f(-0.5, -0.5, -0.5), color: vec4f(0, 1, 0, 1)),  // 4
        Vertex(position: vec3f(-0.5,  0.5, -0.5), color: vec4f(0, 1, 0, 1)),  // 5
        Vertex(position: vec3f( 0.5,  0.5, -0.5), color: vec4f(0, 1, 0, 1)),  // 6
        Vertex(position: vec3f( 0.5, -0.5, -0.5), color: vec4f(0, 1, 0, 1)),  // 7
        
        // Top face (blue)
        Vertex(position: vec3f(-0.5,  0.5, -0.5), color: vec4f(0, 0, 1, 1)),  // 8
        Vertex(position: vec3f(-0.5,  0.5,  0.5), color: vec4f(0, 0, 1, 1)),  // 9
        Vertex(position: vec3f( 0.5,  0.5,  0.5), color: vec4f(0, 0, 1, 1)),  // 10
        Vertex(position: vec3f( 0.5,  0.5, -0.5), color: vec4f(0, 0, 1, 1)),  // 11
        
        // Bottom face (yellow)
        Vertex(position: vec3f(-0.5, -0.5, -0.5), color: vec4f(1, 1, 0, 1)),  // 12
        Vertex(position: vec3f( 0.5, -0.5, -0.5), color: vec4f(1, 1, 0, 1)),  // 13
        Vertex(position: vec3f( 0.5, -0.5,  0.5), color: vec4f(1, 1, 0, 1)),  // 14
        Vertex(position: vec3f(-0.5, -0.5,  0.5), color: vec4f(1, 1, 0, 1)),  // 15
        
        // Right face (magenta)
        Vertex(position: vec3f( 0.5, -0.5, -0.5), color: vec4f(1, 0, 1, 1)),  // 16
        Vertex(position: vec3f( 0.5,  0.5, -0.5), color: vec4f(1, 0, 1, 1)),  // 17
        Vertex(position: vec3f( 0.5,  0.5,  0.5), color: vec4f(1, 0, 1, 1)),  // 18
        Vertex(position: vec3f( 0.5, -0.5,  0.5), color: vec4f(1, 0, 1, 1)),  // 19
        
        // Left face (cyan)
        Vertex(position: vec3f(-0.5, -0.5, -0.5), color: vec4f(0, 1, 1, 1)),  // 20
        Vertex(position: vec3f(-0.5, -0.5,  0.5), color: vec4f(0, 1, 1, 1)),  // 21
        Vertex(position: vec3f(-0.5,  0.5,  0.5), color: vec4f(0, 1, 1, 1)),  // 22
        Vertex(position: vec3f(-0.5,  0.5, -0.5), color: vec4f(0, 1, 1, 1))   // 23
    ]
    
    // Define indices for the cube (6 faces, 2 triangles each)
    static let indices: [UInt16] = [
        0,  1,  2,  2,  3,  0,
        4,  5,  6,  6,  7,  4,
        8,  9,  10, 10, 11, 8,
        12, 13, 14, 14, 15, 12,
        16, 17, 18, 18, 19, 16,
        20, 21, 22, 22, 23, 20
    ]
}

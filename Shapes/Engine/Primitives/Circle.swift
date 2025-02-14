//
//  Circle.swift
//  Shapes
//
//  Created by rusu alexei on 13.02.2025.
//
import Foundation
import MetalKit

struct DebugCircle {
    var position: vec3f
    var color: vec4f
    var radius: Float
    
    init(position: vec3f, color: vec4f = vec4f(1, 0, 0, 1), radius: Float = 0.1) {
        self.position = position
        self.color = color
        self.radius = radius
    }
}

class CircleRenderer {
    private let device: MTLDevice
    private var pipelineState: MTLRenderPipelineState!
    private var vertexBuffer: MTLBuffer!
    private var circleBuffer: MetalBuffer<DebugCircle>?
    
    struct Uniforms {
        var viewProjectionMatrix: mat4f
    }
    
    private var uniformsBuffer: MetalBuffer<Uniforms>!
    
    init(device: MTLDevice) {
        self.device = device
        setupPipeline()
        createVertexBuffer()
    }
    
    private func setupPipeline() {
        let library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "circle_vertex_main")
        let fragmentFunction = library.makeFunction(name: "circle_fragment_main")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }
    
    private func createVertexBuffer() {
        // Create a single quad that will be instanced for each circle
        let vertices: [vec2f] = [
            vec2f(-1, -1),
            vec2f( 1, -1),
            vec2f(-1,  1),
            vec2f( 1,  1)
        ]
        
        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<vec2f>.stride * vertices.count,
            options: .storageModeShared
        )
    }
    
    func updateCircles(_ circles: [DebugCircle]) {
        // Only create a buffer if we have circles to render
        if circles.isEmpty {
            circleBuffer = nil
        } else {
            circleBuffer = MetalBuffer<DebugCircle>(
                device: device,
                elements: circles,
                usage: .storageShared
            )
        }
    }
    
    func render(encoder: MTLRenderCommandEncoder, viewProjectionMatrix: mat4f) {
        guard let circleBuffer = circleBuffer, circleBuffer.count > 0 else { return }
        
        let uniforms = Uniforms(viewProjectionMatrix: viewProjectionMatrix)
        uniformsBuffer = MetalBuffer<Uniforms>(
            device: device,
            element: uniforms,
            usage: .uniforms
        )
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        uniformsBuffer.bind(to: encoder, type: .vertex, index: 1)
        circleBuffer.bind(to: encoder, type: .vertex, index: 2)
        
        encoder.drawPrimitives(
            type: .triangleStrip,
            vertexStart: 0,
            vertexCount: 4,
            instanceCount: circleBuffer.count
        )
    }
}

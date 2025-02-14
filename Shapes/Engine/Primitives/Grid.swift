//
//  Grid.swift
//  Shapes
//
//  Created by rusu alexei on 14.02.2025.
//

import MetalKit

class Grid {
    private let device: MTLDevice
    private var pipelineState: MTLRenderPipelineState!
    
    struct GridUniforms {
        var viewProjectionMatrix: mat4f
        var modelMatrix: mat4f
        var gridSize: Float
        var gridSpacing: Float
    }
    
    init(device: MTLDevice) {
        self.device = device
        buildPipeline()
    }
    
    private func buildPipeline() {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        let layout = ShaderLayout([
            ShaderElement(type: .vertex, data: "grid_vertex_main"),
            ShaderElement(type: .fragment, data: "grid_fragment_main")
        ])
        
        do {
            let shaderHandle = try ShaderManager.shared.loadShader(layout: layout)
            if let shader = ShaderManager.shared.getShader(shaderHandle) {
                pipelineDescriptor.vertexFunction = shader.function(of: .vertex)
                pipelineDescriptor.fragmentFunction = shader.function(of: .fragment)
            }
        } catch {
            print("Grid shader loading error: \(error)")
        }
        
        // Set pixel formats
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        // Enable blending for transparency
        let colorAttachment = pipelineDescriptor.colorAttachments[0]
        colorAttachment?.isBlendingEnabled = true
        colorAttachment?.rgbBlendOperation = .add
        colorAttachment?.alphaBlendOperation = .add
        colorAttachment?.sourceRGBBlendFactor = .sourceAlpha
        colorAttachment?.sourceAlphaBlendFactor = .one
        colorAttachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha
        colorAttachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create grid pipeline state: \(error)")
        }
    }
    
    func render(encoder: MTLRenderCommandEncoder,
                viewProjectionMatrix: mat4f,
                modelMatrix: mat4f = .identity) {
        guard let pipelineState = pipelineState else { return }
        
        let uniforms = GridUniforms(
            viewProjectionMatrix: viewProjectionMatrix,
            modelMatrix: modelMatrix,
            gridSize: 5.0,  // Kept smaller grid size
            gridSpacing: 0.5 // Kept smaller spacing for dense grid
        )
        
        let uniformsBuffer = MetalBuffer<GridUniforms>(
            device: device,
            element: uniforms,
            usage: .uniforms
        )
        
        // Set render states
        encoder.setRenderPipelineState(pipelineState)
        
        // Configure depth testing
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .lessEqual
        depthStencilDescriptor.isDepthWriteEnabled = true
        if let depthState = device.makeDepthStencilState(descriptor: depthStencilDescriptor) {
            encoder.setDepthStencilState(depthState)
        }
        
        
        // Bind uniforms
        uniformsBuffer?.bind(to: encoder, type: .vertex, index: 0)
        
        // Draw grid
        encoder.drawPrimitives(
            type: .line,
            vertexStart: 0,
            vertexCount: 168 // Maintained dense grid
        )
    }
}

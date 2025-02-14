//
//  Renderer.swift
//  Shapes
//
//  Created by rusu alexei on 05.02.2025.
//

import Foundation
import Metal




protocol RendererAPIProtocol: AnyObject {
    var device: MTLDevice { get }
    var commandQueue: MTLCommandQueue { get }
    
    func createCommandBuffer() -> CommandBuffer
    func createRenderPass(renderPassConfig: RenderPassConfig) -> RenderPassDescriptor
    
}

class RendererAPI: RendererAPIProtocol {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    init?() {
        guard let device = Engine.shared?.device,
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.device = device
        self.commandQueue = commandQueue
    }
    
    func createCommandBuffer() -> CommandBuffer {
        CommandBuffer(commandQueue: commandQueue)
    }
    
    func createRenderPass(renderPassConfig: RenderPassConfig) -> RenderPassDescriptor {
        
        RenderPassDescriptor(config: renderPassConfig)
    }
    
}

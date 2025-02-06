//
//  ComandBuffer.swift
//  Shapes
//
//  Created by rusu alexei on 05.02.2025.
//

import Foundation
import Metal


class CommandBuffer {
    private let commandBuffer: MTLCommandBuffer
    private var renderCommandEncoder: MTLRenderCommandEncoder?
    
    init(commandQueue: MTLCommandQueue) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            fatalError("Could not create command buffer")
        }
        self.commandBuffer = commandBuffer
    }
    
    func begin() {
    }
    
    func setRenderPass(descriptor: MTLRenderPassDescriptor) {
        renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
    }
    
    func end() {
        renderCommandEncoder?.endEncoding()
        commandBuffer.commit()
    }
}

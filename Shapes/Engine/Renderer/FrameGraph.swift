//
//  FrameGraph.swift
//  Shapes
//
//  Created by rusu alexei on 05.02.2025.
//

import Foundation
import Metal


class FrameGraph {
    private var renderPasses: [(CommandBuffer) -> Void] = []
    private let rendererAPI: RendererAPI
    
    init(rendererAPI: RendererAPI) {
        self.rendererAPI = rendererAPI
    }
    
    func addPass(renderPass: @escaping (CommandBuffer) -> Void) {
        renderPasses.append(renderPass)
    }
    
    func execute() {
        let commandBuffer = rendererAPI.createCommandBuffer()
        
        for pass in renderPasses {
            pass(commandBuffer)
        }
    }
}

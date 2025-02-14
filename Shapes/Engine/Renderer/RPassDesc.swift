//
//  RPassDesc.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import Foundation
import Metal

// MARK: - Attachment Descriptor Protocol
protocol AttachmentDescriptor {
    var texture: MTLTexture? { get set }
    var loadAction: MTLLoadAction { get set }
    var storeAction: MTLStoreAction { get set }
}

// MARK: - Color Attachment
struct ColorAttachmentDescriptor: AttachmentDescriptor {
    var texture: MTLTexture?
    var loadAction: MTLLoadAction
    var storeAction: MTLStoreAction
    var clearColor: MTLClearColor
    var resolveTexture: MTLTexture?
    var resolveSlice: Int
    var resolveLevel: Int
    
    init(
        texture: MTLTexture? = nil,
        loadAction: MTLLoadAction = .clear,
        storeAction: MTLStoreAction = .store,
        clearColor: MTLClearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    ) {
        self.texture = texture
        self.loadAction = loadAction
        self.storeAction = storeAction
        self.clearColor = clearColor
        self.resolveTexture = nil
        self.resolveSlice = 0
        self.resolveLevel = 0
    }
}

// MARK: - Depth Attachment
struct DepthAttachmentDescriptor: AttachmentDescriptor {
    var texture: MTLTexture?
    var loadAction: MTLLoadAction
    var storeAction: MTLStoreAction
    var clearDepth: Double
    
    init(
        texture: MTLTexture? = nil,
        loadAction: MTLLoadAction = .clear,
        storeAction: MTLStoreAction = .store,
        clearDepth: Double = 1.0
    ) {
        self.texture = texture
        self.loadAction = loadAction
        self.storeAction = storeAction
        self.clearDepth = clearDepth
    }
}

// MARK: - Stencil Attachment
struct StencilAttachmentDescriptor: AttachmentDescriptor {
    var texture: MTLTexture?
    var loadAction: MTLLoadAction
    var storeAction: MTLStoreAction
    var clearStencil: UInt32
    
    init(
        texture: MTLTexture? = nil,
        loadAction: MTLLoadAction = .clear,
        storeAction: MTLStoreAction = .store,
        clearStencil: UInt32 = 0
    ) {
        self.texture = texture
        self.loadAction = loadAction
        self.storeAction = storeAction
        self.clearStencil = clearStencil
    }
}

// MARK: - Render Pass Configuration
struct RenderPassConfig {
    var colorAttachments: [ColorAttachmentDescriptor]
    var depthAttachment: DepthAttachmentDescriptor?
    var stencilAttachment: StencilAttachmentDescriptor?
    var sampleCount: Int
    var rasterizationRateMap: MTLRasterizationRateMap?
    
    init(
        colorAttachments: [ColorAttachmentDescriptor] = [],
        depthAttachment: DepthAttachmentDescriptor? = nil,
        stencilAttachment: StencilAttachmentDescriptor? = nil,
        sampleCount: Int = 1,
        rasterizationRateMap: MTLRasterizationRateMap? = nil
    ) {
        self.colorAttachments = colorAttachments
        self.depthAttachment = depthAttachment
        self.stencilAttachment = stencilAttachment
        self.sampleCount = sampleCount
        self.rasterizationRateMap = rasterizationRateMap
    }
}

// MARK: - Render Pass Builder
class RenderPassBuilder {
    private var config: RenderPassConfig
    
    init() {
        self.config = RenderPassConfig()
    }
    
    func addColorAttachment(_ attachment: ColorAttachmentDescriptor) -> RenderPassBuilder {
        config.colorAttachments.append(attachment)
        return self
    }
    
    func setDepthAttachment(_ attachment: DepthAttachmentDescriptor) -> RenderPassBuilder {
        config.depthAttachment = attachment
        return self
    }
    
    func setStencilAttachment(_ attachment: StencilAttachmentDescriptor) -> RenderPassBuilder {
        config.stencilAttachment = attachment
        return self
    }
    
    func setSampleCount(_ count: Int) -> RenderPassBuilder {
        config.sampleCount = count
        return self
    }
    
    func build() -> RenderPassConfig {
        return config
    }
}

// MARK: - Render Pass Descriptor
class RenderPassDescriptor {
    private let config: RenderPassConfig
    private let descriptor: MTLRenderPassDescriptor
    
    init(config: RenderPassConfig) {
        self.config = config
        self.descriptor = MTLRenderPassDescriptor()
        configure()
    }
    
    private func configure() {
        // Configure color attachments
        for (index, colorAttachment) in config.colorAttachments.enumerated() {
            let attachment = descriptor.colorAttachments[index]
            attachment?.texture = colorAttachment.texture
            attachment?.loadAction = colorAttachment.loadAction
            attachment?.storeAction = colorAttachment.storeAction
            attachment?.clearColor = colorAttachment.clearColor
            attachment?.resolveTexture = colorAttachment.resolveTexture
            attachment?.resolveSlice = colorAttachment.resolveSlice
            attachment?.resolveLevel = colorAttachment.resolveLevel
        }
        
        // Configure depth attachment
        if let depthAttachment = config.depthAttachment {
            descriptor.depthAttachment.texture = depthAttachment.texture
            descriptor.depthAttachment.loadAction = depthAttachment.loadAction
            descriptor.depthAttachment.storeAction = depthAttachment.storeAction
            descriptor.depthAttachment.clearDepth = depthAttachment.clearDepth
        }
        
        // Configure stencil attachment
        if let stencilAttachment = config.stencilAttachment {
            descriptor.stencilAttachment.texture = stencilAttachment.texture
            descriptor.stencilAttachment.loadAction = stencilAttachment.loadAction
            descriptor.stencilAttachment.storeAction = stencilAttachment.storeAction
            descriptor.stencilAttachment.clearStencil = stencilAttachment.clearStencil
        }
        
        descriptor.rasterizationRateMap = config.rasterizationRateMap
    }
    
    func getMTLRenderPassDescriptor() -> MTLRenderPassDescriptor {
        return descriptor
    }
}

// MARK: - Render Pass Factory
class RenderPassFactory {
    static func createDefaultRenderPass() -> RenderPassDescriptor {
        let config = RenderPassBuilder()
            .addColorAttachment(ColorAttachmentDescriptor())
            .setDepthAttachment(DepthAttachmentDescriptor())
            .build()
        
        return RenderPassDescriptor(config: config)
    }
    
    static func createOffscreenRenderPass(
        colorTexture: MTLTexture,
        depthTexture: MTLTexture? = nil
    ) -> RenderPassDescriptor {
        let colorAttachment = ColorAttachmentDescriptor(
            texture: colorTexture,
            loadAction: .clear,
            storeAction: .store
        )
        
        let builder = RenderPassBuilder()
            .addColorAttachment(colorAttachment)
        
        if let depthTexture = depthTexture {
            builder.setDepthAttachment(
                DepthAttachmentDescriptor(
                    texture: depthTexture,
                    loadAction: .clear,
                    storeAction: .store
                )
            )
        }
        
        return RenderPassDescriptor(config: builder.build())
    }
}

//
//  Drawable.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//


import SwiftUI
import MetalKit

struct ScanView: UIViewRepresentable {
    
    private let drawable: Drawable
    private let device: MTLDevice?
    

    
    
    init() {
        guard let engine = Engine.shared else {
            fatalError("Failed to create Metal device")
        }
        
        self.device = engine.device
        self.drawable = Drawable(device: device!)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(device: device!)
    }
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.delegate = context.coordinator.drawable
        
        mtkView.preferredFramesPerSecond = 60
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        
        mtkView.colorPixelFormat = .bgra8Unorm       // Standard color format
        mtkView.depthStencilPixelFormat = .depth32Float // Depth format for proper depth testing
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
    }
    
    class Coordinator {
        let drawable: Drawable
        
        init(device: MTLDevice) {
            drawable = Drawable(device: device)
        }
    }
}

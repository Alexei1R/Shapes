//
//  Drawable.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//


import SwiftUI
import MetalKit

struct ScanView: UIViewRepresentable {
    
    private let device: MTLDevice?
    
    init() {
        guard let engine = Engine.shared else {
            fatalError("Failed to create Metal device")
        }
        self.device = engine.device
    }
    
    func makeCoordinator() -> Coordinator {
        // Create only one instance of Drawable here
        Coordinator(device: device!)
    }
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.delegate = context.coordinator.drawable
        
        mtkView.preferredFramesPerSecond = 60
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float 
        
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

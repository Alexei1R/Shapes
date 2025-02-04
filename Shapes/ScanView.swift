//
//  Drawable.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import Foundation
import MetalKit
import SwiftUI



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
    
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        guard let device = device else {
            fatalError("Metal device is nil")
        }
        
        view.device = device
        view.delegate = drawable
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 30
        view.isPaused = false
        
        // Configure view
        view.depthStencilPixelFormat = .depth32Float
        view.clearDepth = 1.0
        
        let initialSize = view.bounds.size
        drawable.mtkView(view, drawableSizeWillChange: initialSize)
        return view
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Handle updates if needed
    }
}



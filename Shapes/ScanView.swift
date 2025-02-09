//
//  Drawable.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import SwiftUI
import MetalKit

struct ScanView: UIViewRepresentable {
    @ObservedObject var drawable: Drawable
    
    func makeCoordinator() -> Coordinator {
        Coordinator(drawable: drawable)
    }
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView(frame: .zero, device: drawable.device)
        mtkView.delegate = drawable
        
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
        
        init(drawable: Drawable) {
            self.drawable = drawable
        }
    }
}

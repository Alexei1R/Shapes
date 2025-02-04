//
//  Drawable.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import Foundation
import MetalKit

class Drawable: NSObject {
    private let eventManager : EventManager

    private let device: MTLDevice
    
    init(device: MTLDevice)  {
        self.device = device
        self.eventManager = EventManager.shared

        super.init()
    }

}



extension Drawable : MTKViewDelegate{
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }


    func draw(in view: MTKView) {
        if eventManager.isActive, let event = eventManager.currentEvent {
            print(" \(event.delta)")
        }
    }
}

//
//  Engine.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import Foundation
import Metal

protocol EngineComponent {
    func initialize()
    func update(deltaTime: Float)
}

protocol Renderable {
    func render(commandEncoder: MTLRenderCommandEncoder)
}




class Engine{
 
    static let shared = Engine()
    let device : MTLDevice
    
    private init ? (){
        //Create a singleton device
        guard let mtlDevice = MTLCreateSystemDefaultDevice() else{
            return nil
        }
        self.device = mtlDevice
        
        
    }
    
    
    
    
    
    
    
}



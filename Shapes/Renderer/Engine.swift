//
//  Engine.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import Foundation
import Metal


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



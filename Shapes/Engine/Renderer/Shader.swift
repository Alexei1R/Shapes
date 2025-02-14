//
//  Shader.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import Foundation
import Metal

enum ShaderType {
    case vertex
    case fragment
    case compute
}

struct ShaderElement {
    let type: ShaderType
    let data: String
}

struct ShaderLayout {
    let elements: [ShaderElement]
    
    init(_ elements: [ShaderElement]) {
        self.elements = elements
    }
}

class Shader {
    private let device: MTLDevice
    private var functions: [ShaderType: MTLFunction] = [:]
    private let library: MTLLibrary
    
    init(device: MTLDevice, library: MTLLibrary) throws {
        self.device = device
        self.library = library
    }
    
    func addFunction(_ type: ShaderType, name: String) throws {
        guard let function = library.makeFunction(name: name) else {
            throw ShaderError.functionNotFound(name)
        }
        functions[type] = function
    }
    
    func function(of type: ShaderType) -> MTLFunction? {
        return functions[type]
    }
}

// MARK: - Shader Manager
enum ShaderError: Error {
    case functionNotFound(String)
    case libraryCreationFailed
    case invalidHandle
}

class ShaderManager {
    // Singleton instance
    static let shared = ShaderManager()
    
    private let device: MTLDevice
    private var shaders: [Handle: Shader] = [:]
    private let queue = DispatchQueue(label: "com.forge.shadermanager", attributes: .concurrent)
    
    private init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = device
    }
    
    func loadShader(layout: ShaderLayout) throws -> Handle {
        let handle = Handle()
        
        guard let library = device.makeDefaultLibrary() else {
            throw ShaderError.libraryCreationFailed
        }
        
        let shader = try Shader(device: device, library: library)
        
        // Load all shader functions based on layout
        for element in layout.elements {
            try shader.addFunction(element.type, name: element.data)
        }
        
        queue.async(flags: .barrier) { [weak self] in
            self?.shaders[handle] = shader
        }
        
        return handle
    }
    
    func getShader(_ handle: Handle) -> Shader? {
        queue.sync {
            return shaders[handle]
        }
    }
    
    func removeShader(_ handle: Handle) {
        queue.async(flags: .barrier) { [weak self] in
            self?.shaders.removeValue(forKey: handle)
        }
    }
    
    func clearCache() {
        queue.async(flags: .barrier) { [weak self] in
            self?.shaders.removeAll()
        }
    }
}

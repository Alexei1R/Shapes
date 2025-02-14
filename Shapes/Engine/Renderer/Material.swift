//
//  Material.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import Foundation
import simd



protocol ConfigEntry {
    var name: String { get }
    var value: Any { get }
}


enum MaterialParamValue {
    case float(Float)
    case vector2(SIMD2<Float>)
    case vector3(SIMD3<Float>)
    case vector4(SIMD4<Float>)
    case integer(Int)
    case boolean(Bool)
}

/// Main Material class
class Material {
    var name: String = "UnnamedMaterial"
    var color: SIMD4<Float>
    var additionalParameters: [String: MaterialParamValue]
    
    // MARK: - Initialization
    init(name: String = "UnnamedMaterial") {
        self.name = name
        self.additionalParameters = [:]
        self.color = SIMD4<Float>(1.0, 0.0, 1.0, 1.0)
    }
    
    // MARK: - Methods
    func setParameter(_ name: String, _ value: MaterialParamValue) {
        additionalParameters[name] = value
    }
    
    func getParameter(_ name: String) -> MaterialParamValue? {
        return additionalParameters[name]
    }
    
}

// MARK: - Material Manager
class MaterialManager {
    private var materials: [Handle: Material] = [:]
    private let queue = DispatchQueue(label: "com.forge.materialmanager", attributes: .concurrent)
    
    func createMaterial(name: String = "UnnamedMaterial") -> Handle {
        let material = Material(name: name)
        let handle = Handle()
        
        queue.async(flags: .barrier) { [weak self] in
            self?.materials[handle] = material
        }
        
        return handle
    }
    
    func getMaterial(_ handle: Handle) -> Material? {
        queue.sync {
            return materials[handle]
        }
    }
    
    func updateMaterial(_ handle: Handle, update: @escaping (Material) -> Void) {
        queue.async(flags: .barrier) { [weak self] in
            guard let material = self?.materials[handle] else { return }
            update(material)
        }
    }
    
    func destroyMaterial(_ handle: Handle) {
        queue.async(flags: .barrier) { [weak self] in
            self?.materials.removeValue(forKey: handle)
        }
    }
}


extension MaterialManager {
    func printMaterialDetails(_ handle: Handle) {
        if let material = getMaterial(handle) {
            print("\n=== Material Details [\(material.name)] ===")
            
            print("\nBase Properties:")
            print("- color: SIMD4<Float> = \(material.color)")
            
            // Print all parameters
            print("\nCustom Parameters:")
            for (name, value) in material.additionalParameters {
                switch value {
                case .float(let v):
                    print("- \(name): Float = \(v)")
                case .vector2(let v):
                    print("- \(name): SIMD2<Float> = \(v)")
                case .vector3(let v):
                    print("- \(name): SIMD3<Float> = \(v)")
                case .vector4(let v):
                    print("- \(name): SIMD4<Float> = \(v)")
                case .integer(let v):
                    print("- \(name): Int = \(v)")
                case .boolean(let v):
                    print("- \(name): Bool = \(v)")
                }
            }
            print("===================================")
        } else {
            print("No material found for the given handle")
        }
    }
}


//Default material
extension Material {
    static func createDefault() -> Material {
        let material = Material(name: "DefaultMaterial")
        material.setParameter("roughness", .float(0.5))
        material.setParameter("metallic", .float(0.0))
        material.setParameter("normalScale", .vector2(SIMD2<Float>(1.0, 1.0)))
        return material
    }
}

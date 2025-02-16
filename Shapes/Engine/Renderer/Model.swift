//
//  Model3D.swift
//  Shapes
//
//  Created by Alexei1R on 2025-02-16
//

import Foundation
import MetalKit
import ModelIO
import simd

// MARK: - Types and Structures
public enum ModelLoaderError: Error {
    case failedToLoadAsset(String)
    case invalidMesh
    case missingVertexData
    case invalidSkeleton
}

public struct ModelVertex {
    var position: vec3f
    var normal: vec3f
    var textureCoordinate: vec2f
    var tangent: vec3f
    var bitangent: vec3f
    var jointIndices: SIMD4<UInt16>
    var jointWeights: vec4f
}

public struct MeshData {
    var vertices: [ModelVertex]
    var indices: [UInt32]
}

public struct ModelJoint {
    let id: Int
    let name: String
    let path: String
    let bindTransform: mat4f
    let restTransform: mat4f
    let parentIndex: Int?
}

// MARK: - Main Model3D Class
public class Model3D {
    // MARK: - Properties
    private(set) var asset: MDLAsset?
    private(set) var meshes: [MDLMesh] = []
    private(set) var skeleton: MDLSkeleton?
    private(set) var joints: [ModelJoint] = []
    
    // MARK: - Transformation Matrix
    private let coordinateTransform: mat4f = {
        // Convert from Z-up to Y-up and flip Z for Metal's coordinate system
        let toYUp = mat4f(
            vec4f(1, 0,  0, 0),
            vec4f(0, 0, -1, 0),
            vec4f(0, 1,  0, 0),
            vec4f(0, 0,  0, 1)
        )
        let flipZ = mat4f(diagonal: vec4f(1, 1, -1, 1))
        return flipZ * toYUp
    }()
    
    // MARK: - Vertex Layout Configuration
    private let vertexDescriptor: MDLVertexDescriptor = {
        let descriptor = MDLVertexDescriptor()
        var offset = 0
        
        // Position attribute
        descriptor.attributes[0] = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: offset,
            bufferIndex: 0
        )
        offset += MemoryLayout<vec3f>.stride
        
        // Normal attribute
        descriptor.attributes[1] = MDLVertexAttribute(
            name: MDLVertexAttributeNormal,
            format: .float3,
            offset: offset,
            bufferIndex: 0
        )
        offset += MemoryLayout<vec3f>.stride
        
        // Texture coordinate attribute
        descriptor.attributes[2] = MDLVertexAttribute(
            name: MDLVertexAttributeTextureCoordinate,
            format: .float2,
            offset: offset,
            bufferIndex: 0
        )
        offset += MemoryLayout<vec2f>.stride
        
        // Tangent attribute
        descriptor.attributes[3] = MDLVertexAttribute(
            name: MDLVertexAttributeTangent,
            format: .float3,
            offset: offset,
            bufferIndex: 0
        )
        offset += MemoryLayout<vec3f>.stride
        
        // Bitangent attribute
        descriptor.attributes[4] = MDLVertexAttribute(
            name: MDLVertexAttributeBitangent,
            format: .float3,
            offset: offset,
            bufferIndex: 0
        )
        offset += MemoryLayout<vec3f>.stride
        
        // Joint indices attribute
        descriptor.attributes[5] = MDLVertexAttribute(
            name: MDLVertexAttributeJointIndices,
            format: .float4,
            offset: offset,
            bufferIndex: 0
        )
        offset += MemoryLayout<vec4f>.stride
        
        // Joint weights attribute
        descriptor.attributes[6] = MDLVertexAttribute(
            name: MDLVertexAttributeJointWeights,
            format: .float4,
            offset: offset,
            bufferIndex: 0
        )
        offset += MemoryLayout<vec4f>.stride
        
        descriptor.layouts[0] = MDLVertexBufferLayout(stride: offset)
        return descriptor
    }()
    
    // MARK: - Initialization
    public init() {}
    
    // MARK: - Model Loading
    public func load(from url: URL) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw ModelLoaderError.failedToLoadAsset("No Metal device available")
        }
        
        let allocator = MTKMeshBufferAllocator(device: device)
        asset = MDLAsset(
            url: url,
            vertexDescriptor: vertexDescriptor,
            bufferAllocator: allocator
        )
        
        guard let asset = asset else {
            throw ModelLoaderError.failedToLoadAsset("Failed to load asset")
        }
        
        if #available(iOS 11.0, macOS 10.13, *) {
            asset.upAxis = vec3f.up
        }
        
        try loadMeshes()
        try loadSkeleton()
    }
    
    // MARK: - Mesh Loading
    private func loadMeshes() throws {
        guard let foundMeshes = asset?.childObjects(of: MDLMesh.self) as? [MDLMesh],
              !foundMeshes.isEmpty else {
            throw ModelLoaderError.invalidMesh
        }
        
        meshes = foundMeshes
        
        for mesh in meshes {
            let transform = MDLTransform()
            transform.setLocalTransform(coordinateTransform)
            mesh.transform = transform
            
            if let attributes = mesh.vertexDescriptor.attributes as? [MDLVertexAttribute] {
                if !attributes.contains(where: { $0.name == MDLVertexAttributeNormal }) {
                    mesh.addNormals(
                        withAttributeNamed: MDLVertexAttributeNormal,
                        creaseThreshold: 0.5
                    )
                }
                
                if !attributes.contains(where: { $0.name == MDLVertexAttributeTangent }) {
                    mesh.addTangentBasis(
                        forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                        tangentAttributeNamed: MDLVertexAttributeTangent,
                        bitangentAttributeNamed: MDLVertexAttributeBitangent
                    )
                }
            }
        }
    }
    
    // MARK: - Skeleton Loading
    private func loadSkeleton() throws {
        guard let asset = asset else { return }
        
        guard let skeletons = asset.childObjects(of: MDLSkeleton.self) as? [MDLSkeleton],
              let firstSkeleton = skeletons.first else {
            return
        }
        
        skeleton = firstSkeleton
        
        guard let jointPaths = firstSkeleton.jointPaths as? [String],
              !jointPaths.isEmpty else {
            throw ModelLoaderError.invalidSkeleton
        }
        
        var pathToIndex = [String: Int](minimumCapacity: jointPaths.count)
        for (i, path) in jointPaths.enumerated() {
            pathToIndex[path] = i
        }
        
        joints.removeAll(keepingCapacity: true)
        joints.reserveCapacity(jointPaths.count)
        
        let bindTransforms = getTransforms(from: firstSkeleton.jointBindTransforms)
        let restTransforms = getTransforms(from: firstSkeleton.jointRestTransforms)
        
        guard bindTransforms.count == jointPaths.count,
              restTransforms.count == jointPaths.count else {
            throw ModelLoaderError.invalidSkeleton
        }
        
        for (i, path) in jointPaths.enumerated() {
            let components = path.components(separatedBy: "/")
            let parentPath = components.dropLast().joined(separator: "/")
            let parentIndex = pathToIndex[parentPath]
            
            let bindTransform = coordinateTransform * bindTransforms[i] * coordinateTransform.inverse()
            let restTransform = coordinateTransform * restTransforms[i] * coordinateTransform.inverse()
            
            joints.append(ModelJoint(
                id: i,
                name: (path as NSString).lastPathComponent,
                path: path,
                bindTransform: bindTransform,
                restTransform: restTransform,
                parentIndex: parentIndex
            ))
        }
    }
    
    // MARK: - Matrix Transform Utilities
    private func getTransforms(from array: MDLMatrix4x4Array) -> [mat4f] {
        var transforms = [mat4f]()
        
        if #available(iOS 11.0, macOS 10.13, *) {
            // Use the proper API for iOS 11.0 and later
            let matrices = array.float4x4Array
            transforms = matrices.map { matrix in
                mat4f(
                    vec4f(matrix.columns.0),
                    vec4f(matrix.columns.1),
                    vec4f(matrix.columns.2),
                    vec4f(matrix.columns.3)
                )
            }
        } else {
            // Fallback for earlier versions
            let count = array.elementCount
            transforms.reserveCapacity(count)
            
            // Create empty matrices for earlier versions
            for _ in 0..<count {
                transforms.append(mat4f.identity)
            }
        }
        
        return transforms
    }
    
    // MARK: - Mesh Data Extraction
    public func extractMeshData(from mesh: MDLMesh) -> MeshData? {
        guard let vertexBuffer = mesh.vertexBuffers.first as? MDLMeshBuffer,
              let layout = mesh.vertexDescriptor.layouts[0] as? MDLVertexBufferLayout else {
            return nil
        }
        
        let vertexMap = vertexBuffer.map()
        let vertexData = vertexMap.bytes
        let stride = Int(layout.stride)
        
        var vertices = [ModelVertex]()
        vertices.reserveCapacity(mesh.vertexCount)
        
        var attributeMap = [String: (offset: Int, format: MDLVertexFormat)]()
        for attribute in mesh.vertexDescriptor.attributes as? [MDLVertexAttribute] ?? [] {
            attributeMap[attribute.name] = (Int(attribute.offset), attribute.format)
        }
        
        // Extract vertex data
        for i in 0..<mesh.vertexCount {
            let baseAddress = vertexData.advanced(by: i * stride)
            var vertex = ModelVertex(
                position: .zero,
                normal: .zero,
                textureCoordinate: .zero,
                tangent: .zero,
                bitangent: .zero,
                jointIndices: .init(repeating: 0),
                jointWeights: vec4f(1, 0, 0, 0)
            )
            
            // Position
            if let (offset, _) = attributeMap[MDLVertexAttributePosition] {
                let position = baseAddress.advanced(by: offset)
                    .assumingMemoryBound(to: vec3f.self)
                    .pointee
                let transformed = coordinateTransform * vec4f(position.x, position.y, position.z, 1)
                vertex.position = vec3f(transformed.x, transformed.y, transformed.z) / transformed.w
            }
            
            // Normal
            if let (offset, _) = attributeMap[MDLVertexAttributeNormal] {
                let normal = baseAddress.advanced(by: offset)
                    .assumingMemoryBound(to: vec3f.self)
                    .pointee
                let transformed = coordinateTransform * vec4f(normal.x, normal.y, normal.z, 0)
                vertex.normal = normalize(vec3f(transformed.x, transformed.y, transformed.z))
            }
            
            // Texture coordinates
            if let (offset, _) = attributeMap[MDLVertexAttributeTextureCoordinate] {
                vertex.textureCoordinate = baseAddress.advanced(by: offset)
                    .assumingMemoryBound(to: vec2f.self)
                    .pointee
            }
            
            // Tangent
            if let (offset, _) = attributeMap[MDLVertexAttributeTangent] {
                let tangent = baseAddress.advanced(by: offset)
                    .assumingMemoryBound(to: vec3f.self)
                    .pointee
                let transformed = coordinateTransform * vec4f(tangent.x, tangent.y, tangent.z, 0)
                vertex.tangent = normalize(vec3f(transformed.x, transformed.y, transformed.z))
            }
            
            // Bitangent
            if let (offset, _) = attributeMap[MDLVertexAttributeBitangent] {
                let bitangent = baseAddress.advanced(by: offset)
                    .assumingMemoryBound(to: vec3f.self)
                    .pointee
                let transformed = coordinateTransform * vec4f(bitangent.x, bitangent.y, bitangent.z, 0)
                vertex.bitangent = normalize(vec3f(transformed.x, transformed.y, transformed.z))
            }
            
            // Joint indices
            if let (offset, _) = attributeMap[MDLVertexAttributeJointIndices] {
                let rawIndices = baseAddress.advanced(by: offset)
                    .assumingMemoryBound(to: vec4f.self)
                    .pointee
                vertex.jointIndices = SIMD4<UInt16>(
                    UInt16(rawIndices.x),
                    UInt16(rawIndices.y),
                    UInt16(rawIndices.z),
                    UInt16(rawIndices.w)
                )
            }
            
            // Joint weights
            if let (offset, _) = attributeMap[MDLVertexAttributeJointWeights] {
                var weights = baseAddress.advanced(by: offset)
                    .assumingMemoryBound(to: vec4f.self)
                    .pointee
                let total = weights.x + weights.y + weights.z + weights.w
                vertex.jointWeights = total > 0 ? weights / total : vec4f(1, 0, 0, 0)
            }
            
            vertices.append(vertex)
        }
        // Extract indices
                var indices = [UInt32]()
                if let submeshes = mesh.submeshes as? [MDLSubmesh] {
                    for submesh in submeshes {
                        guard let indexBuffer = submesh.indexBuffer as? MDLMeshBuffer else { continue }
                        
                        let indexMap = indexBuffer.map()
                        let indexData = indexMap.bytes
                        let indexCount = submesh.indexCount
                        
                        switch submesh.indexType {
                        case .uInt32:
                            let ptr = indexData.assumingMemoryBound(to: UInt32.self)
                            indices.append(contentsOf: UnsafeBufferPointer(start: ptr, count: indexCount))
                            
                        case .uInt16:
                            let ptr = indexData.assumingMemoryBound(to: UInt16.self)
                            indices.append(contentsOf: UnsafeBufferPointer(start: ptr, count: indexCount)
                                .map { UInt32($0) })
                            
                        case .uInt8:
                            let ptr = indexData.assumingMemoryBound(to: UInt8.self)
                            indices.append(contentsOf: UnsafeBufferPointer(start: ptr, count: indexCount)
                                .map { UInt32($0) })
                            
                        @unknown default:
                            continue
                        }
                    }
                }
                
                guard !vertices.isEmpty, !indices.isEmpty else {
                    return nil
                }
                
                return MeshData(vertices: vertices, indices: indices)
            }
            
            // MARK: - Debug Information
            public func printModelInfo() {
                print("\n=== Model Information ===")
                print("Number of meshes: \(meshes.count)")
                
                for (index, mesh) in meshes.enumerated() {
                    print("\nMesh \(index + 1):")
                    print("- Vertex count: \(mesh.vertexCount)")
                    print("- Submesh count: \(mesh.submeshes?.count ?? 0)")
                    
                    if let name = (mesh as? MDLNamed)?.name, !name.isEmpty {
                        print("- Name: \(name)")
                    }
                }
                
                print("\n=== Skeleton Information ===")
                print("Number of joints: \(joints.count)")
                
                if !joints.isEmpty {
                    print("\nJoint Hierarchy:")
                    for joint in joints {
                        let indent = String(repeating: "  ", count: joint.path.components(separatedBy: "/").count - 1)
                        print("\(indent)- \(joint.name) (ID: \(joint.id))")
                        if let parentIndex = joint.parentIndex {
                            print("\(indent)  Parent: \(joints[parentIndex].name) (ID: \(parentIndex))")
                        }
                    }
                }
                
                if let asset = asset {
                    print("\n=== Asset Information ===")
                    if #available(iOS 11.0, macOS 10.13, *) {
                        print("Up Axis: \(asset.upAxis)")
                    }
                    print("Start Time: \(asset.startTime)")
                    print("End Time: \(asset.endTime)")
                    print("Frame Interval: \(asset.frameInterval)")
                }
            }
        }

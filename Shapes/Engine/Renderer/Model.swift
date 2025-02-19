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

public class Model3D {
    private(set) var asset: MDLAsset?
    private(set) var meshes: [MDLMesh] = []
    private(set) var skeleton: MDLSkeleton?
    private(set) var joints: [ModelJoint] = []
    
    private(set) var changeCoordonateSystem: Bool = true
    
    let blenderToMetalMatrix: mat4f = mat4f(columns: (
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, 0, 1, 0),
        SIMD4<Float>(0, -1, 0, 0),
        SIMD4<Float>(0, 0, 0, 1)
    ))
    
    private let vertexDescriptor: MDLVertexDescriptor = {
        let descriptor = MDLVertexDescriptor()
        var offset = 0
        
        descriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                      format: .float3,
                                                      offset: offset,
                                                      bufferIndex: 0)
        offset += MemoryLayout<vec3f>.stride
        
        descriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                                      format: .float3,
                                                      offset: offset,
                                                      bufferIndex: 0)
        offset += MemoryLayout<vec3f>.stride
        
        descriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                                      format: .float2,
                                                      offset: offset,
                                                      bufferIndex: 0)
        offset += MemoryLayout<vec2f>.stride
        
        descriptor.attributes[3] = MDLVertexAttribute(name: MDLVertexAttributeTangent,
                                                      format: .float3,
                                                      offset: offset,
                                                      bufferIndex: 0)
        offset += MemoryLayout<vec3f>.stride
        
        descriptor.attributes[4] = MDLVertexAttribute(name: MDLVertexAttributeBitangent,
                                                      format: .float3,
                                                      offset: offset,
                                                      bufferIndex: 0)
        offset += MemoryLayout<vec3f>.stride
        
        descriptor.attributes[5] = MDLVertexAttribute(name: MDLVertexAttributeJointIndices,
                                                      format: .uShort4,
                                                      offset: offset,
                                                      bufferIndex: 0)
        offset += MemoryLayout<SIMD4<UInt16>>.stride
        
        descriptor.attributes[6] = MDLVertexAttribute(name: MDLVertexAttributeJointWeights,
                                                      format: .float4,
                                                      offset: offset,
                                                      bufferIndex: 0)
        offset += MemoryLayout<vec4f>.stride
        
        descriptor.layouts[0] = MDLVertexBufferLayout(stride: offset)
        return descriptor
    }()
    
    public init() {}
    
    public func load(from url: URL) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw ModelLoaderError.failedToLoadAsset("No Metal device available")
        }
        let allocator = MTKMeshBufferAllocator(device: device)
        asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor, bufferAllocator: allocator)
        guard let asset = asset else {
            throw ModelLoaderError.failedToLoadAsset("Failed to load asset")
        }
        if #available(iOS 11.0, macOS 10.13, *) {
            asset.upAxis = vec3f.up
        }
        try loadMeshes()
        try loadSkeleton()
    }
    
    private func loadMeshes() throws {
        guard let foundMeshes = asset?.childObjects(of: MDLMesh.self) as? [MDLMesh],
              !foundMeshes.isEmpty else {
            throw ModelLoaderError.invalidMesh
        }
        meshes = foundMeshes
        for mesh in meshes {
            mesh.transform = MDLTransform()
            if let attributes = mesh.vertexDescriptor.attributes as? [MDLVertexAttribute] {
                if !attributes.contains(where: { $0.name == MDLVertexAttributeNormal }) {
                    mesh.addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0.5)
                }
                if !attributes.contains(where: { $0.name == MDLVertexAttributeTangent }) {
                    mesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                                           tangentAttributeNamed: MDLVertexAttributeTangent,
                                           bitangentAttributeNamed: MDLVertexAttributeBitangent)
                }
            }
        }
    }
    
    private func loadSkeleton() throws {
        guard let asset = asset else { return }
        guard let skeletons = asset.childObjects(of: MDLSkeleton.self) as? [MDLSkeleton],
              let firstSkeleton = skeletons.first else { return }
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
            let components = path.split(separator: "/").map { String($0) }
            let parentPath = components.dropLast().joined(separator: "/")
            let parentIndex = parentPath.isEmpty ? nil : pathToIndex[parentPath]
            let jointName = components.last ?? ""
            var bindTransform = bindTransforms[i]
            var restTransform = restTransforms[i]
            if changeCoordonateSystem {
                bindTransform = blenderToMetalMatrix * bindTransform
                restTransform = blenderToMetalMatrix * restTransform
            }
            joints.append(ModelJoint(id: i,
                                     name: jointName,
                                     path: path,
                                     bindTransform: bindTransform,
                                     restTransform: restTransform,
                                     parentIndex: parentIndex))
        }
    }
    
    private func getTransforms(from array: MDLMatrix4x4Array) -> [mat4f] {
        if #available(iOS 11.0, macOS 10.13, *) {
            return array.float4x4Array.map { mat4f($0) }
        } else {
            let count = array.elementCount
            return Array(repeating: mat4f.identity, count: count)
        }
    }
    
    public func extractMeshData(from mesh: MDLMesh) -> MeshData? {
        guard let vertexBuffer = mesh.vertexBuffers.first as? MDLMeshBuffer,
              let layout = mesh.vertexDescriptor.layouts[0] as? MDLVertexBufferLayout else { return nil }
        let vertexMap = vertexBuffer.map()
        let vertexData = vertexMap.bytes
        let stride = Int(layout.stride)
        var vertices = [ModelVertex]()
        vertices.reserveCapacity(mesh.vertexCount)
        var attributeMap = [String: (offset: Int, format: MDLVertexFormat)]()
        for attribute in mesh.vertexDescriptor.attributes as? [MDLVertexAttribute] ?? [] {
            attributeMap[attribute.name] = (Int(attribute.offset), attribute.format)
        }
        for i in 0..<mesh.vertexCount {
            let baseAddress = vertexData.advanced(by: i * stride)
            var vertex = ModelVertex(position: .zero,
                                     normal: .zero,
                                     textureCoordinate: .zero,
                                     tangent: .zero,
                                     bitangent: .zero,
                                     jointIndices: SIMD4<UInt16>(0, 0, 0, 0),
                                     jointWeights: vec4f(1, 0, 0, 0))
            if let (offset, _) = attributeMap[MDLVertexAttributePosition] {
                let pos = baseAddress.advanced(by: offset).assumingMemoryBound(to: vec3f.self).pointee
                if changeCoordonateSystem {
                    let t = blenderToMetalMatrix * SIMD4<Float>(pos.x, pos.y, pos.z, 1)
                    vertex.position = vec3f(t.x, t.y, t.z) / t.w
                } else {
                    vertex.position = pos
                }
            }
            if let (offset, _) = attributeMap[MDLVertexAttributeNormal] {
                let n = baseAddress.advanced(by: offset).assumingMemoryBound(to: vec3f.self).pointee
                if changeCoordonateSystem {
                    let t = blenderToMetalMatrix * SIMD4<Float>(n.x, n.y, n.z, 0)
                    vertex.normal = normalize(vec3f(t.x, t.y, t.z))
                } else {
                    vertex.normal = normalize(n)
                }
            }
            if let (offset, _) = attributeMap[MDLVertexAttributeTextureCoordinate] {
                vertex.textureCoordinate = baseAddress.advanced(by: offset).assumingMemoryBound(to: vec2f.self).pointee
            }
            if let (offset, _) = attributeMap[MDLVertexAttributeTangent] {
                let tan = baseAddress.advanced(by: offset).assumingMemoryBound(to: vec3f.self).pointee
                if changeCoordonateSystem {
                    let t = blenderToMetalMatrix * SIMD4<Float>(tan.x, tan.y, tan.z, 0)
                    vertex.tangent = normalize(vec3f(t.x, t.y, t.z))
                } else {
                    vertex.tangent = normalize(tan)
                }
            }
            if let (offset, _) = attributeMap[MDLVertexAttributeBitangent] {
                let bitan = baseAddress.advanced(by: offset).assumingMemoryBound(to: vec3f.self).pointee
                if changeCoordonateSystem {
                    let t = blenderToMetalMatrix * SIMD4<Float>(bitan.x, bitan.y, bitan.z, 0)
                    vertex.bitangent = normalize(vec3f(t.x, t.y, t.z))
                } else {
                    vertex.bitangent = normalize(bitan)
                }
            }
            if let (offset, _) = attributeMap[MDLVertexAttributeJointIndices] {
                let indicesPtr = baseAddress.advanced(by: offset).assumingMemoryBound(to: UInt16.self)
                vertex.jointIndices = SIMD4<UInt16>(indicesPtr[0],
                                                    indicesPtr[1],
                                                    indicesPtr[2],
                                                    indicesPtr[3])
            }
            if let (offset, _) = attributeMap[MDLVertexAttributeJointWeights] {
                let weights = baseAddress.advanced(by: offset).assumingMemoryBound(to: vec4f.self).pointee
                let total = weights.x + weights.y + weights.z + weights.w
                vertex.jointWeights = total > 0 ? weights / total : vec4f(1, 0, 0, 0)
            }
            vertices.append(vertex)
        }
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
                    indices.append(contentsOf: UnsafeBufferPointer(start: ptr, count: indexCount).map { UInt32($0) })
                case .uInt8:
                    let ptr = indexData.assumingMemoryBound(to: UInt8.self)
                    indices.append(contentsOf: UnsafeBufferPointer(start: ptr, count: indexCount).map { UInt32($0) })
                @unknown default:
                    continue
                }
            }
        }
        guard !vertices.isEmpty, !indices.isEmpty else { return nil }
        return MeshData(vertices: vertices, indices: indices)
    }
    
    public func printModelJoints() {
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
    }
    
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
        if let asset = asset {
            if #available(iOS 11.0, macOS 10.13, *) {
                print("Up Axis: \(asset.upAxis)")
            }
            print("Start Time: \(asset.startTime)")
            print("End Time: \(asset.endTime)")
            print("Frame Interval: \(asset.frameInterval)")
        }
    }
}

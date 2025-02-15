import Foundation
import MetalKit
import ModelIO
import simd

public enum ModelLoaderError: Error {
    case failedToLoadAsset(String)
    case invalidMesh
    case missingVertexData
}

public struct ModelVertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var textureCoordinate: SIMD2<Float>
    var tangent: SIMD3<Float>
    var bitangent: SIMD3<Float>
    var jointIndices: SIMD4<UInt16>
    var jointWeights: SIMD4<Float>
    
    init(position: SIMD3<Float> = .zero,
         normal: SIMD3<Float> = .zero,
         textureCoordinate: SIMD2<Float> = .zero,
         tangent: SIMD3<Float> = .zero,
         bitangent: SIMD3<Float> = .zero,
         jointIndices: SIMD4<UInt16> = .init(repeating: 0),
         jointWeights: SIMD4<Float> = .init(1, 0, 0, 0)) {
        self.position = position
        self.normal = normal
        self.textureCoordinate = textureCoordinate
        self.tangent = tangent
        self.bitangent = bitangent
        self.jointIndices = jointIndices
        self.jointWeights = jointWeights
    }
}

public struct MeshData {
    var vertices: [ModelVertex]
    var indices: [UInt32]
}

public class Model3D {
    private(set) var asset: MDLAsset?
    private(set) var meshes: [MDLMesh] = []
    
    private let vertexDescriptor: MDLVertexDescriptor = {
        let descriptor = MDLVertexDescriptor()
        var offset = 0
        
        // Position
        descriptor.attributes[0] = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: offset,
            bufferIndex: 0
        )
        offset += MemoryLayout<SIMD3<Float>>.stride
        
        // Normal
        descriptor.attributes[1] = MDLVertexAttribute(
            name: MDLVertexAttributeNormal,
            format: .float3,
            offset: offset,
            bufferIndex: 0
        )
        offset += MemoryLayout<SIMD3<Float>>.stride
        
        // Texture coordinates
        descriptor.attributes[2] = MDLVertexAttribute(
            name: MDLVertexAttributeTextureCoordinate,
            format: .float2,
            offset: offset,
            bufferIndex: 0
        )
        offset += MemoryLayout<SIMD2<Float>>.stride
        
        // Tangent
        descriptor.attributes[3] = MDLVertexAttribute(
            name: MDLVertexAttributeTangent,
            format: .float3,
            offset: offset,
            bufferIndex: 0
        )
        offset += MemoryLayout<SIMD3<Float>>.stride
        
        // Bitangent
        descriptor.attributes[4] = MDLVertexAttribute(
            name: MDLVertexAttributeBitangent,
            format: .float3,
            offset: offset,
            bufferIndex: 0
        )
        offset += MemoryLayout<SIMD3<Float>>.stride
        
        // Joint indices - Note the format is float4 for reading but will be converted to UInt16
        descriptor.attributes[5] = MDLVertexAttribute(
            name: MDLVertexAttributeJointIndices,
            format: .float4,
            offset: offset,
            bufferIndex: 0
        )
        offset += MemoryLayout<SIMD4<Float>>.stride
        
        // Joint weights
        descriptor.attributes[6] = MDLVertexAttribute(
            name: MDLVertexAttributeJointWeights,
            format: .float4,
            offset: offset,
            bufferIndex: 0
        )
        offset += MemoryLayout<SIMD4<Float>>.stride
        
        descriptor.layouts[0] = MDLVertexBufferLayout(stride: offset)
        return descriptor
    }()
    
    public init() {}
    
    public func load(from url: URL) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw ModelLoaderError.failedToLoadAsset("No Metal device available.")
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
        
        try loadMeshes()
    }
    
    private func loadMeshes() throws {
        guard let foundMeshes = asset?.childObjects(of: MDLMesh.self) as? [MDLMesh] else {
            throw ModelLoaderError.invalidMesh
        }
        
        meshes = foundMeshes
        
        // Add missing attributes if needed
        for mesh in meshes {
            if let attributes = mesh.vertexDescriptor.attributes as? [MDLVertexAttribute] {
                // Add normals if missing
                if !attributes.contains(where: { $0.name == MDLVertexAttributeNormal }) {
                    mesh.addNormals(
                        withAttributeNamed: MDLVertexAttributeNormal,
                        creaseThreshold: 0.5
                    )
                }
                
                // Add tangents and bitangents if missing
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
    
    public func extractMeshData(from mesh: MDLMesh) -> MeshData? {
        guard let vertexBuffer = mesh.vertexBuffers.first,
              let layout = mesh.vertexDescriptor.layouts[0] as? MDLVertexBufferLayout else {
            return nil
        }
        
        let vertexCount = mesh.vertexCount
        var vertices = [ModelVertex]()
        vertices.reserveCapacity(vertexCount)
        
        let map = vertexBuffer.map()
        let data = map.bytes
        let stride = layout.stride
        
        // Create attribute map
        var attributeMap = [String: (offset: Int, format: MDLVertexFormat)]()
        for attribute in mesh.vertexDescriptor.attributes as! [MDLVertexAttribute] {
            attributeMap[attribute.name] = (Int(attribute.offset), attribute.format)
        }
        
        // Extract vertices
        for i in 0..<vertexCount {
            let base = data.advanced(by: i * stride)
            var vertex = ModelVertex()
            
            // Position
            if let (offset, _) = attributeMap[MDLVertexAttributePosition] {
                vertex.position = base.advanced(by: offset)
                    .assumingMemoryBound(to: SIMD3<Float>.self)
                    .pointee
            }
            
            // Normal
            if let (offset, _) = attributeMap[MDLVertexAttributeNormal] {
                vertex.normal = base.advanced(by: offset)
                    .assumingMemoryBound(to: SIMD3<Float>.self)
                    .pointee
            }
            
            // Texture coordinates
            if let (offset, _) = attributeMap[MDLVertexAttributeTextureCoordinate] {
                vertex.textureCoordinate = base.advanced(by: offset)
                    .assumingMemoryBound(to: SIMD2<Float>.self)
                    .pointee
            }
            
            // Tangent
            if let (offset, _) = attributeMap[MDLVertexAttributeTangent] {
                vertex.tangent = base.advanced(by: offset)
                    .assumingMemoryBound(to: SIMD3<Float>.self)
                    .pointee
            }
            
            // Bitangent
            if let (offset, _) = attributeMap[MDLVertexAttributeBitangent] {
                vertex.bitangent = base.advanced(by: offset)
                    .assumingMemoryBound(to: SIMD3<Float>.self)
                    .pointee
            }
            
            // Joint indices
            if let (offset, _) = attributeMap[MDLVertexAttributeJointIndices] {
                let raw = base.advanced(by: offset)
                    .assumingMemoryBound(to: SIMD4<Float>.self)
                    .pointee
                vertex.jointIndices = SIMD4<UInt16>(
                    UInt16(raw.x),
                    UInt16(raw.y),
                    UInt16(raw.z),
                    UInt16(raw.w)
                )
            }
            
            // Joint weights
            if let (offset, _) = attributeMap[MDLVertexAttributeJointWeights] {
                let weights = base.advanced(by: offset)
                    .assumingMemoryBound(to: SIMD4<Float>.self)
                    .pointee
                let total = weights.x + weights.y + weights.z + weights.w
                vertex.jointWeights = total > 0 ? weights / total : SIMD4<Float>(1, 0, 0, 0)
            }
            
            vertices.append(vertex)
        }
        
        // Extract indices
        var indices = [UInt32]()
        for submesh in mesh.submeshes ?? [] {
            guard let submesh = submesh as? MDLSubmesh else { continue }
            
            let indexCount = submesh.indexCount
            let indexBuffer = submesh.indexBuffer
            let indexMap = indexBuffer.map()
            let indexData = indexMap.bytes
            
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
                return nil
            }
        }
        
        return MeshData(vertices: vertices, indices: indices)
    }
}

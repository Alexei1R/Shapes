import Foundation
import MetalKit
import ModelIO
import simd

enum ModelLoaderError: Error {
    case failedToLoadAsset(String)
    case invalidMesh
    case missingVertexData
    case unsupportedIndexFormat
}

public struct ModelVertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var textureCoordinate: SIMD2<Float>
    var tangent: SIMD3<Float>
    var bitangent: SIMD3<Float>
    var jointIndices: SIMD4<UInt16>
    var jointWeights: SIMD4<Float>
}


public struct MeshData {
    var vertices: [ModelVertex]
    var indices: [UInt32]
}

public struct ModelJoint {
    let name: String
    let path: String
    let bindTransform: simd_float4x4
    let restTransform: simd_float4x4
    let parentIndex: Int? // Add parent reference
}


public struct ModelAnimation {
    let name: String
    let jointPaths: [String]
    let translations: [SIMD3<Float>]
    let rotations: [simd_quatf]
    let scales: [SIMD3<Float>]
    let duration: TimeInterval
    let frameInterval: TimeInterval
}

public class Model3D {
    private(set) var asset: MDLAsset?
    private(set) var meshes: [MDLMesh] = []
    private(set) var skeleton: MDLSkeleton?
    private(set) var joints: [ModelJoint] = []
    private(set) var animations: [ModelAnimation] = []
    
    private let vertexDescriptor: MDLVertexDescriptor = {
        let descriptor = MDLVertexDescriptor()
        var offset = 0
        
        descriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                      format: .float3,
                                                      offset: offset,
                                                      bufferIndex: 0)
        offset += MemoryLayout<SIMD3<Float>>.stride
        
        // Normal (Float3)
        descriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                                      format: .float3,
                                                      offset: offset,
                                                      bufferIndex: 0)
        offset += MemoryLayout<SIMD3<Float>>.stride
        
        // Texture Coordinate (Float2)
        descriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                                      format: .float2,
                                                      offset: offset,
                                                      bufferIndex: 0)
        offset += MemoryLayout<SIMD2<Float>>.stride
        
        // Tangent (Float3)
        descriptor.attributes[3] = MDLVertexAttribute(name: MDLVertexAttributeTangent,
                                                      format: .float3,
                                                      offset: offset,
                                                      bufferIndex: 0)
        offset += MemoryLayout<SIMD3<Float>>.stride
        
        // Bitangent (Float3)
        descriptor.attributes[4] = MDLVertexAttribute(name: MDLVertexAttributeBitangent,
                                                      format: .float3,
                                                      offset: offset,
                                                      bufferIndex: 0)
        offset += MemoryLayout<SIMD3<Float>>.stride
        
        // Joint Indices (Float4; will convert to UInt16 when extracting)
        descriptor.attributes[5] = MDLVertexAttribute(name: MDLVertexAttributeJointIndices,
                                                      format: .float4,
                                                      offset: offset,
                                                      bufferIndex: 0)
        offset += MemoryLayout<SIMD4<Float>>.stride
        
        // Joint Weights (Float4)
        descriptor.attributes[6] = MDLVertexAttribute(name: MDLVertexAttributeJointWeights,
                                                      format: .float4,
                                                      offset: offset,
                                                      bufferIndex: 0)
        offset += MemoryLayout<SIMD4<Float>>.stride
        
        descriptor.layouts[0] = MDLVertexBufferLayout(stride: offset)
        return descriptor
    }()
    
    public func load(from url: URL, preserveTopology: Bool = false) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw ModelLoaderError.failedToLoadAsset("No Metal device available.")
        }
        let allocator = MTKMeshBufferAllocator(device: device)
        var mdlError: NSError?
        asset = MDLAsset(url: url,
                         vertexDescriptor: vertexDescriptor,
                         bufferAllocator: allocator,
                         preserveTopology: preserveTopology,
                         error: &mdlError)
        if let err = mdlError {
            throw ModelLoaderError.failedToLoadAsset(err.localizedDescription)
        }
        guard asset != nil else {
            throw ModelLoaderError.failedToLoadAsset(url.lastPathComponent)
        }
        try loadMeshes()
        loadSkeleton()
        loadAnimations()
    }
    
    private func loadMeshes() throws {
        guard let foundMeshes = asset?.childObjects(of: MDLMesh.self) as? [MDLMesh] else {
            throw ModelLoaderError.invalidMesh
        }
        meshes = foundMeshes
        for mesh in meshes {
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
    
    private func loadSkeleton() {
        guard let asset = asset else { return }
        if let skeletons = asset.childObjects(of: MDLSkeleton.self) as? [MDLSkeleton],
           let firstSkeleton = skeletons.first {
            self.skeleton = firstSkeleton
            let paths = firstSkeleton.jointPaths
            let bindTransforms = firstSkeleton.jointBindTransforms
            let restTransforms = firstSkeleton.jointRestTransforms
            
            var pathToIndex = [String: Int]()
            
            // First pass to map paths
            for (index, path) in paths.enumerated() {
                pathToIndex[path as String] = index
            }
            
            // Second pass to build hierarchy
            for (index, path) in paths.enumerated() {
                let components = (path as String).components(separatedBy: "/")
                let parentPath = components.dropLast().joined(separator: "/")
                let parentIndex = pathToIndex[parentPath]
                
                let joint = ModelJoint(
                    name: (path as NSString).lastPathComponent,
                    path: path as String,
                    bindTransform: bindTransforms.float4x4Array[index],
                    restTransform: restTransforms.float4x4Array[index],
                    parentIndex: parentIndex
                )
                joints.append(joint)
            }
            print("✅ Loaded \(joints.count) joints with hierarchy")
        }
    }
    
    
    
    private func loadAnimations() {
        guard let asset = asset else { return }
        if let animationObjects = asset.animations.objects as? [MDLPackedJointAnimation] {
            for packedAnim in animationObjects {
                let translations = packedAnim.translations.float3Array
                let rotations = packedAnim.rotations.floatQuaternionArray
                let scales = packedAnim.scales.float3Array
                if packedAnim.jointPaths.isEmpty || translations.isEmpty || rotations.isEmpty || scales.isEmpty {
                    continue
                }
                let animName: String = {
                    let name = (packedAnim as MDLNamed).name
                    return name.isEmpty ? "Animation_\(animations.count + 1)" : name
                }()
                let anim = ModelAnimation(
                    name: animName,
                    jointPaths: packedAnim.jointPaths,
                    translations: translations,
                    rotations: rotations,
                    scales: scales,
                    duration: asset.endTime,
                    frameInterval: asset.frameInterval
                )
                animations.append(anim)
            }
        }
    }
    
    public func printAllComponents() {
        print("\n=== Model Components ===")
        if let asset = asset {
            print("Frame Interval: \(asset.frameInterval)")
            print("Time Range: \(asset.startTime) to \(asset.endTime)")
            if #available(iOS 11.0, *) {
                print("Up Axis: \(asset.upAxis)")
            }
        }
        print("\nMeshes: \(meshes.count)")
        for (i, mesh) in meshes.enumerated() {
            let name = (mesh as MDLNamed).name.isEmpty ? "Mesh_\(i + 1)" : (mesh as MDLNamed).name
            print("  \(i + 1). \(name) - Vertices: \(mesh.vertexCount)")
        }
        print("\nSkeleton:")
        if let skeleton = skeleton {
            let jointCount = skeleton.jointPaths.count
            print("  Total Joints: \(jointCount)")
            for (i, jointPath) in skeleton.jointPaths.enumerated() {
//                if i >= 5 { break }
                print("  \(i + 1). \(jointPath)")
            }
        } else {
            print("  No skeleton found")
        }
        print("\nAnimations: \(animations.count)")
        for (i, anim) in animations.enumerated() {
            print("  \(i + 1). \(anim.name) - Duration: \(anim.duration)s, Frame Interval: \(anim.frameInterval)s")
        }
    }
    
    public func extractMeshData(from mdlMesh: MDLMesh) -> MeshData? {
        guard let vertexBuffer = mdlMesh.vertexBuffers.first else {
            print("❌ No vertex buffer found in mesh.")
            return nil
        }
        
        let vertexCount = mdlMesh.vertexCount
        var vertices: [ModelVertex] = []
        vertices.reserveCapacity(vertexCount)
        
        let bufferMap = vertexBuffer.map()
        let vertexData = bufferMap.bytes
        guard let layout = mdlMesh.vertexDescriptor.layouts[0] as? MDLVertexBufferLayout else {
            print("❌ No valid layout found in vertex descriptor.")
            return nil
        }
        let stride = layout.stride
        
        var attributeMap: [String: (offset: Int, format: MDLVertexFormat)] = [:]
        for attribute in mdlMesh.vertexDescriptor.attributes as! [MDLVertexAttribute] {
            attributeMap[attribute.name] = (Int(attribute.offset), attribute.format)
        }
        
        for vertexIndex in 0..<vertexCount {
            let baseAddress = vertexData.advanced(by: vertexIndex * stride)
            var vertex = ModelVertex(
                position: SIMD3<Float>.zero,
                normal: SIMD3<Float>.zero,
                textureCoordinate: SIMD2<Float>.zero,
                tangent: SIMD3<Float>.zero,
                bitangent: SIMD3<Float>.zero,
                jointIndices: SIMD4<UInt16>(repeating: 0),
                jointWeights: SIMD4<Float>(1, 0, 0, 0)
            )
            if let (offset, _) = attributeMap[MDLVertexAttributePosition] {
                vertex.position = baseAddress.advanced(by: offset)
                    .assumingMemoryBound(to: SIMD3<Float>.self).pointee
            }
            if let (offset, _) = attributeMap[MDLVertexAttributeNormal] {
                vertex.normal = baseAddress.advanced(by: offset)
                    .assumingMemoryBound(to: SIMD3<Float>.self).pointee
            }
            if let (offset, _) = attributeMap[MDLVertexAttributeTextureCoordinate] {
                vertex.textureCoordinate = baseAddress.advanced(by: offset)
                    .assumingMemoryBound(to: SIMD2<Float>.self).pointee
            }
            if let (offset, _) = attributeMap[MDLVertexAttributeTangent] {
                vertex.tangent = baseAddress.advanced(by: offset)
                    .assumingMemoryBound(to: SIMD3<Float>.self).pointee
            }
            if let (offset, _) = attributeMap[MDLVertexAttributeBitangent] {
                vertex.bitangent = baseAddress.advanced(by: offset)
                    .assumingMemoryBound(to: SIMD3<Float>.self).pointee
            }
            if let (offset, _) = attributeMap[MDLVertexAttributeJointIndices] {
                // Read as SIMD4<Float> then convert to UInt16 values.
                let rawIndices = baseAddress.advanced(by: offset)
                    .assumingMemoryBound(to: SIMD4<Float>.self).pointee
                vertex.jointIndices = SIMD4<UInt16>(UInt16(rawIndices.x),
                                                    UInt16(rawIndices.y),
                                                    UInt16(rawIndices.z),
                                                    UInt16(rawIndices.w))
            }
            if let (offset, _) = attributeMap[MDLVertexAttributeJointWeights] {
                let weights = baseAddress.advanced(by: offset)
                    .assumingMemoryBound(to: SIMD4<Float>.self).pointee
                let total = weights.x + weights.y + weights.z + weights.w
                vertex.jointWeights = total > 0 ? weights / total : SIMD4<Float>(1, 0, 0, 0)
            }
            vertices.append(vertex)
        }
        
        var indices: [UInt32] = []
        // Process indices from every submesh.
        for submesh in mdlMesh.submeshes ?? [] {
            guard let mdlSubmesh = submesh as? MDLSubmesh else {
                continue
            }
            let indexCount = mdlSubmesh.indexCount
            let indexBuffer = mdlSubmesh.indexBuffer
            let indexMap = indexBuffer.map()
            let indexData = indexMap.bytes
            
            switch mdlSubmesh.indexType {
            case .uInt32:
                let ptr = indexData.assumingMemoryBound(to: UInt32.self)
                let submeshIndices = UnsafeBufferPointer(start: ptr, count: indexCount)
                indices.append(contentsOf: submeshIndices)
            case .uInt16:
                let ptr = indexData.assumingMemoryBound(to: UInt16.self)
                let submeshIndices = UnsafeBufferPointer(start: ptr, count: indexCount).map { UInt32($0) }
                indices.append(contentsOf: submeshIndices)
            case .uInt8:
                let ptr = indexData.assumingMemoryBound(to: UInt8.self)
                let submeshIndices = UnsafeBufferPointer(start: ptr, count: indexCount).map { UInt32($0) }
                indices.append(contentsOf: submeshIndices)
            @unknown default:
                print("❌ Unsupported index type encountered in submesh.")
                return nil
            }
            // Debug: Print submesh index data summary.
            if let firstIndex = indices.last, indexCount > 0 {
                print("✅ Submesh processed: index count = \(indexCount), first index = \(firstIndex)")
            }
        }
        
        if let maxIndex = indices.max(), maxIndex >= vertices.count {
            print("⚠️ WARNING: Extracted index out of range: \(maxIndex) >= \(vertices.count)")
        }
        
        return MeshData(vertices: vertices, indices: indices)
    }
}

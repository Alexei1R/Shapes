import Foundation
import MetalKit
import ModelIO
import simd

public enum ModelLoaderError: Error {
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
    let id: Int
    let name: String
    let path: String
    let bindTransform: simd_float4x4
    let restTransform: simd_float4x4
    let parentIndex: Int?
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
    public let targetUp: SIMD3<Float>
    private var conversionMatrix: simd_float4x4 = matrix_identity_float4x4
    private var conversionMatrixInverse: simd_float4x4 = matrix_identity_float4x4
    private var overallConversion: simd_float4x4 = matrix_identity_float4x4
    private var overallConversionInverse: simd_float4x4 = matrix_identity_float4x4
    
    private(set) var asset: MDLAsset?
    private(set) var meshes: [MDLMesh] = []
    private(set) var skeleton: MDLSkeleton?
    private(set) var joints: [ModelJoint] = []
    private(set) var animations: [ModelAnimation] = []
    
    private let vertexDescriptor: MDLVertexDescriptor = {
        let d = MDLVertexDescriptor()
        var offset = 0
        d.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                             format: .float3,
                                             offset: offset,
                                             bufferIndex: 0)
        offset += MemoryLayout<SIMD3<Float>>.stride
        d.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                             format: .float3,
                                             offset: offset,
                                             bufferIndex: 0)
        offset += MemoryLayout<SIMD3<Float>>.stride
        d.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                             format: .float2,
                                             offset: offset,
                                             bufferIndex: 0)
        offset += MemoryLayout<SIMD2<Float>>.stride
        d.attributes[3] = MDLVertexAttribute(name: MDLVertexAttributeTangent,
                                             format: .float3,
                                             offset: offset,
                                             bufferIndex: 0)
        offset += MemoryLayout<SIMD3<Float>>.stride
        d.attributes[4] = MDLVertexAttribute(name: MDLVertexAttributeBitangent,
                                             format: .float3,
                                             offset: offset,
                                             bufferIndex: 0)
        offset += MemoryLayout<SIMD3<Float>>.stride
        d.attributes[5] = MDLVertexAttribute(name: MDLVertexAttributeJointIndices,
                                             format: .float4,
                                             offset: offset,
                                             bufferIndex: 0)
        offset += MemoryLayout<SIMD4<Float>>.stride
        d.attributes[6] = MDLVertexAttribute(name: MDLVertexAttributeJointWeights,
                                             format: .float4,
                                             offset: offset,
                                             bufferIndex: 0)
        offset += MemoryLayout<SIMD4<Float>>.stride
        d.layouts[0] = MDLVertexBufferLayout(stride: offset)
        return d
    }()
    
    public init(targetUp: SIMD3<Float> = vec3f.up) {
        self.targetUp = targetUp
    }
    
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
        if let err = mdlError { throw ModelLoaderError.failedToLoadAsset(err.localizedDescription) }
        guard asset != nil else { throw ModelLoaderError.failedToLoadAsset(url.lastPathComponent) }
        
        let sourceUp: SIMD3<Float>
        if #available(iOS 11.0, *) {
            sourceUp = asset!.upAxis
        } else {
            sourceUp = SIMD3<Float>(0, 0, 1)
        }
        conversionMatrix = rotationMatrix(from: sourceUp, to: targetUp)
        conversionMatrixInverse = conversionMatrix.inverse
        let flipZ = simd_float4x4(diagonal: SIMD4<Float>(1, 1, -1, 1))
        overallConversion = flipZ * conversionMatrix
        overallConversionInverse = conversionMatrixInverse * flipZ
        
        try loadMeshes()
        loadSkeleton()
        loadAnimations()
    }
    
    private func rotationMatrix(from source: SIMD3<Float>, to target: SIMD3<Float>) -> simd_float4x4 {
        let src = normalize(source)
        let tgt = normalize(target)
        let dotVal = dot(src, tgt)
        if dotVal > 0.9999 { return matrix_identity_float4x4 }
        if dotVal < -0.9999 {
            let ortho: SIMD3<Float> = abs(src.x) < 0.1 ? SIMD3<Float>(1, 0, 0) : SIMD3<Float>(0, 1, 0)
            let axis = normalize(cross(src, ortho))
            return mat4f.rotation(angle: .pi, axis: axis)
        }
        let angle = acos(dotVal)
        let axis = normalize(cross(src, tgt))
        return mat4f.rotation(angle: angle, axis: axis)
    }
    
    private func loadMeshes() throws {
        guard let foundMeshes = asset?.childObjects(of: MDLMesh.self) as? [MDLMesh] else { throw ModelLoaderError.invalidMesh }
        meshes = foundMeshes
        for m in meshes {
            if let attrs = m.vertexDescriptor.attributes as? [MDLVertexAttribute] {
                if !attrs.contains(where: { $0.name == MDLVertexAttributeNormal }) {
                    m.addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0.5)
                }
                if !attrs.contains(where: { $0.name == MDLVertexAttributeTangent }) {
                    m.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
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
            skeleton = firstSkeleton
            let paths = firstSkeleton.jointPaths
            let bindTransforms = firstSkeleton.jointBindTransforms
            let restTransforms = firstSkeleton.jointRestTransforms
            var pathToIndex = [String: Int]()
            for (i, p) in paths.enumerated() {
                pathToIndex[p as String] = i
            }
            print(paths.count)
            for (i, p) in paths.enumerated() {
                let comps = (p as String).components(separatedBy: "/")
                let parentPath = comps.dropLast().joined(separator: "/")
                let parentIndex = pathToIndex[parentPath]
                let originalBind = bindTransforms.float4x4Array[i]
                let originalRest = restTransforms.float4x4Array[i]
                let bind = overallConversion * originalBind * overallConversionInverse
                let rest = overallConversion * originalRest * overallConversionInverse
                let joint = ModelJoint(id: i,
                                       name: (p as NSString).lastPathComponent,
                                       path: p as String,
                                       bindTransform: bind,
                                       restTransform: rest,
                                       parentIndex: parentIndex)
                joints.append(joint)
            }
        }
    }
    
    private func loadAnimations() {
        guard let asset = asset else { return }
        if let anims = asset.animations.objects as? [MDLPackedJointAnimation] {
            for packed in anims {
                let translations = packed.translations.float3Array
                let rotations = packed.rotations.floatQuaternionArray
                let scales = packed.scales.float3Array
                if packed.jointPaths.isEmpty || translations.isEmpty || rotations.isEmpty || scales.isEmpty { continue }
                let name = (packed as MDLNamed).name.isEmpty ? "Animation_\(animations.count + 1)" : (packed as MDLNamed).name
                let transformedTranslations = translations.map {
                    let t4 = overallConversion * SIMD4<Float>($0, 0)
                    return SIMD3<Float>(t4.x, t4.y, t4.z)
                }
                let transformedRotations = rotations.map { transformQuaternion($0) }
                let anim = ModelAnimation(name: name,
                                          jointPaths: packed.jointPaths,
                                          translations: transformedTranslations,
                                          rotations: transformedRotations,
                                          scales: scales,
                                          duration: asset.endTime,
                                          frameInterval: asset.frameInterval)
                animations.append(anim)
            }
        }
    }
    
    private func transformQuaternion(_ q: simd_quatf) -> simd_quatf {
        let m = simd_float4x4(q)
        let mTransformed = overallConversion * m * overallConversionInverse
        return simd_quatf(mTransformed)
    }
    
    public func printAllComponents() {
        if let a = asset {
            print("Frame Interval: \(a.frameInterval)")
            print("Time Range: \(a.startTime) to \(a.endTime)")
            if #available(iOS 11.0, *) { print("Up Axis: \(a.upAxis)") }
        }
        print("Meshes: \(meshes.count)")
        for (i, m) in meshes.enumerated() {
            let n = (m as MDLNamed).name.isEmpty ? "Mesh_\(i+1)" : (m as MDLNamed).name
            print("\(i+1). \(n) - Vertices: \(m.vertexCount)")
        }
        print("Animations: \(animations.count)")
        for (i, a) in animations.enumerated() {
            print("\(i+1). \(a.name) - Duration: \(a.duration)s, Frame Interval: \(a.frameInterval)s")
        }
    }
    
    public func extractMeshData(from m: MDLMesh) -> MeshData? {
        guard let vb = m.vertexBuffers.first,
              let layout = m.vertexDescriptor.layouts[0] as? MDLVertexBufferLayout else { return nil }
        let count = m.vertexCount
        var vertices = [ModelVertex]()
        vertices.reserveCapacity(count)
        let map = vb.map()
        let data = map.bytes
        let stride = layout.stride
        var attrMap = [String: (offset: Int, format: MDLVertexFormat)]()
        for a in m.vertexDescriptor.attributes as! [MDLVertexAttribute] {
            attrMap[a.name] = (Int(a.offset), a.format)
        }
        for i in 0..<count {
            let base = data.advanced(by: i * stride)
            var v = ModelVertex(position: SIMD3<Float>.zero,
                                normal: SIMD3<Float>.zero,
                                textureCoordinate: SIMD2<Float>.zero,
                                tangent: SIMD3<Float>.zero,
                                bitangent: SIMD3<Float>.zero,
                                jointIndices: SIMD4<UInt16>(repeating: 0),
                                jointWeights: SIMD4<Float>(1, 0, 0, 0))
            if let (off, _) = attrMap[MDLVertexAttributePosition] {
                var pos = base.advanced(by: off).assumingMemoryBound(to: SIMD3<Float>.self).pointee
                let pos4 = overallConversion * SIMD4<Float>(pos, 1)
                pos = SIMD3<Float>(pos4.x, pos4.y, pos4.z)
                v.position = pos
            }
            if let (off, _) = attrMap[MDLVertexAttributeNormal] {
                var norm = base.advanced(by: off).assumingMemoryBound(to: SIMD3<Float>.self).pointee
                let norm4 = overallConversion * SIMD4<Float>(norm, 0)
                norm = normalize(SIMD3<Float>(norm4.x, norm4.y, norm4.z))
                v.normal = norm
            }
            if let (off, _) = attrMap[MDLVertexAttributeTextureCoordinate] {
                v.textureCoordinate = base.advanced(by: off).assumingMemoryBound(to: SIMD2<Float>.self).pointee
            }
            if let (off, _) = attrMap[MDLVertexAttributeTangent] {
                var tan = base.advanced(by: off).assumingMemoryBound(to: SIMD3<Float>.self).pointee
                let tan4 = overallConversion * SIMD4<Float>(tan, 0)
                tan = normalize(SIMD3<Float>(tan4.x, tan4.y, tan4.z))
                v.tangent = tan
            }
            if let (off, _) = attrMap[MDLVertexAttributeBitangent] {
                var bitan = base.advanced(by: off).assumingMemoryBound(to: SIMD3<Float>.self).pointee
                let bitan4 = overallConversion * SIMD4<Float>(bitan, 0)
                bitan = normalize(SIMD3<Float>(bitan4.x, bitan4.y, bitan4.z))
                v.bitangent = bitan
            }
            if let (off, _) = attrMap[MDLVertexAttributeJointIndices] {
                let raw = base.advanced(by: off).assumingMemoryBound(to: SIMD4<Float>.self).pointee
                v.jointIndices = SIMD4<UInt16>(UInt16(raw.x),
                                               UInt16(raw.y),
                                               UInt16(raw.z),
                                               UInt16(raw.w))
            }
            if let (off, _) = attrMap[MDLVertexAttributeJointWeights] {
                let w = base.advanced(by: off).assumingMemoryBound(to: SIMD4<Float>.self).pointee
                let total = w.x + w.y + w.z + w.w
                v.jointWeights = total > 0 ? w / total : SIMD4<Float>(1, 0, 0, 0)
            }
            vertices.append(v)
        }
        var indices = [UInt32]()
        for submesh in m.submeshes ?? [] {
            guard let sm = submesh as? MDLSubmesh else { continue }
            let idxCount = sm.indexCount
            let ib = sm.indexBuffer
            let map = ib.map()
            let d = map.bytes
            switch sm.indexType {
            case .uInt32:
                let ptr = d.assumingMemoryBound(to: UInt32.self)
                indices.append(contentsOf: UnsafeBufferPointer(start: ptr, count: idxCount))
            case .uInt16:
                let ptr = d.assumingMemoryBound(to: UInt16.self)
                indices.append(contentsOf: UnsafeBufferPointer(start: ptr, count: idxCount).map { UInt32($0) })
            case .uInt8:
                let ptr = d.assumingMemoryBound(to: UInt8.self)
                indices.append(contentsOf: UnsafeBufferPointer(start: ptr, count: idxCount).map { UInt32($0) })
            @unknown default:
                return nil
            }
        }
        return MeshData(vertices: vertices, indices: indices)
    }
}

extension mat4f {
    public static func rotation(angle: Float, axis: SIMD3<Float>) -> simd_float4x4 {
        let c = cos(angle)
        let s = sin(angle)
        let t = 1 - c
        let x = axis.x, y = axis.y, z = axis.z
        return simd_float4x4(
            SIMD4<Float>(t * x * x + c,     t * x * y + s * z,   t * x * z - s * y, 0),
            SIMD4<Float>(t * x * y - s * z,   t * y * y + c,       t * y * z + s * x, 0),
            SIMD4<Float>(t * x * z + s * y,   t * y * z - s * x,   t * z * z + c,     0),
            SIMD4<Float>(0,                   0,                   0,                 1)
        )
    }
}

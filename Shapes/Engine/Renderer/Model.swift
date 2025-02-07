
import ModelIO
import MetalKit

enum ModelLoaderError: Error {
    case failedToLoadAsset(String)
    case invalidMesh
    case missingVertexData
    case unsupportedFormat
    case textureLoadingFailed(String)
    case animationError(String)
}

struct ModelVertex {
    var position: vec3f
    var normal: vec3f
    var textureCoordinate: vec2f
    var tangent: vec3f
    var bitangent: vec3f
}

struct ModelTexture {
    let name: String
    let path: String
    let type: TextureType
    var texture: MDLTexture?
    
    enum TextureType {
        case diffuse
        case normal
        case metallic
        case roughness
        case ambientOcclusion
        case emission
    }
}

struct ModelJoint {
    let name: String
    let path: String
    let bindTransform: matrix_float4x4
    let restTransform: matrix_float4x4
}

struct ModelAnimation {
    let name: String
    let jointPaths: [String]
    let translations: [SIMD3<Float>]
    let rotations: [simd_quatf]
    let scales: [SIMD3<Float>]
    let duration: TimeInterval
    let frameInterval: TimeInterval
}

struct ModelCamera {
    let name: String
    let position: vec3f
    let rotation: simd_quatf
    let fieldOfView: Float
    let nearPlane: Float
    let farPlane: Float}

struct ModelLight {
    let name: String
    let type: LightType
    let color: vec3f
    let intensity: Float
    let position: vec3f
    let direction: vec3f?
    
    enum LightType {
        case directional
        case point
        case spot
        case area
    }
}

class Model3D {
    
    private(set) var asset: MDLAsset?
    private(set) var meshes: [MDLMesh] = []
    private(set) var textures: [ModelTexture] = []
    private(set) var skeleton: MDLSkeleton?
    private(set) var joints: [ModelJoint] = []
    private(set) var animations: [ModelAnimation] = []
    private(set) var cameras: [ModelCamera] = []
    private(set) var lights: [ModelLight] = []
    
    private let vertexDescriptor: MDLVertexDescriptor = {
        let descriptor = MDLVertexDescriptor()
        descriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                      format: .float3,
                                                      offset: 0,
                                                      bufferIndex: 0)
        descriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                                      format: .float3,
                                                      offset: 12,
                                                      bufferIndex: 0)
        descriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                                      format: .float2,
                                                      offset: 24,
                                                      bufferIndex: 0)
        descriptor.attributes[3] = MDLVertexAttribute(name: MDLVertexAttributeTangent,
                                                      format: .float3,
                                                      offset: 32,
                                                      bufferIndex: 0)
        descriptor.attributes[4] = MDLVertexAttribute(name: MDLVertexAttributeBitangent,
                                                      format: .float3,
                                                      offset: 44,
                                                      bufferIndex: 0)
        descriptor.layouts[0] = MDLVertexBufferLayout(stride: 56)
        return descriptor
    }()
    
    func load(from url: URL, preserveTopology: Bool = false) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw ModelLoaderError.failedToLoadAsset("No Metal device found.")
        }
        let allocator = MTKMeshBufferAllocator(device: device)
        var error: NSError?
        asset = MDLAsset(url: url,
                         vertexDescriptor: vertexDescriptor,
                         bufferAllocator: allocator,
                         preserveTopology: preserveTopology,
                         error: &error)
        if let error = error {
            throw ModelLoaderError.failedToLoadAsset(error.localizedDescription)
        }
        guard let asset = asset else {
            throw ModelLoaderError.failedToLoadAsset(url.lastPathComponent)
        }
        
        print("///////////////////////////////////////////////////////////////////////////////////////")
        
        try loadMeshes()
        loadSkeleton()
        loadAnimations()
        loadCameras()
        loadLights()
    }
    
    private func loadMeshes() throws {
        if let foundMeshes = asset?.childObjects(of: MDLMesh.self) as? [MDLMesh] {
            meshes = foundMeshes
        } else {
            meshes = []
        }
        for mesh in meshes {
            if let attributes = mesh.vertexDescriptor.attributes as? [MDLVertexAttribute] {
                if !attributes.contains(where: { $0.name == MDLVertexAttributeNormal }) {
                    mesh.addNormals(withAttributeNamed: MDLVertexAttributeNormal,
                                    creaseThreshold: 0.5)
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
            let jointCount = paths.count
            let maxJointsToStore = 5
            for i in 0..<jointCount {
                let joint = ModelJoint(
                    name: (paths[i] as NSString).lastPathComponent,
                    path: paths[i],
                    bindTransform: bindTransforms.float4x4Array[i],
                    restTransform: restTransforms.float4x4Array[i]
                )
                joints.append(joint)
                if i + 1 == maxJointsToStore { break }
            }
        }
    }
    
    private func loadAnimations() {
        guard let asset = asset else { return }
        let animationsContainer = asset.animations
        if animationsContainer.objects.count > 0 {
            for object in animationsContainer.objects {
                if let packedAnim = object as? MDLPackedJointAnimation {
                    let translationsArray = packedAnim.translations.float3Array
                    let rotationsArray = packedAnim.rotations.floatQuaternionArray
                    let scalesArray = packedAnim.scales.float3Array
                    if packedAnim.jointPaths.isEmpty ||
                        translationsArray.isEmpty ||
                        rotationsArray.isEmpty ||
                        scalesArray.isEmpty {
                        continue
                    }
                    let animationName = (packedAnim as MDLNamed).name.isEmpty ?
                    "Animation_\(animations.count + 1)" :
                    (packedAnim as MDLNamed).name
                    let anim = ModelAnimation(
                        name: animationName,
                        jointPaths: packedAnim.jointPaths,
                        translations: translationsArray,
                        rotations: rotationsArray,
                        scales: scalesArray,
                        duration: asset.endTime,
                        frameInterval: asset.frameInterval
                    )
                    animations.append(anim)
                }
            }
        } else if let packedAnimations = asset.childObjects(of: MDLPackedJointAnimation.self) as? [MDLPackedJointAnimation],
                  !packedAnimations.isEmpty {
            for animation in packedAnimations {
                let translationsArray = animation.translations.float3Array
                let rotationsArray = animation.rotations.floatQuaternionArray
                let scalesArray = animation.scales.float3Array
                if animation.jointPaths.isEmpty ||
                    translationsArray.isEmpty ||
                    rotationsArray.isEmpty ||
                    scalesArray.isEmpty {
                    continue
                }
                let animationName = (animation as MDLNamed).name.isEmpty ?
                "Animation_\(animations.count + 1)" :
                (animation as MDLNamed).name
                let anim = ModelAnimation(
                    name: animationName,
                    jointPaths: animation.jointPaths,
                    translations: translationsArray,
                    rotations: rotationsArray,
                    scales: scalesArray,
                    duration: asset.endTime,
                    frameInterval: asset.frameInterval
                )
                animations.append(anim)
            }
        }
    }
    
    private func loadCameras() {
        let cameraObjects = asset?.childObjects(of: MDLCamera.self) as? [MDLCamera] ?? []
        for camera in cameraObjects {
            let transform = camera.transform?.matrix ?? matrix_identity_float4x4
            let position = vec3f(transform.columns.3.x,
                                 transform.columns.3.y,
                                 transform.columns.3.z)
            // Extract rotation from the transform matrix.
            let rotation = simd_quaternion(transform)
            let cameraName = (camera as MDLNamed).name.isEmpty ?
            "Camera_\(cameras.count + 1)" : (camera as MDLNamed).name
            cameras.append(ModelCamera(
                name: cameraName,
                position: position,
                rotation: rotation,
                fieldOfView: camera.fieldOfView,
                nearPlane: 0.1,
                farPlane: 100.0
            ))
        }    }
    
    private func loadLights() {
        let lightObjects = asset?.childObjects(of: MDLLight.self) as? [MDLLight] ?? []
        for light in lightObjects {
            let transform = light.transform?.matrix ?? matrix_identity_float4x4
            let position = vec3f(transform.columns.3.x,
                                 transform.columns.3.y,
                                 transform.columns.3.z)
            let defaultColor = vec3f(1.0, 1.0, 1.0)
            let lightType: ModelLight.LightType
            let lightClassName = String(describing: type(of: light))
            switch lightClassName {
            case "MDLPhysicallyPlausibleLight":
                lightType = .directional
            case "MDLAreaLight":
                lightType = .area
            case "MDLPhotometricLight":
                lightType = .spot
            default:
                lightType = .point
            }
            let lightName = (light as MDLNamed).name.isEmpty ?
            "Light_\(lights.count + 1)" : (light as MDLNamed).name
            lights.append(ModelLight(
                name: lightName,
                type: lightType,
                color: defaultColor,
                intensity: 1.0,
                position: position,
                direction: lightType == .directional ? vec3f(0, 0, -1) : nil
            ))
        }
    }
    
    public func printAllComponents() {
        print("\n=== Model Component Summary ===")
        if let asset = asset {
            print("Frame Interval: \(asset.frameInterval)")
            print("Time Range: \(asset.startTime) to \(asset.endTime)")
            if #available(iOS 11.0, *) {
                print("Up Axis: \(asset.upAxis)")
            }
        }
        print("\nMeshes: \(meshes.count)")
        for (index, mesh) in meshes.enumerated() {
            let name = (mesh as MDLNamed).name
            let meshName = name.isEmpty ? "Mesh_\(index + 1)" : name
            print("  \(index + 1). \(meshName) - Vertices: \(mesh.vertexCount)")
        }
        print("\nSkeleton:")
        if let skeleton = skeleton {
            let totalJoints = skeleton.jointPaths.count
            let jointsToPrint = min(totalJoints, 5)
            print("  Joints: \(totalJoints)")
            for i in 0..<jointsToPrint {
                print("  \(i + 1). \(skeleton.jointPaths[i])")
            }
            if totalJoints > jointsToPrint {
                print("  ...")
            }
        } else {
            print("  No skeleton found")
        }
        print("\nAnimations: \(animations.count)")
        for (index, animation) in animations.enumerated() {
            print("  \(index + 1). \(animation.name) - Duration: \(animation.duration)s, Frame Interval: \(animation.frameInterval)s")
        }
        print("\nCameras: \(cameras.count)")
        for (index, camera) in cameras.enumerated() {
            print("  \(index + 1). \(camera.name) - Position: (\(camera.position.x), \(camera.position.y), \(camera.position.z)), FOV: \(camera.fieldOfView)")
        }
        print("\nLights: \(lights.count)")
        for (index, light) in lights.enumerated() {
            print("  \(index + 1). \(light.name) - Type: \(light.type), Color: (\(light.color.x), \(light.color.y), \(light.color.z)), Position: (\(light.position.x), \(light.position.y), \(light.position.z))")
        }
        print("============================\n")
    }
}


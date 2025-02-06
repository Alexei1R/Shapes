//
//  Model.swift
//  Shapes
//
//  Created by Alexei1R on 2025-02-06 07:35:41
//

import ModelIO
import MetalKit

// MARK: - Errors
enum ModelLoaderError: Error {
    case failedToLoadAsset(String)
    case invalidMesh
    case missingVertexData
    case unsupportedFormat
    case textureLoadingFailed(String)
    case animationError(String)
}

// MARK: - Model Components
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
    let target: vec3f
    let fieldOfView: Float
    let nearPlane: Float
    let farPlane: Float
}

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

// MARK: - Main Model Class
class Model3D {
    private(set) var asset: MDLAsset?
    private(set) var meshes: [MDLMesh] = []
    private(set) var textures: [ModelTexture] = []
    private(set) var skeleton: MDLSkeleton?
    private(set) var joints: [ModelJoint] = []
    private(set) var animations: [ModelAnimation] = []
    private(set) var cameras: [ModelCamera] = []
    private(set) var lights: [ModelLight] = []
    
    // Asset loading options
    private let vertexDescriptor: MDLVertexDescriptor = {
        let descriptor = MDLVertexDescriptor()
        // Position
        descriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                        format: .float3,
                                                        offset: 0,
                                                        bufferIndex: 0)
        // Normal
        descriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                                        format: .float3,
                                                        offset: 12,
                                                        bufferIndex: 0)
        // Texture Coordinates
        descriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                                        format: .float2,
                                                        offset: 24,
                                                        bufferIndex: 0)
        // Tangent
        descriptor.attributes[3] = MDLVertexAttribute(name: MDLVertexAttributeTangent,
                                                        format: .float3,
                                                        offset: 32,
                                                        bufferIndex: 0)
        // Bitangent
        descriptor.attributes[4] = MDLVertexAttribute(name: MDLVertexAttributeBitangent,
                                                        format: .float3,
                                                        offset: 44,
                                                        bufferIndex: 0)
        descriptor.layouts[0] = MDLVertexBufferLayout(stride: 56)
        return descriptor
    }()
    
    // MARK: - Loading Methods
    func load(from url: URL, preserveTopology: Bool = false) throws {
        // Create asset allocator
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw ModelLoaderError.failedToLoadAsset("No Metal device found.")
        }
        let allocator = MTKMeshBufferAllocator(device: device)
        
        // Load the asset with topology preservation if requested
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
        
        // Load textures automatically if available
        if #available(iOS 11.0, *) {
            asset.loadTextures()
        }
        
        // Load all components
        try loadMeshes()
        loadSkeleton()      // Updated to use MDLSkeleton, prints only a subset of joints.
        loadAnimations()    // Updated to support multiple types of animations.
        loadCameras()
        loadLights()        // Updated to support lights in multiple cases.
        
        // Print essential components for debugging (filtering output for brevity)
        printAvailableComponents()
    }
    
    private func loadMeshes() throws {
        // Explicitly cast each child object to MDLMesh
        if let foundMeshes = asset?.childObjects(of: MDLMesh.self) as? [MDLMesh] {
            meshes = foundMeshes
        } else {
            meshes = []
        }
        
        // For each mesh, check if normals and tangents exist otherwise generate them.
        for mesh in meshes {
            if let attributes = mesh.vertexDescriptor.attributes as? [MDLVertexAttribute] {
                if !attributes.contains(where: { $0.name == MDLVertexAttributeNormal }) {
                    print("DEBUG: Mesh \(mesh.name) missing normals. Adding normals.")
                    mesh.addNormals(withAttributeNamed: MDLVertexAttributeNormal,
                                    creaseThreshold: 0.5)
                }
                if !attributes.contains(where: { $0.name == MDLVertexAttributeTangent }) {
                    print("DEBUG: Mesh \(mesh.name) missing tangents. Generating tangent basis.")
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
            
            print("DEBUG: Found skeleton with \(jointCount) joints.")
            
            // Only print a subset of joints to avoid clutter
            let maxJointsToPrint = 5
            for i in 0..<jointCount {
                let joint = ModelJoint(
                    name: (paths[i] as NSString).lastPathComponent,
                    path: paths[i],
                    bindTransform: bindTransforms.float4x4Array[i],
                    restTransform: restTransforms.float4x4Array[i]
                )
                joints.append(joint)
                if i < maxJointsToPrint {
                    print("DEBUG: Loaded joint \(joint.name) with path \(joint.path)")
                }
            }
            if jointCount > maxJointsToPrint {
                print("DEBUG: ... \(jointCount - maxJointsToPrint) more joints loaded")
            }
        } else {
            print("DEBUG: No skeleton found in asset.")
        }
    }
    
    private func loadAnimations() {
        guard let asset = asset else { return }
        var foundAnimation = false
        
        // First, check for MDLPackedJointAnimation types (MDLPackedJointAnimation is an MDLObject subclass)
        if let packedAnimations = asset.childObjects(of: MDLPackedJointAnimation.self) as? [MDLPackedJointAnimation],
           !packedAnimations.isEmpty {
            print("DEBUG: Found \(packedAnimations.count) packed joint animations in asset.")
            for animation in packedAnimations {
                let translationsArray = animation.translations.float3Array
                let rotationsArray = animation.rotations.floatQuaternionArray
                let scalesArray = animation.scales.float3Array
                
                print("DEBUG: Animation '\((animation as MDLNamed).name)' details:")
                print("       jointPaths count: \(animation.jointPaths.count)")
                print("       translations count: \(translationsArray.count)")
                print("       rotations count: \(rotationsArray.count)")
                print("       scales count: \(scalesArray.count)")
                
                if animation.jointPaths.isEmpty ||
                    translationsArray.isEmpty ||
                    rotationsArray.isEmpty ||
                    scalesArray.isEmpty {
                    print("WARNING: Animation '\((animation as MDLNamed).name)' has incomplete animation data.")
                    continue
                }
                
                let animationName = (animation as MDLNamed).name.isEmpty ?
                                    "Animation_\(animations.count + 1)" : (animation as MDLNamed).name
                
                let anim = ModelAnimation(
                    name: animationName,
                    jointPaths: animation.jointPaths,
                    translations: translationsArray,
                    rotations: rotationsArray,
                    scales: scalesArray,
                    duration: asset.endTime, // Adjust if necessary.
                    frameInterval: asset.frameInterval
                )
                animations.append(anim)
                print("DEBUG: Imported animation '\(anim.name)' with duration \(anim.duration)s and frame interval \(anim.frameInterval)s")
                foundAnimation = true
            }
        }
        
        // Next, check for animations embedded in MDLAnimationBindComponent via the asset.animations container.
        // Note: MDLAnimationBindComponent is not an MDLObject subclass so we cannot query it via childObjects(of:).
        if let animationsContainer = asset.animations as? MDLObjectContainerComponent {
            for object in animationsContainer.objects {
                if let bindComponent = object as? MDLAnimationBindComponent,
                   let jointAnim = bindComponent.jointAnimation {
                    if let packedAnim = jointAnim as? MDLPackedJointAnimation {
                        let translationsArray = packedAnim.translations.float3Array
                        let rotationsArray = packedAnim.rotations.floatQuaternionArray
                        let scalesArray = packedAnim.scales.float3Array
                        
                        if packedAnim.jointPaths.isEmpty ||
                            translationsArray.isEmpty ||
                            rotationsArray.isEmpty ||
                            scalesArray.isEmpty {
                            print("WARNING: Animation from bind component '\((packedAnim as MDLNamed).name)' has incomplete data.")
                            continue
                        }
                        
                        let animationName = (packedAnim as MDLNamed).name.isEmpty ?
                                            "Animation_\(animations.count + 1)" : (packedAnim as MDLNamed).name
                        
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
                        print("DEBUG: Imported animation from bind component '\(anim.name)' with duration \(anim.duration)s and frame interval \(anim.frameInterval)s")
                        foundAnimation = true
                    } else {
                        print("DEBUG: Found non-packed joint animation of type \(jointAnim.self). Support for this type can be added as needed.")
                    }
                }
            }
        }
        
        if !foundAnimation {
            print("DEBUG: No joint animations found in asset.")
        }
    }
    
    private func loadCameras() {
        let cameraObjects = asset?.childObjects(of: MDLCamera.self) as? [MDLCamera] ?? []
        print("DEBUG: Found \(cameraObjects.count) camera(s) in asset.")
        for camera in cameraObjects {
            let transform = camera.transform?.matrix ?? matrix_identity_float4x4
            let position = vec3f(transform.columns.3.x,
                                 transform.columns.3.y,
                                 transform.columns.3.z)
            
            let cameraName = (camera as MDLNamed).name.isEmpty ?
                             "Camera_\(cameras.count + 1)" : (camera as MDLNamed).name
            
            cameras.append(ModelCamera(
                name: cameraName,
                position: position,
                target: vec3f(0, 0, -1),
                fieldOfView: camera.fieldOfView,
                nearPlane: 0.1,
                farPlane: 100.0
            ))
            print("DEBUG: Loaded camera '\(cameraName)' at position (\(position.x), \(position.y), \(position.z)) with FOV \(camera.fieldOfView)")
        }
    }
    
    private func loadLights() {
        // Support multiple MDLLight types.
        let lightObjects = asset?.childObjects(of: MDLLight.self) as? [MDLLight] ?? []
        print("DEBUG: Found \(lightObjects.count) light(s) in asset.")
        
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
            print("DEBUG: Loaded light '\(lightName)' with type \(lightType) at position (\(position.x), \(position.y), \(position.z))")
        }
    }
    
    // MARK: - Utility Methods
    func printAvailableComponents() {
        print("\n=== Model Component Summary ===")
        // Asset Info
        if let asset = asset {
            print("Frame Interval: \(asset.frameInterval)")
            print("Time Range: \(asset.startTime) to \(asset.endTime)")
            if #available(iOS 11.0, *) {
                print("Up Axis: \(asset.upAxis)")
            }
        }
        
        // Meshes
        print("\nMeshes: \(meshes.count)")
        for (index, mesh) in meshes.enumerated() {
            let name = (mesh as MDLNamed).name
            let meshName = name.isEmpty ? "Mesh_\(index + 1)" : name
            print("  \(index + 1). \(meshName) - Vertices: \(mesh.vertexCount)")
        }
        
        // Skeleton - print only a subset for brevity
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
        
        // Animations
        print("\nAnimations: \(animations.count)")
        for (index, animation) in animations.enumerated() {
            print("  \(index + 1). \(animation.name) - Duration: \(animation.duration)s, Frame Interval: \(animation.frameInterval)s")
        }
        
        // Cameras
        print("\nCameras: \(cameras.count)")
        for (index, camera) in cameras.enumerated() {
            print("  \(index + 1). \(camera.name) - Position: (\(camera.position.x), \(camera.position.y), \(camera.position.z)), FOV: \(camera.fieldOfView)")
        }
        
        // Lights
        print("\nLights: \(lights.count)")
        for (index, light) in lights.enumerated() {
            print("  \(index + 1). \(light.name) - Type: \(light.type), Color: (\(light.color.x), \(light.color.y), \(light.color.z)), Position: (\(light.position.x), \(light.position.y), \(light.position.z))")
        }
        print("============================\n")
    }
}

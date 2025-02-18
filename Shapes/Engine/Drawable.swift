import Foundation
import MetalKit

enum MovementMode {
    case rotate
    case moveInPlane
}

let modelToAppleMapping: [Int: Int] = [
    0: 1, 1: 12, 2: 13, 3: 14, 4: 15, 5: 16,
    6: 17, 7: 19, 8: 20, 9: 21, 10: 22, 11: 23,
    12: 24, 13: 25, 14: 26, 15: 27, 16: 28, 17: 29,
    18: 30, 19: 31, 20: 32, 21: 33, 22: 34, 23: 35,
    24: 36, 25: 37, 26: 38, 27: 39, 28: 40, 29: 41,
    30: 42, 31: 43, 32: 44, 33: 45, 34: 46, 35: 47,
    36: 48, 37: 49, 38: 50, 39: 51, 40: 52, 41: 53,
    42: 54, 43: 55, 44: 56, 45: 57, 46: 58, 47: 59,
    48: 60, 49: 61, 50: 62, 51: 63, 52: 64, 53: 65,
    54: 66, 55: 67, 56: 68, 57: 69, 58: 70, 59: 71,
    60: 72, 61: 73, 62: 74, 63: 75, 64: 76
]

func convertAppleToModelMatrix(_ appleMatrix: mat4f) -> mat4f {
    let correction = mat4f(rows: [
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, -1, 0, 0),
        SIMD4<Float>(0, 0, -1, 0),
        SIMD4<Float>(0, 0, 0, 1)
    ])
    return correction * appleMatrix
}

func updateJointMatrices(recordedAppleMatrices: [mat4f], modelBindPoseInverses: [mat4f]) -> [mat4f] {
    var finalMatrices = Array(repeating: mat4f.identity, count: 65)
    for modelIndex in 0..<65 {
        if let appleIndex = modelToAppleMapping[modelIndex] {
            let appleMatrix = recordedAppleMatrices[appleIndex]
            let converted = convertAppleToModelMatrix(appleMatrix)
            finalMatrices[modelIndex] = converted * modelBindPoseInverses[modelIndex]
        }
    }
    return finalMatrices
}

class Drawable: NSObject, ObservableObject {
    let device: MTLDevice
    var commandQueue: MTLCommandQueue!
    var modelPipelineState: MTLRenderPipelineState!
    private var depthStencilState: MTLDepthStencilState!
    private var camera: Camera!
    private var time = Time()
    private var renderPassDescriptor: RenderPassDescriptor?
    private var grid: Grid!
    
    @Published var selectedAnimation: CapturedAnimation?
    @Published var currentJointIndex: Int = 1
    
    private var customAnimation: CustomAnimation?
    private var circleRenderer: CircleRenderer!
    private var jointMatrices: [mat4f] = []
    
    private var modelAsset: Model3D?
    private var vertexBuffer: MetalBuffer<ModelVertex>?
    private var indexBuffer: MetalBuffer<UInt32>?
    private var jointMatricesBuffer: MetalBuffer<mat4f>?
    
    var model: mat4f = mat4f.identity
        .scale(vec3f(0.01))
        .translate(vec3f.forward * 0.5)
    
    struct ModelUniforms {
        var viewProjectionMatrix: mat4f
        var modelMatrix: mat4f
        var time: Float
        var hasAnimation: Int32
        var jointIndex: Int32
    }
    
    private var uniformsBuffer: MetalBuffer<ModelUniforms>!
    var movementMode: MovementMode = .rotate
    
    init(device: MTLDevice) {
        self.device = device
        super.init()
        setupCamera()
        buildPipeline()
        setupScene()
        loadModel()
    }
    
    private func setupCamera() {
        camera = Camera(
            position: vec3f(0, 1, -5),
            target: vec3f.zero,
            up: vec3f.up,
            fieldOfView: Float.pi / 3,
            aspectRatio: 1.0,
            nearPlane: 0.1,
            farPlane: 100.0
        )
    }
    
    private func setupScene() {
        grid = Grid(device: device)
        circleRenderer = CircleRenderer(device: device)
        customAnimation = CustomAnimation()
        jointMatricesBuffer = MetalBuffer<mat4f>(
            device: device,
            count: 100,
            usage: .storageShared
        )
        let identityMatrices = Array(repeating: mat4f.identity, count: 100)
        jointMatricesBuffer?.update(with: identityMatrices)
    }
    
    private func loadModel() {
        if let modelPath = Bundle.main.path(forResource: "girl", ofType: "usdc") {
            let modelURL = URL(fileURLWithPath: modelPath)
            if let device = Engine.shared?.device {
                let model3D = Model3D()
                do {
                    try model3D.load(from: modelURL)
                    model3D.printModelInfo()
                    if let firstMesh = model3D.meshes.first,
                       let meshData = model3D.extractMeshData(from: firstMesh) {
                        vertexBuffer = MetalBuffer<ModelVertex>(
                            device: device,
                            elements: meshData.vertices,
                            usage: .storageShared
                        )
                        indexBuffer = MetalBuffer<UInt32>(
                            device: device,
                            elements: meshData.indices,
                            usage: .storageShared
                        )
                    }
                    self.modelAsset = model3D
                    print("Model loaded successfully with \(model3D.meshes.count) meshes")
                } catch {
                    print("Failed to load model: \(error)")
                }
            }
        }
    }
    
    private func buildPipeline() {
        commandQueue = device.makeCommandQueue()
        let modelPipelineDescriptor = MTLRenderPipelineDescriptor()
        let layout = ShaderLayout([
            ShaderElement(type: .vertex, data: "model_vertex_main"),
            ShaderElement(type: .fragment, data: "model_fragment_main")
        ])
        do {
            let shaderHandle = try ShaderManager.shared.loadShader(layout: layout)
            if let shader = ShaderManager.shared.getShader(shaderHandle) {
                modelPipelineDescriptor.vertexFunction = shader.function(of: .vertex)
                modelPipelineDescriptor.fragmentFunction = shader.function(of: .fragment)
            }
        } catch {
            print("Shader loading error: \(error)")
        }
        let vertexLayout = BufferLayout(elements: [
            BufferElement(type: .float3, name: "position"),
            BufferElement(type: .float3, name: "normal"),
            BufferElement(type: .float2, name: "textureCoordinate"),
            BufferElement(type: .float3, name: "tangent"),
            BufferElement(type: .float3, name: "bitangent"),
            BufferElement(type: .uint16x4, name: "jointIndices"),
            BufferElement(type: .float4, name: "jointWeights")
        ])
        modelPipelineDescriptor.vertexDescriptor = vertexLayout.metalVertexDescriptor(bufferIndex: 0)
        modelPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        modelPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        modelPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        modelPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        modelPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        modelPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        modelPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        modelPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        modelPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        do {
            modelPipelineState = try device.makeRenderPipelineState(descriptor: modelPipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
    }
    
    func setAnimation(_ animation: CapturedAnimation) {
        selectedAnimation = animation
        customAnimation?.play(animation: animation)
        print("Animation set: \(animation.name)")
    }
    
    func pauseAnimation() {
        customAnimation?.pause()
        print("Animation paused")
    }
    
    func resumeAnimation() {
        customAnimation?.resume()
        print("Animation resumed")
    }
    
    func stopAnimation() {
        customAnimation?.stop()
        selectedAnimation = nil
        jointMatrices.removeAll()
        circleRenderer.updateCircles([])
        let identityMatrices = Array(repeating: mat4f.identity, count: 100)
        jointMatricesBuffer?.update(with: identityMatrices)
        print("Animation stopped")
    }
    
    func setMovementMode(_ mode: MovementMode) {
        movementMode = mode
    }
    
    func selectNextJoint() {
        if let model = modelAsset {
            let maxJoint = model.joints.isEmpty ? 0 : model.joints.count - 1
            currentJointIndex = min(maxJoint, currentJointIndex + 1)
        }
    }
    
    func selectPreviousJoint() {
        currentJointIndex = max(0, currentJointIndex - 1)
    }
    
    func printRecordedJoints() { }
    
    func printModelJoints(){
        print("those ar the model joints")
        if let model = modelAsset {
            print("Model joints count \(model.joints.count)")
            model.printModelJoints()
        }
        print(" those ar the recorded joints")
        if let animation = selectedAnimation, let customAnim = customAnimation {
            print("Recording apple joints count \(animation.capturedFrames[0].joints.count)")
            customAnim.printTree()
        }
        print("how i can make the conversiont/ use the corect matrices ?")
    }
}

extension Drawable: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        camera.setAspectRatio(Float(size.width) / Float(size.height))
    }
    
    func draw(in view: MTKView) {
        guard let renderPassDescriptor = setupRenderPass(view: view),
              let drawableTarget = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else { return }
        
        time.update()
        
        if EventManager.shared.isActive, let event = EventManager.shared.currentEvent {
            switch event.type {
            case .drag:
                switch movementMode {
                case .rotate:
                    camera.orbit(deltaTheta: Float(event.delta.x) * 0.005, deltaPhi: Float(event.delta.y) * 0.005)
                case .moveInPlane:
                    camera.moveInPlane(deltaX: Float(event.delta.x) * 0.01, deltaY: Float(event.delta.y) * 0.01)
                }
            case .pinch:
                camera.zoom(factor: Float(event.scale))
            default:
                break
            }
        }
        
        grid.render(encoder: renderEncoder, viewProjectionMatrix: camera.getViewProjectionMatrix())
        
        if let animation = selectedAnimation,
           let customAnim = customAnimation,
           let modelAsset = modelAsset {
            let recordedMatrices = customAnim.update(deltaTime: time.deltaTime)
            let bindPoseInverses = modelAsset.jointBindPoseInverses
            jointMatrices = updateJointMatrices(recordedAppleMatrices: recordedMatrices, modelBindPoseInverses: bindPoseInverses)
            let circles: [DebugCircle] = jointMatrices.enumerated().map { index, matrix in
                let position = vec3f(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
                let isCurrentJoint = (index == currentJointIndex)
                return DebugCircle(position: position, color: isCurrentJoint ? vec4f(0, 1, 0, 1) : vec4f(1, 0, 0, 1), radius: isCurrentJoint ? 0.02 : 0.01)
            }
            circleRenderer.updateCircles(circles)
            jointMatricesBuffer?.update(with: jointMatrices)
        }
        
        if let vertexBuffer = vertexBuffer,
           let indexBuffer = indexBuffer {
            let modelUniforms = ModelUniforms(
                viewProjectionMatrix: camera.getViewProjectionMatrix(),
                modelMatrix: model,
                time: time.now,
                hasAnimation: selectedAnimation != nil ? 1 : 0,
                jointIndex: Int32(currentJointIndex)
            )
            uniformsBuffer = MetalBuffer<ModelUniforms>(device: device, element: modelUniforms, usage: .uniforms)
            renderEncoder.setRenderPipelineState(modelPipelineState)
            renderEncoder.setDepthStencilState(depthStencilState)
            uniformsBuffer.bind(to: renderEncoder, type: .vertex, index: 1)
            vertexBuffer.bind(to: renderEncoder, type: .vertex, index: 0)
            jointMatricesBuffer?.bind(to: renderEncoder, type: .vertex, index: 2)
            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: indexBuffer.count,
                indexType: .uint32,
                indexBuffer: indexBuffer.raw()!,
                indexBufferOffset: 0
            )
        }
        
        circleRenderer.render(encoder: renderEncoder, viewProjectionMatrix: camera.getViewProjectionMatrix())
        renderEncoder.endEncoding()
        commandBuffer.present(drawableTarget)
        commandBuffer.commit()
    }
    
    private func setupRenderPass(view: MTKView) -> MTLRenderPassDescriptor? {
        guard let currentDrawable = view.currentDrawable else { return nil }
        let colorAttachment = ColorAttachmentDescriptor(
            texture: currentDrawable.texture,
            loadAction: .clear,
            storeAction: .store,
            clearColor: MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        )
        let depthAttachment = DepthAttachmentDescriptor(
            texture: view.depthStencilTexture,
            loadAction: .clear,
            storeAction: .dontCare,
            clearDepth: 1.0
        )
        let config = RenderPassBuilder()
            .addColorAttachment(colorAttachment)
            .setDepthAttachment(depthAttachment)
            .setSampleCount(view.sampleCount)
            .build()
        renderPassDescriptor = RenderPassDescriptor(config: config)
        return renderPassDescriptor?.getMTLRenderPassDescriptor()
    }
}

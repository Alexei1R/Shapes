import Foundation
import MetalKit

enum MovementMode {
    case rotate
    case moveInPlane
}

class Drawable: NSObject, ObservableObject {
    // MARK: - Core Properties
    let device: MTLDevice
    var commandQueue: MTLCommandQueue!
    var modelPipelineState: MTLRenderPipelineState!
    private var depthStencilState: MTLDepthStencilState!
    private var camera: Camera!
    private var time = Time()
    private var renderPassDescriptor: RenderPassDescriptor?
    private var grid: Grid!
    
    // MARK: - Animation and Debug Properties
    @Published var selectedAnimation: CapturedAnimation?
    private var customAnimation: CustomAnimation?
    private var circleRenderer: CircleRenderer!
    private var jointMatrices: [mat4f] = []
    
    // MARK: - Model Properties
    private var modelAsset: Model3D?
    private var vertexBuffer: MetalBuffer<ModelVertex>?
    private var indexBuffer: MetalBuffer<UInt32>?
    private var jointMatricesBuffer: MetalBuffer<mat4f>?
    
    // MARK: - Transform Properties
    var model: mat4f = mat4f.identity
        .scale(vec3f(0.01))
        .rotateDegrees(90, axis: .x)
        .rotateDegrees(180, axis: .y)
    
    // MARK: - Uniforms
    struct ModelUniforms {
        var viewProjectionMatrix: mat4f
        var modelMatrix: mat4f
        var time: Float
        var hasAnimation: Int32
    }
    
    private var uniformsBuffer: MetalBuffer<ModelUniforms>!
    var movementMode: MovementMode = .rotate
    
    // MARK: - Initialization
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
        
        // Initialize joint matrices buffer
        jointMatricesBuffer = MetalBuffer<mat4f>(
            device: device,
            count: 100,
            usage: .storageShared
        )
        
        // Initialize with identity matrices
        let identityMatrices = Array(repeating: mat4f.identity, count: 100)
        jointMatricesBuffer?.update(with: identityMatrices)
    }
    
    private func loadModel() {
        if let modelPath = Bundle.main.path(forResource: "robot", ofType: "usdc") {
            let modelURL = URL(fileURLWithPath: modelPath)
            
            if let device = Engine.shared?.device {
                let model3D = Model3D()
                do {
                    try model3D.load(from: modelURL)
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
        
        // Set up shader functions
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
        
        // Set up vertex descriptor
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
        
        // Enable alpha blending
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
    
    // MARK: - Animation Matrix Transformation
    private func transformAnimationMatrices(_ matrices: [mat4f]) -> [mat4f] {
        return matrices.map { jointMatrix in
            // Convert joint matrix to model space
            let modelInv = model.inverse()
            return model * jointMatrix * modelInv
        }
    }
    
    // MARK: - Animation Control
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
        // Reset to identity matrices
        let identityMatrices = Array(repeating: mat4f.identity, count: 100)
        jointMatricesBuffer?.update(with: identityMatrices)
        print("Animation stopped")
    }
    
    func setMovementMode(_ mode: MovementMode) {
        movementMode = mode
    }
}

// MARK: - MTKViewDelegate
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
        
        // Handle camera controls
        if EventManager.shared.isActive, let event = EventManager.shared.currentEvent {
            switch event.type {
            case .drag:
                switch movementMode {
                case .rotate:
                    camera.orbit(
                        deltaTheta: Float(event.delta.x) * 0.005,
                        deltaPhi: Float(event.delta.y) * 0.005
                    )
                case .moveInPlane:
                    camera.moveInPlane(
                        deltaX: Float(event.delta.x) * 0.01,
                        deltaY: Float(event.delta.y) * 0.01
                    )
                }
            case .pinch:
                camera.zoom(factor: Float(event.scale))
            default:
                break
            }
        }
        
        // Draw grid
        grid.render(encoder: renderEncoder,
                   viewProjectionMatrix: camera.getViewProjectionMatrix())
        
        // Update animation and debug circles
        if let animation = selectedAnimation,
           let customAnim = customAnimation {
            jointMatrices = customAnim.update(deltaTime: time.deltaTime)
            
            if !jointMatrices.isEmpty {
                // Transform and update joint matrices for model animation
                let transformedMatrices = transformAnimationMatrices(jointMatrices)
                jointMatricesBuffer?.update(with: transformedMatrices)
                
                // Create debug circles using original matrices for visualization
                let circles: [DebugCircle] = jointMatrices.map { matrix in
                    let position = vec3f(
                        matrix.columns.3.x,
                        matrix.columns.3.y,
                        matrix.columns.3.z
                    )
                    return DebugCircle(
                        position: position,
                        color: vec4f(1, 0, 0, 1),
                        radius: 0.01
                    )
                }
                circleRenderer.updateCircles(circles)
            }
        }
        
        // Draw model
        if let vertexBuffer = vertexBuffer,
           let indexBuffer = indexBuffer {
            
            let modelUniforms = ModelUniforms(
                viewProjectionMatrix: camera.getViewProjectionMatrix(),
                modelMatrix: model,
                time: time.now,
                hasAnimation: selectedAnimation != nil ? 1 : 0
            )
            
            uniformsBuffer = MetalBuffer<ModelUniforms>(
                device: device,
                element: modelUniforms,
                usage: .uniforms
            )
            
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
        
        // Draw debug circles
        circleRenderer.render(
            encoder: renderEncoder,
            viewProjectionMatrix: camera.getViewProjectionMatrix()
        )
        
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

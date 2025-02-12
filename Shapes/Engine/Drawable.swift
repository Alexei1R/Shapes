import Foundation
import MetalKit

class Drawable: NSObject, ObservableObject {
    let device: MTLDevice
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    private var depthStencilState: MTLDepthStencilState!
    private var camera: Camera!
    var model = mat4f.identity
    private var time = Time()
    private var renderPassDescriptor: RenderPassDescriptor?
    
    var modelAsset: Model3D?
    @Published var currentJointIndex: Int = 0
    private var animationManager: AnimationManager?
    private var jointMatricesBuffer: MetalBuffer<mat4f>?
    
    struct Uniforms {
        var viewProjectionMatrix: mat4f
        var modelMatrix: mat4f
        var time: Float
        var selectedJointIndex: Int32
    }
    
    var vertexBuffer: MetalBuffer<ModelVertex>!
    var indexBuffer: MetalBuffer<UInt32>!
    var uniformsBuffer: MetalBuffer<Uniforms>!
    let materialManager = MaterialManager()
    
    init(device: MTLDevice) {
        self.device = device
        super.init()
        setupCamera()
        buildPipeline()
        model = mat4f.identity.scale(vec3f.one * 0.3)
        loadMesh()
    }
    
    private func loadMesh() {
        if let modelPath = Bundle.main.path(forResource: "girl", ofType: "usdc") {
            let modelURL = URL(fileURLWithPath: modelPath)
            let model3D = Model3D()
            
            do {
                try model3D.load(from: modelURL)
                model3D.printAllComponents()
                
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
                
                modelAsset = model3D
                
                // Initialize animation manager and joint matrices buffer
                animationManager = AnimationManager(model: model3D)
                jointMatricesBuffer = MetalBuffer<mat4f>(
                    device: device,
                    elements: Array(repeating: mat4f.identity, count: model3D.joints.count),
                    usage: .storageShared
                )
                
                // Start playing the first animation if available
                if !model3D.animations.isEmpty {
                    animationManager?.play(animationIndex: 0)
                }
                
            } catch {
                print("Failed to load model: \(error)")
            }
        } else {
            print("Model file not found in bundle.")
        }
    }
    
    private func setupCamera() {
        camera = Camera(
            position: SIMD3(0, 1, -200),
            target: SIMD3(0, 0, 0),
            up: SIMD3(0, 1, 0),
            fieldOfView: Float.pi / 3,
            aspectRatio: 1.0,
            nearPlane: 0.1,
            farPlane: 10000.0
        )
        let uniforms = Uniforms(
            viewProjectionMatrix: camera.getViewProjectionMatrix(),
            modelMatrix: model,
            time: time.now,
            selectedJointIndex: Int32(currentJointIndex)
        )
        uniformsBuffer = MetalBuffer<Uniforms>(device: device, element: uniforms, usage: .uniforms)
    }
    
    private func setupRenderPass(view: MTKView) -> MTLRenderPassDescriptor? {
        guard let currentDrawable = view.currentDrawable else { return nil }
        
        let colorAttachment = ColorAttachmentDescriptor(
            texture: currentDrawable.texture,
            loadAction: .clear,
            storeAction: .store,
            clearColor: MTLClearColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)
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
    
    private func buildPipeline() {
        commandQueue = device.makeCommandQueue()
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        
        let layout = ShaderLayout([
            ShaderElement(type: .vertex, data: "model_vertex_main"),
            ShaderElement(type: .fragment, data: "model_fragment_main")
        ])
        
        do {
            let shaderHandle = try ShaderManager.shared.loadShader(layout: layout)
            if let shader = ShaderManager.shared.getShader(shaderHandle) {
                pipelineDescriptor.vertexFunction = shader.function(of: .vertex)
                pipelineDescriptor.fragmentFunction = shader.function(of: .fragment)
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
            BufferElement(type: .uint16x4, name: "indices"),
            BufferElement(type: .float4, name: "weight")
        ])
        
        pipelineDescriptor.vertexDescriptor = vertexLayout.metalVertexDescriptor(bufferIndex: 0)
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create pipeline state: \(error)")
        }
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
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
    
    func toggleAnimation() {
        if let manager = animationManager {
            switch manager.state {
            case .playing:
                manager.pause()
            case .paused:
                manager.resume()
            case .stopped:
                if !(modelAsset?.animations.isEmpty  ?? true ){
                    manager.play(animationIndex: 0)
                }
            }
        }
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
        
        // Handle camera controls
        if EventManager.shared.isActive, let event = EventManager.shared.currentEvent {
            switch event.type {
            case .drag:
                camera.orbit(
                    deltaTheta: Float(event.delta.x) * 0.005,
                    deltaPhi: Float(event.delta.y) * 0.005
                )
            case .pinch:
                camera.zoom(factor: Float(event.scale))
            default:
                break
            }
        }
        
        // Update animation state
        if let manager = animationManager {
            let jointMatrices = manager.update(deltaTime: time.deltaTime)
            memcpy(jointMatricesBuffer?.contents(), jointMatrices, MemoryLayout<mat4f>.size * jointMatrices.count)
        }
        
        // Update uniforms
        var uniforms = Uniforms(
            viewProjectionMatrix: camera.getViewProjectionMatrix(),
            modelMatrix: model,
            time: time.now,
            selectedJointIndex: Int32(currentJointIndex)
        )
        memcpy(uniformsBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.size)
        
        // Set render state
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        // Bind buffers
        vertexBuffer.bind(to: renderEncoder, type: .vertex, index: 0)
        uniformsBuffer.bind(to: renderEncoder, type: .vertex, index: 1)
        jointMatricesBuffer?.bind(to: renderEncoder, type: .vertex, index: 2)
        
        // Draw
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexBuffer.count,
            indexType: .uint32,
            indexBuffer: indexBuffer.raw()!,
            indexBufferOffset: 0
        )
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawableTarget)
        commandBuffer.commit()
    }
}

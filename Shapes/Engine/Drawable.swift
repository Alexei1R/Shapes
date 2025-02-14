//  Drawable.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import Foundation
import MetalKit

enum MovementMode {
    case rotate
    case moveInPlane
}

class Drawable: NSObject, ObservableObject {
    let device: MTLDevice
    var commandQueue: MTLCommandQueue!
    var modelPipelineState: MTLRenderPipelineState!
    private var depthStencilState: MTLDepthStencilState!
    private var camera: Camera!
    var model = mat4f.identity
    private var time = Time()
    private var renderPassDescriptor: RenderPassDescriptor?
    private var grid: Grid!
    
    var modelAsset: Model3D?
    @Published var currentJointIndex: Int = 0
    
    private var animationManager: AnimationManager?
    private var jointMatricesBuffer: MetalBuffer<matrix_float4x4>?
    
    struct ModelUniforms {
        var viewProjectionMatrix: mat4f
        var modelMatrix: mat4f
        var time: Float
        var selectedJointIndex: Int32
    }
    
    var vertexBuffer: MetalBuffer<ModelVertex>!
    var indexBuffer: MetalBuffer<UInt32>!
    var uniformsBuffer: MetalBuffer<ModelUniforms>!
    let materialManager = MaterialManager()
    
    var movementMode: MovementMode = .rotate
    
    init(device: MTLDevice) {
        self.device = device
        super.init()
        setupCamera()
        buildPipeline()
        model = mat4f.identity.scale(vec3f.one * 0.01)
//            .translate(vec3f.up * -1.3)
            .rotateDegrees(90, axis: .x)
            .rotateDegrees(180, axis: .y)
        
        // Initialize grid before loading mesh
        grid = Grid(device: device)
        
        loadMesh()
        
        if let model3D = modelAsset {
            animationManager = AnimationManager(model: model3D)
            jointMatricesBuffer = MetalBuffer<matrix_float4x4>(
                device: device,
                count: model3D.joints.count,
                usage: .storageShared
            )
        }
    }
    
    func setMovementMode(_ mode: MovementMode) {
        movementMode = mode
    }
    
    func playAnimation(index: Int) {
        animationManager?.play(animationIndex: index)
    }
    
    func pauseAnimation() {
        animationManager?.pause()
    }
    
    func resumeAnimation() {
        animationManager?.resume()
    }
    
    func stopAnimation() {
        animationManager?.stop()
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
            } catch {
                print("Failed to load model: \(error)")
            }
        } else {
            print("Model file not found in bundle.")
        }
    }
    
    private func setupCamera() {
        camera = Camera(
            position: SIMD3(0, 1, -5),
            target: SIMD3(0, 0, 0),
            up: SIMD3(0, 1, 0),
            fieldOfView: Float.pi / 3,
            aspectRatio: 1.0,
            nearPlane: 0.1,
            farPlane: 10000.0
        )
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
            BufferElement(type: .uint16x4, name: "indices"),
            BufferElement(type: .float4, name: "weight")
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
        
        // Draw grid first
        grid.render(encoder: renderEncoder,
                   viewProjectionMatrix: camera.getViewProjectionMatrix())
        
        if let animationManager = animationManager {
            let jointMatrices = animationManager.update(deltaTime: time.deltaTime)
            jointMatricesBuffer?.update(with: jointMatrices)
        }
        
        var modelUniforms = ModelUniforms(
            viewProjectionMatrix: camera.getViewProjectionMatrix(),
            modelMatrix: model,
            time: time.now,
            selectedJointIndex: Int32(currentJointIndex)
        )
        
        renderEncoder.setRenderPipelineState(modelPipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        uniformsBuffer = MetalBuffer<ModelUniforms>(
            device: device,
            element: modelUniforms,
            usage: .uniforms
        )
        
        uniformsBuffer.bind(to: renderEncoder, type: .vertex, index: 1)
        vertexBuffer.bind(to: renderEncoder, type: .vertex, index: 0)
        
        if let jointMatricesBuffer = jointMatricesBuffer {
            jointMatricesBuffer.bind(to: renderEncoder, type: .vertex, index: 2)
        }
        
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

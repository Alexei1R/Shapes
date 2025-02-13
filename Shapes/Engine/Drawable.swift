//
//  Drawable.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import Foundation
import MetalKit

class Drawable: NSObject, ObservableObject {
    let device: MTLDevice
    var commandQueue: MTLCommandQueue!
    var modelPipelineState: MTLRenderPipelineState!
    private var depthStencilState: MTLDepthStencilState!
    private var camera: Camera!
    var model = mat4f.identity
    private var time = Time()
    private var renderPassDescriptor: RenderPassDescriptor?
    private var circleRenderer: CircleRenderer!
    private var debugCircles: [Circle] = []
    
    var modelAsset: Model3D?
    @Published var currentJointIndex: Int = 0
    
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
    
    init(device: MTLDevice) {
        self.device = device
        super.init()
        setupCamera()
        buildPipeline()
        setupCircleRenderer()
        model = mat4f.identity.scale(vec3f.one * 0.01).rotateDegrees(90 , axis: .x).translate(vec3f.up * -1.3)
        loadMesh()
        generateRandomCircles()
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
    
    private func setupCircleRenderer() {
        circleRenderer = CircleRenderer(device: device)
    }
    
    func generateRandomCircles() {
        debugCircles.removeAll()
        
        // Generate 10 random circles
        for _ in 0..<10 {
            let position = vec3f(
                Float.random(in: -2...2),  // X
                Float.random(in: -2...2),  // Y
                Float.random(in: -1...1)   // Z
            )
            
            let color = vec4f(
                Float.random(in: 0...1),   // R
                Float.random(in: 0...1),   // G
                Float.random(in: 0...1),   // B
                1.0                        // A
            )
            
            let radius = Float.random(in: 0.05...0.2)
            
            let circle = Circle(position: position, color: color, radius: radius)
            debugCircles.append(circle)
        }
        
        circleRenderer.updateCircles(debugCircles)
    }
    
    func addDebugCircle(at position: vec3f, color: vec4f = vec4f(1, 0, 0, 1), radius: Float = 0.1) {
        let circle = Circle(position: position, color: color, radius: radius)
        debugCircles.append(circle)
        circleRenderer.updateCircles(debugCircles)
    }
    
    func clearDebugCircles() {
        debugCircles.removeAll()
        circleRenderer.updateCircles(debugCircles)
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
    
    func addTenRandomCircles() {
        // Clear previous circles
        clearDebugCircles()
        
        // Generate and add 10 new random circles
        for _ in 0..<10 {
            let position = vec3f(
                Float.random(in: -2...2),  // X
                Float.random(in: -2...2),  // Y
                Float.random(in: -1...1)   // Z
            )
            
            let color = vec4f(
                Float.random(in: 0...1),   // R
                Float.random(in: 0...1),   // G
                Float.random(in: 0...1),   // B
                1.0                        // A
            )
            
            let radius = Float.random(in: 0.05...0.2)
            
            let circle = Circle(position: position, color: color, radius: radius)
            debugCircles.append(circle)
        }
        
        // Update the circle renderer with the new circles
        circleRenderer.updateCircles(debugCircles)
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
        
        // Draw Model
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
        
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexBuffer.count,
            indexType: .uint32,
            indexBuffer: indexBuffer.raw()!,
            indexBufferOffset: 0
        )
        
        // Draw Circles
        circleRenderer.render(encoder: renderEncoder, viewProjectionMatrix: camera.getViewProjectionMatrix())
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawableTarget)
        commandBuffer.commit()
    }
}

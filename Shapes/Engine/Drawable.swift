//
//  Drawable.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//



import Foundation
import MetalKit



class Drawable: NSObject {
    let device: MTLDevice
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    private var depthStencilState: MTLDepthStencilState!
    private var camera: Camera!
    var model = mat4f.identity
    private var time = Time()
    private var renderPassDescriptor: RenderPassDescriptor?
    
    
    
    
    
    var girlModel : Model3D?
    
    struct Uniforms {
        var viewProjectionMatrix: mat4f
        var model: mat4f
        var time: Float
    }
    
    var vertexBuffer: MetalBuffer<Vertex>!
    var indexBuffer: MetalBuffer<UInt16>!
    var uniformsBuffer: MetalBuffer<Uniforms>!
    let materialManager = MaterialManager()
    
    var rotationX: Float = 0.0
    var rotationY: Float = 0.0
    
    init(device: MTLDevice) {
        self.device = device
        super.init()
        setupCamera()
        buildPipeline()
        createBuffers()
        model = mat4f.identity.rotate(Float.pi / 4, axis: .x)
        
        
        loadMesh()
    }
    
    
    private func loadMesh(){
        if let modelPath = Bundle.main.path(forResource: "girl", ofType: "usdc") {
            let modelURL = URL(fileURLWithPath: modelPath)
            let model3D = Model3D()
            
            do {
                try model3D.load(from: modelURL)
                model3D.printAllComponents()
                girlModel = model3D
            } catch {
                print("Failed to load model: \(error)")
            }
        } else {
            print("Model file not found in bundle.")
        }
    }

    private func setupCamera() {
        camera = Camera(
            position: vec3f(0, 1, -5),
            target: vec3f(0, 0, 0),
            up: vec3f(0, 1, 0),
            fieldOfView: Float.pi / 3,
            aspectRatio: 1.0,
            nearPlane: 0.1,
            farPlane: 100.0
        )
        let uniforms = Uniforms(
            viewProjectionMatrix: camera.getViewProjectionMatrix(),
            model: model,
            time: 0.0
        )
        uniformsBuffer = MetalBuffer<Uniforms>(device: device, element: uniforms, usage: .uniforms)
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


        let pipelineDescriptor = MTLRenderPipelineDescriptor()

        let layout = ShaderLayout([
            ShaderElement(type: .vertex, data: "vertex_main"),
            ShaderElement(type: .fragment, data: "fragment_main")
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


        let vertexLayout = BufferLayout(
            elements: BufferElement(type: .float3, name: "position"),
            BufferElement(type: .float4, name: "color")
        )
        pipelineDescriptor.vertexDescriptor = vertexLayout.metalVertexDescriptor(bufferIndex: 0)
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)

        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
    }

    private func createBuffers() {
        vertexBuffer = MetalBuffer<Vertex>(
            device: device,
            elements: CubeMesh.vertices,
            usage: .storageShared
        )
        indexBuffer = MetalBuffer<UInt16>(
            device: device,
            elements: CubeMesh.indices,
            usage: .storageShared
        )
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
            rotationY += Float(event.delta.x) * 0.005
            rotationX += Float(event.delta.y) * 0.005
        }


        model = mat4f.identity
            .rotate(rotationX, axis: .x)
            .rotate(rotationY, axis: .y)

        var uniforms = Uniforms(
            viewProjectionMatrix: camera.getViewProjectionMatrix(),
            model: model,
            time: 0.0
        )
        memcpy(uniformsBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.size)

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        uniformsBuffer.bind(to: renderEncoder, type: .vertex, index: 1)
        vertexBuffer.bind(to: renderEncoder, type: .vertex, index: 0)
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: CubeMesh.indices.count,
            indexType: .uint16,
            indexBuffer: indexBuffer.raw()!,
            indexBufferOffset: 0
        )

        renderEncoder.endEncoding()
        commandBuffer.present(drawableTarget)
        commandBuffer.commit()
    }
}






////
////  Drawable.swift
////  Shapes
////
////  Created by rusu alexei on 04.02.2025.
////
//
//
//import Foundation
//import MetalKit
//
//class Drawable: NSObject {
//    let renderApi: RendererAPI
//    let frameGraph: FrameGraph
//    
//    init(device: MTLDevice) {
//        guard let rendererAPI = RendererAPI() else {
//            fatalError("Failed to create Renderer API")
//        }
//        self.renderApi = rendererAPI
//        
//        self.frameGraph = FrameGraph(rendererAPI: rendererAPI)
//        
//        super.init()
//        setup()
//    }
//    
//    private func setup() {
//        frameGraph.addPass { [weak self] commandBuffer in
//            guard let self = self else{
//                return
//            }
//            
//        }
//    }
//}
//
//extension Drawable: MTKViewDelegate {
//    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
//        // Handle view resize if needed
//    }
//    
//    func draw(in view: MTKView) {
//        frameGraph.execute()
//    }
//}

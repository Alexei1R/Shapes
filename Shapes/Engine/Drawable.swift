//
//  Drawable.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import Foundation
import MetalKit

// Move MeshData to a separate file or declare it here only once
struct MeshData {
    var vertices: [ModelVertex]
    var indices: [UInt32]
}

class Drawable: NSObject {
    let device: MTLDevice
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    private var depthStencilState: MTLDepthStencilState!
    private var camera: Camera!
    var model = mat4f.identity
    private var time = Time()
    private var renderPassDescriptor: RenderPassDescriptor?
    
    var girlModel: Model3D?
    
    struct Uniforms {
        var viewProjectionMatrix: mat4f
        var model: mat4f
        var time: Float
    }
    
    var vertexBuffer: MetalBuffer<ModelVertex>!
    var indexBuffer: MetalBuffer<UInt32>!
    var uniformsBuffer: MetalBuffer<Uniforms>!
    let materialManager = MaterialManager()
    
    var rotationX: Float = 0.0
    var rotationY: Float = 0.0
    
    init(device: MTLDevice) {
        self.device = device
        super.init()
        setupCamera()
        buildPipeline()
        model = mat4f.identity.rotate(Float.pi / 4, axis: .x)
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
                   let meshData = extractMeshData(from: firstMesh) {
                    
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
            position: SIMD3(0, 1, -400),
            target: SIMD3(0, 0, 0),
            up: SIMD3(0, 1, 0),
            fieldOfView: Float.pi / 3,
            aspectRatio: 1.0,
            nearPlane: 0.1,
            farPlane: 1000.0
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
            clearColor: MTLClearColor(red: 0.1, green: 0.3, blue: 0.3, alpha: 1)
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
            BufferElement(type: .float4, name: "indices"),
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
            time: time.now
        )
        memcpy(uniformsBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.size)
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        uniformsBuffer.bind(to: renderEncoder, type: .vertex, index: 1)
        vertexBuffer.bind(to: renderEncoder, type: .vertex, index: 0)
        
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

extension Drawable {
    private func extractMeshData(from mdlMesh: MDLMesh) -> MeshData? {
        guard let vertexBuffer = mdlMesh.vertexBuffers.first else {
            print("No vertex buffer found!")
            return nil
        }
        
        let vertexData = vertexBuffer.map().bytes.assumingMemoryBound(to: Float.self)
        let vertexCount = mdlMesh.vertexCount
        
        var vertices: [ModelVertex] = []
        
        guard let stride = mdlMesh.vertexDescriptor.layouts[0] as? MDLVertexBufferLayout else {
            print("No vertex layout found!")
            return nil
        }
        
        let strideInFloats = stride.stride / MemoryLayout<Float>.stride
        
        for i in 0..<vertexCount {
            let base = i * strideInFloats
            
            // Extract vertex attributes with proper offsets
            let position = SIMD3<Float>(
                vertexData[base],
                vertexData[base + 1],
                vertexData[base + 2]
            )
            
            let normal = SIMD3<Float>(
                vertexData[base + 3],
                vertexData[base + 4],
                vertexData[base + 5]
            )
            
            let texCoord = SIMD2<Float>(
                vertexData[base + 6],
                vertexData[base + 7]
            )
            
            let tangent = SIMD3<Float>(
                vertexData[base + 8],
                vertexData[base + 9],
                vertexData[base + 10]
            )
            
            let bitangent = SIMD3<Float>(
                vertexData[base + 11],
                vertexData[base + 12],
                vertexData[base + 13]
            )
            
            let jointIndices = SIMD4<Float>(
                vertexData[base + 14],
                vertexData[base + 15],
                vertexData[base + 16],
                vertexData[base + 17]
            )
            
            let jointWeights = SIMD4<Float>(
                vertexData[base + 18],
                vertexData[base + 19],
                vertexData[base + 20],
                vertexData[base + 21]
            )
            
            vertices.append(ModelVertex(
                position: position,
                normal: normal,
                textureCoordinate: texCoord,
                tangent: tangent,
                bitangent: bitangent,
                jointIndices: jointIndices,
                jointWeights: jointWeights
            ))
        }
        
        // Extract indices
        var indices: [UInt32] = []
        
        for submesh in mdlMesh.submeshes as! [MDLSubmesh] {
            let indexBuffer = submesh.indexBuffer
            let indexData = indexBuffer.map().bytes.assumingMemoryBound(to: UInt32.self)
            
            let indexCount = submesh.indexCount
            for i in 0..<indexCount {
                indices.append(indexData[i])
            }
        }
        
        return MeshData(vertices: vertices, indices: indices)
    }}

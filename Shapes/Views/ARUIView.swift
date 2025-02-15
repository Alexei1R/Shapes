import SwiftUI
import RealityKit
import ARKit
import Combine
import simd

struct ARViewContainer: UIViewRepresentable {
    
    var handleFrame: (CapturedFrame) -> Void
    
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let coordinator = context.coordinator
        arView.session.delegate = coordinator
        
        guard ARBodyTrackingConfiguration.isSupported else {
            fatalError("This feature is only supported on devices with an A12 chip")
        }
        
        let configuration = ARBodyTrackingConfiguration()
        arView.session.run(configuration)
        
        coordinator.setupARView(arView)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(handleFrame: handleFrame)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        
        
        var idFrame : Int = 0
        
        var character: BodyTrackedEntity?
        let characterOffset: SIMD3<Float> = [0, 0, 0]
        let characterAnchor = AnchorEntity()
        var cancellable: AnyCancellable?
        var handleFrame: (CapturedFrame) -> Void
        
        init(character: BodyTrackedEntity? = nil, cancellable: AnyCancellable? = nil, handleFrame: @escaping (CapturedFrame) -> Void) {
            self.character = character
            self.cancellable = cancellable
            self.handleFrame = handleFrame
        }
        
        func setupARView(_ arView: ARView) {
            arView.scene.addAnchor(characterAnchor)
            
            cancellable = Entity.loadBodyTrackedAsync(named: "robotAR").sink(
                receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        print("Error: Unable to load model: \(error.localizedDescription)")
                        fatalError()
                    }
                    self.cancellable?.cancel()
                }, receiveValue: { (character: Entity) in
                    if let character = character as? BodyTrackedEntity {
                        character.scale = [1, 1, 1]
                        self.character = character
                        self.cancellable?.cancel()
                    } else {
                        print("Error: Unable to load model as BodyTrackedEntity")
                    }
                }
            )
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            for anchor in anchors {
                guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }
                let bodyPosition = simd_make_float3(bodyAnchor.transform.columns.3)
                characterAnchor.position = bodyPosition + characterOffset
                characterAnchor.orientation = Transform(matrix: bodyAnchor.transform).rotation
                if let character = character, character.parent == nil {
                    characterAnchor.addChild(character)
                }
                
                
                
                //RECORD ANIMATIONS THAT I WILL SAVE TO THE DISK
                //                var bodyTransform = bodyAnchor.transform
                //                var globalJointTransforms: [simd_float4x4] = []
                //                for jointTransform in bodyAnchor.skeleton.jointModelTransforms {
                //                    let globalTransform = matrix_multiply(bodyTransform , jointTransform)
                //                    globalJointTransforms.append(globalTransform)
                //                }
                let capturedFrame = CapturedFrame(
                    id: idFrame,
                    joints:bodyAnchor.skeleton.jointModelTransforms
                )
                handleFrame(capturedFrame)
            }
        }
    }
}

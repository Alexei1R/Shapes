import Foundation
import simd

enum AnimationState {
    case stopped
    case playing
    case paused
}

class AnimationManager {
    private let model: Model3D
    private(set) var state: AnimationState = .stopped
    private var currentAnimationIndex: Int?
    private var currentTime: TimeInterval = 0.0
    private var jointMatrices: [mat4f] = []
    private var framesPerJoint: Int = 0  // Added to track frames per joint
    
    init(model: Model3D) {
        self.model = model
        jointMatrices = Array(repeating: mat4f.identity, count: model.joints.count)
        
        // Calculate frames per joint if there's an animation
        if let firstAnimation = model.animations.first {
            framesPerJoint = firstAnimation.translations.count / firstAnimation.jointPaths.count
        }
    }
    
    func play(animationIndex: Int, startTime: TimeInterval = 0.0) {
        guard animationIndex >= 0 && animationIndex < model.animations.count else {
            print("Invalid animation index. The model only contains \(model.animations.count) animation(s).")
            return
        }
        currentAnimationIndex = animationIndex
        currentTime = startTime
        state = .playing
        let animation = model.animations[animationIndex]
        print("Started animation: \"\(animation.name)\" at time offset: \(startTime)")
    }
    
    func pause() {
        guard state == .playing else { return }
        state = .paused
    }
    
    func resume() {
        guard state == .paused else { return }
        state = .playing
    }
    
    func stop() {
        state = .stopped
        currentAnimationIndex = nil
        currentTime = 0.0
    }
    
    func update(deltaTime: TimeInterval) -> [mat4f] {
        guard state == .playing,
              let animationIndex = currentAnimationIndex,
              let animation = model.animations[safe: animationIndex] else {
            return jointMatrices
        }
        
        currentTime += deltaTime
        if currentTime > animation.duration {
            currentTime = currentTime.truncatingRemainder(dividingBy: animation.duration)
        }
        
        // Calculate frame indices
        let currentFrame = Int((currentTime / animation.duration) * Double(framesPerJoint)) % framesPerJoint
        let nextFrame = (currentFrame + 1) % framesPerJoint
        let frameProgress = Float((currentTime / animation.duration) * Double(framesPerJoint) - Double(currentFrame))
        
        // Update transforms for each joint
        for (jointIndex, jointPath) in animation.jointPaths.enumerated() {
            guard let modelJointIndex = model.joints.firstIndex(where: { $0.path == jointPath }) else { continue }
            
            // Calculate base indices for the joint's data
            let baseCurrentIndex = currentFrame * animation.jointPaths.count + jointIndex
            let baseNextIndex = nextFrame * animation.jointPaths.count + jointIndex
            
            // Safe array access
            guard baseCurrentIndex < animation.translations.count,
                  baseNextIndex < animation.translations.count,
                  baseCurrentIndex < animation.rotations.count,
                  baseNextIndex < animation.rotations.count,
                  baseCurrentIndex < animation.scales.count,
                  baseNextIndex < animation.scales.count else {
                continue
            }
            
            // Get transform components
            let currentTranslation = animation.translations[baseCurrentIndex]
            let nextTranslation = animation.translations[baseNextIndex]
            let currentRotation = animation.rotations[baseCurrentIndex]
            let nextRotation = animation.rotations[baseNextIndex]
            let currentScale = animation.scales[baseCurrentIndex]
            let nextScale = animation.scales[baseNextIndex]
            
            // Interpolate transforms
            let translation = mix(currentTranslation, nextTranslation, t: frameProgress)
            let rotation = simd_slerp(currentRotation, nextRotation, frameProgress)
            let scale = mix(currentScale, nextScale, t: frameProgress)
            
            // Build local transform matrix
            var transform = mat4f.identity
            transform = transform.translate(translation)
            transform = transform * matrix4x4_from_quaternion(rotation)
            transform = transform.scale(scale)
            
            // Apply parent transform if exists
            if let parentIndex = model.joints[modelJointIndex].parentIndex {
                transform = jointMatrices[parentIndex] * transform
            }
            
            jointMatrices[modelJointIndex] = transform
        }
        
        return jointMatrices
    }
}

// Helper functions
private func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
    return a + (b - a) * t
}

private func matrix4x4_from_quaternion(_ q: simd_quatf) -> mat4f {
    let w = q.real
    let x = q.imag.x
    let y = q.imag.y
    let z = q.imag.z
    
    return mat4f(
        SIMD4<Float>(1 - 2*y*y - 2*z*z, 2*x*y + 2*w*z, 2*x*z - 2*w*y, 0),
        SIMD4<Float>(2*x*y - 2*w*z, 1 - 2*x*x - 2*z*z, 2*y*z + 2*w*x, 0),
        SIMD4<Float>(2*x*z + 2*w*y, 2*y*z - 2*w*x, 1 - 2*x*x - 2*y*y, 0),
        SIMD4<Float>(0, 0, 0, 1)
    )
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

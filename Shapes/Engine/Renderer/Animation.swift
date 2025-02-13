//
//  Animation.swift
//  Shapes
//
//  Created by rusu alexei on 07.02.2025.
//

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
    
    init(model: Model3D) {
        self.model = model
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
        print("Paused animation.")
    }
    
    func resume() {
        guard state == .paused else { return }
        state = .playing
        print("Resumed animation.")
    }
    
    func stop() {
        state = .stopped
        currentAnimationIndex = nil
        currentTime = 0.0
        print("Stopped animation.")
    }
    
    private func quaternionToMatrix(_ q: simd_quatf) -> mat4f {
        let w = q.vector.w
        let x = q.vector.x
        let y = q.vector.y
        let z = q.vector.z
        
        return mat4f(
            SIMD4<Float>(1 - 2*y*y - 2*z*z, 2*x*y + 2*w*z, 2*x*z - 2*w*y, 0),
            SIMD4<Float>(2*x*y - 2*w*z, 1 - 2*x*x - 2*z*z, 2*y*z + 2*w*x, 0),
            SIMD4<Float>(2*x*z + 2*w*y, 2*y*z - 2*w*x, 1 - 2*x*x - 2*y*y, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
    
    func update(deltaTime: TimeInterval) -> [mat4f] {
        guard state == .playing,
              let animationIndex = currentAnimationIndex,
              let animation = model.animations[safe: animationIndex] else {
            return model.joints.map { $0.bindTransform }
        }
        
        currentTime += deltaTime
        if currentTime > animation.duration {
            currentTime = currentTime.truncatingRemainder(dividingBy: animation.duration)
        }
        
        let frameCount = animation.translations.count / animation.jointPaths.count
        let frameTime = animation.duration / Double(frameCount - 1)
        let currentFrame = Int(currentTime / frameTime)
        let nextFrame = (currentFrame + 1) % frameCount
        let frameDelta = Float((currentTime.truncatingRemainder(dividingBy: frameTime)) / frameTime)
        
        var jointMatrices = [mat4f](repeating: .identity, count: model.joints.count)
        var pathToIndex: [String: Int] = [:]
        
        // Create path to joint index mapping
        for (index, path) in animation.jointPaths.enumerated() {
            if let jointIndex = model.joints.firstIndex(where: { $0.path == path }) {
                pathToIndex[path] = jointIndex
            }
        }
        
        // Calculate interpolated transforms for each joint
        for (pathIndex, path) in animation.jointPaths.enumerated() {
            guard let jointIndex = pathToIndex[path] else { continue }
            let joint = model.joints[jointIndex]
            
            // Calculate array indices for current and next frame
            let currentIndex = pathIndex + currentFrame * animation.jointPaths.count
            let nextIndex = pathIndex + nextFrame * animation.jointPaths.count
            
            // Get translation, rotation, and scale for current and next frame
            let t0 = animation.translations[currentIndex]
            let t1 = animation.translations[nextIndex]
            let r0 = animation.rotations[currentIndex]
            let r1 = animation.rotations[nextIndex]
            let s0 = animation.scales[currentIndex]
            let s1 = animation.scales[nextIndex]
            
            // Interpolate translation and scale
            let translation = mix(t0, t1, t: frameDelta)
            let scale = mix(s0, s1, t: frameDelta)
            
            // Interpolate rotation using quaternion slerp
            let rotation = simd_slerp(r0, r1, frameDelta)
            
            // Create transform matrix
            let scaleMatrix = mat4f.identity.scale(scale)
            let rotationMatrix = quaternionToMatrix(rotation)
            let translationMatrix = mat4f.identity.translate(translation)
            
            let localTransform = translationMatrix * rotationMatrix * scaleMatrix
            
            // Apply parent transform if exists
            if let parentIndex = joint.parentIndex {
                jointMatrices[jointIndex] = jointMatrices[parentIndex] * localTransform
            } else {
                jointMatrices[jointIndex] = localTransform
            }
        }
        
        // Calculate final matrices including bind pose
        return jointMatrices.enumerated().map { index, matrix in
            let joint = model.joints[index]
            return matrix * joint.bindTransform.inverse()
        }
    }
}

// Helper function to mix vectors
private func mix(_ v0: SIMD3<Float>, _ v1: SIMD3<Float>, t: Float) -> SIMD3<Float> {
    return v0 * (1 - t) + v1 * t
}

// Safe array access
private extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

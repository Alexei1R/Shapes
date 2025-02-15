//
//  CustomAnimation.swift
//  Shapes
//
//  Created by rusu alexei on 15.02.2025.
//
import Foundation
import simd

class CustomAnimation {
    var recordedAnimation: CapturedAnimation?
    private var currentTime: TimeInterval = 0.0
    private var lastFrameTime: TimeInterval = 0.0
    private var frameRate: TimeInterval = 1.0/30.0 // 30 fps
    
    func play(animation: CapturedAnimation, startTime: TimeInterval = 0.0) {
        self.recordedAnimation = animation
        self.currentTime = startTime
        self.lastFrameTime = 0.0
        print("Custom animation started: \(animation.name)")
    }
    
    func stop() {
        recordedAnimation = nil
        currentTime = 0.0
        lastFrameTime = 0.0
        print("Custom animation stopped.")
    }
    
    func update(deltaTime: TimeInterval) -> [mat4f] {
        guard let animation = recordedAnimation,
              !animation.capturedFrames.isEmpty else {
            return []
        }
        
        currentTime += deltaTime
        
        // Ensure smooth playback by maintaining consistent frame rate
        if currentTime - lastFrameTime < frameRate {
            // Return last frame if not enough time has passed
            return animation.capturedFrames[Int(lastFrameTime / frameRate) % animation.capturedFrames.count].joints
        }
        
        lastFrameTime = currentTime
        
        let totalDuration = TimeInterval(animation.duration)
        if totalDuration > 0, currentTime > totalDuration {
            currentTime = currentTime.truncatingRemainder(dividingBy: totalDuration)
        }
        
        let frameCount = animation.capturedFrames.count
        guard frameCount > 1 else {
            return animation.capturedFrames.first?.joints ?? []
        }
        
        let frameTime = totalDuration / TimeInterval(frameCount - 1)
        let currentFrameIndex = Int(currentTime / frameTime)
        let nextFrameIndex = (currentFrameIndex + 1) % frameCount
        
        let currentFrameTime = TimeInterval(currentFrameIndex) * frameTime
        let frameDelta = Float((currentTime - currentFrameTime) / frameTime)
        
        let currentJoints = animation.capturedFrames[currentFrameIndex].joints
        let nextJoints = animation.capturedFrames[nextFrameIndex].joints
        
        return interpolateJointTransforms(
            from: currentJoints,
            to: nextJoints,
            t: frameDelta
        )
    }
    
    private func interpolateJointTransforms(from: [mat4f], to: [mat4f], t: Float) -> [mat4f] {
        let jointCount = min(from.count, to.count)
        var result = [mat4f](repeating: .identity, count: jointCount)
        
        for i in 0..<jointCount {
            let m0 = from[i]
            let m1 = to[i]
            
            // Decompose matrices into translation, rotation, and scale
            let (t0, r0, s0) = decomposeMatrix(m0)
            let (t1, r1, s1) = decomposeMatrix(m1)
            
            // Interpolate components
            let translation = mix(t0, t1, t: t)
            let rotation = simd_slerp(r0, r1, t)
            let scale = mix(s0, s1, t: t)
            
            // Reconstruct matrix
            result[i] = composeMatrix(translation: translation, rotation: rotation, scale: scale)
        }
        
        return result
    }
    
    private func decomposeMatrix(_ matrix: mat4f) -> (SIMD3<Float>, simd_quatf, SIMD3<Float>) {
        let translation = SIMD3<Float>(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
        
        let rotationMatrix = mat3f(
            SIMD3<Float>(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z),
            SIMD3<Float>(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z),
            SIMD3<Float>(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z)
        )
        
        let scale = SIMD3<Float>(
            length(SIMD3<Float>(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z)),
            length(SIMD3<Float>(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z)),
            length(SIMD3<Float>(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z))
        )
        
        let normalizedRotation = mat3f(
            normalize(SIMD3<Float>(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z)),
            normalize(SIMD3<Float>(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z)),
            normalize(SIMD3<Float>(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z))
        )
        
        let rotation = simd_quaternion(normalizedRotation)
        
        return (translation, rotation, scale)
    }
    
    private func composeMatrix(translation: SIMD3<Float>, rotation: simd_quatf, scale: SIMD3<Float>) -> mat4f {
        let rotationMatrix = mat3f(rotation)
        let scaledRotation = mat3f(
            rotationMatrix.columns.0 * scale.x,
            rotationMatrix.columns.1 * scale.y,
            rotationMatrix.columns.2 * scale.z
        )
        
        return mat4f(
            SIMD4<Float>(scaledRotation.columns.0, 0),
            SIMD4<Float>(scaledRotation.columns.1, 0),
            SIMD4<Float>(scaledRotation.columns.2, 0),
            SIMD4<Float>(translation, 1)
        )
    }
}

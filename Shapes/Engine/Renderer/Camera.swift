//
//  Camera.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import Foundation
import simd

public class Camera {
    // Camera properties
    private var position: vec3f
    private var target: vec3f
    private var up: vec3f
    
    // Spherical coordinates for orbiting
    private var radius: Float
    private var phi: Float    // Vertical angle (elevation)
    private var theta: Float  // Horizontal angle (azimuth)
    
    // Projection properties
    private var fieldOfView: Float
    private var aspectRatio: Float
    private var nearPlane: Float
    private var farPlane: Float
    
    // Matrices
    private var viewMatrix: mat4f
    private var projectionMatrix: mat4f
    
    public init(
        position: vec3f = vec3f(0, 0, -5),
        target: vec3f = vec3f(0, 0, 0),
        up: vec3f = vec3f(0, 1, 0),
        fieldOfView: Float = Float.pi / 3,
        aspectRatio: Float = 1.0,
        nearPlane: Float = 0.1,
        farPlane: Float = 100.0
    ) {
        self.position = position
        self.target = target
        self.up = up
        self.fieldOfView = fieldOfView
        self.aspectRatio = aspectRatio
        self.nearPlane = nearPlane
        self.farPlane = farPlane
        self.viewMatrix = .identity
        self.projectionMatrix = .identity
        
        // Initialize orbital parameters
        let offset = position - target
        self.radius = length(offset)
        self.phi = asin(offset.y / self.radius)
        self.theta = atan2(offset.x, offset.z)
        
        //Update Matrices
        updateViewMatrix()
        updateProjectionMatrix()
    }
    
    private func updateViewMatrix() {
        // Calculate camera position based on spherical coordinates
        position = target + vec3f(
            radius * cos(phi) * sin(theta),
            radius * sin(phi),
            radius * cos(phi) * cos(theta)
        )
        
        let normalizedUp = normalize(up)
        viewMatrix = .lookAt(eye: position, target: target, up: normalizedUp)
    }
    
    private func updateProjectionMatrix() {
        projectionMatrix = .perspective(
            fovYRadians: fieldOfView,
            aspect: aspectRatio,
            nearZ: nearPlane,
            farZ: farPlane
        )
    }
    
    // MARK: - Public Interface
    
    public func getViewMatrix() -> mat4f {
        return viewMatrix
    }
    
    public func getProjectionMatrix() -> mat4f {
        return projectionMatrix
    }
    
    public func getViewProjectionMatrix() -> mat4f {
        return projectionMatrix * viewMatrix
    }
    
    // MARK: - Camera Control
    
    public func orbit(deltaTheta: Float, deltaPhi: Float) {
        theta += deltaTheta
        phi += deltaPhi
        
        // Clamp phi to avoid camera flipping
        phi = min(max(phi, -Float.pi / 2 + 0.1), Float.pi / 2 - 0.1)
        
        updateViewMatrix()
    }
    
    public func zoom(factor: Float) {
        radius = max(1.0, radius * factor)
        updateViewMatrix()
    }
    
    public func setPosition(_ newPosition: vec3f) {
        position = newPosition
        updateViewMatrix()
    }
    
    public func setTarget(_ newTarget: vec3f) {
        target = newTarget
        updateViewMatrix()
    }
    
    public func setUp(_ newUp: vec3f) {
        up = newUp
        updateViewMatrix()
    }
    
    public func setAspectRatio(_ ratio: Float) {
        aspectRatio = ratio
        updateProjectionMatrix()
    }
    
    public func setFieldOfView(_ fov: Float) {
        fieldOfView = fov
        updateProjectionMatrix()
    }
    
    public func setNearPlane(_ near: Float) {
        nearPlane = near
        updateProjectionMatrix()
    }
    
    public func setFarPlane(_ far: Float) {
        farPlane = far
        updateProjectionMatrix()
    }
    
    public func moveInPlane(deltaX: Float, deltaY: Float) {
        let forward = normalize(target - position)
        let right = normalize(cross(forward, up))
        let trueUp = normalize(cross(right, forward))
        
        let movement = right * deltaX + trueUp * deltaY
        
        position += movement
        target += movement
        
        updateViewMatrix()
    }
}

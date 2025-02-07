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
    
    func update(deltaTime: TimeInterval) {
        guard state == .playing, let animationIndex = currentAnimationIndex else { return }
        
        let animation = model.animations[animationIndex]
        currentTime += deltaTime
        
        // Loop the animation by wrapping the current time around the duration.
        if currentTime > animation.duration {
            currentTime = currentTime.truncatingRemainder(dividingBy: animation.duration)
        }
        
        // Ensure there is at least one keyframe.
        let totalFrames = animation.translations.count
        guard totalFrames > 0 else { return }
        
        
     
        //interpolate beetween joints transforms ,and make shure that the animations is played corectrly
        
    }
}

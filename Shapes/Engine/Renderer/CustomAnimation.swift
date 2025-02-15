import Foundation
import simd


enum AnimationState {
    case stopped
    case playing
    case paused
}


class CustomAnimation {
    // Animation state
    private var recordedAnimation: CapturedAnimation?
    private var currentTime: TimeInterval = 0.0
    private var lastFrameTime: TimeInterval = 0.0
    private var state: AnimationState = .stopped
    private var isLooping: Bool = true  // Default to looping
    
    // Event system properties
    private var eventCallbacks: [AnimationEventCallback] = []
    
    // Animation control properties
    private var playbackSpeed: Float = 1.0
    private var isReversed: Bool = false
    
    // Animation event type
    enum AnimationEvent {
        case started
        case completed
        case looped
        case stopped
        case paused
        case resumed
    }
    
    // Callback type for animation events
    typealias AnimationEventCallback = (AnimationEvent) -> Void
    
    func play(animation: CapturedAnimation, startTime: TimeInterval = 0.0) {
        self.recordedAnimation = animation
        self.currentTime = startTime
        self.lastFrameTime = 0.0
        self.state = .playing
        notifyListeners(.started)
        print("Playing animation: \(animation.name)")
    }
    
    func pause() {
        guard state == .playing else { return }
        state = .paused
        notifyListeners(.paused)
        print("Animation paused")
    }
    
    func resume() {
        guard state == .paused else { return }
        state = .playing
        notifyListeners(.resumed)
        print("Animation resumed")
    }
    
    func stop() {
        recordedAnimation = nil
        currentTime = 0.0
        lastFrameTime = 0.0
        state = .stopped
        notifyListeners(.stopped)
        print("Animation stopped")
    }
    
    func setLooping(_ shouldLoop: Bool) {
        isLooping = shouldLoop
    }
    
    func update(deltaTime: TimeInterval) -> [mat4f] {
        guard let animation = recordedAnimation,
              !animation.capturedFrames.isEmpty,
              state == .playing else {
            return []
        }
        
        let adjustedDeltaTime = deltaTime * Double(playbackSpeed) * (isReversed ? -1 : 1)
        currentTime += adjustedDeltaTime
        
        let frameRate = Double(animation.frameRate)
        let totalDuration = Double(animation.duration)
        
        // Handle animation looping and completion
        if totalDuration > 0 {
            if isReversed {
                if currentTime < 0 {
                    if isLooping {
                        currentTime = totalDuration + currentTime.truncatingRemainder(dividingBy: totalDuration)
                        notifyListeners(.looped)
                    } else {
                        stop()
                        notifyListeners(.completed)
                        return []
                    }
                }
            } else {
                if currentTime > totalDuration {
                    if isLooping {
                        currentTime = currentTime.truncatingRemainder(dividingBy: totalDuration)
                        notifyListeners(.looped)
                    } else {
                        stop()
                        notifyListeners(.completed)
                        return []
                    }
                }
            }
        }
        
        // Calculate current frame index
        let progress = Float(currentTime / totalDuration)
        let frameCount = animation.capturedFrames.count
        let currentFrameIndex = Int(progress * Float(frameCount - 1)) % frameCount
        
        // Return the current frame's joint transforms directly without interpolation
        return animation.capturedFrames[currentFrameIndex].joints
    }
    
    // Animation control methods
    func setPlaybackSpeed(_ speed: Float) {
        playbackSpeed = max(0.1, speed)
    }
    
    func setReversed(_ reversed: Bool) {
        isReversed = reversed
    }
    
    func toggleDirection() {
        isReversed = !isReversed
    }
    
    // Event system methods
    func addEventListener(_ callback: @escaping AnimationEventCallback) {
        eventCallbacks.append(callback)
    }
    
    func removeAllEventListeners() {
        eventCallbacks.removeAll()
    }
    
    private func notifyListeners(_ event: AnimationEvent) {
        eventCallbacks.forEach { callback in
            callback(event)
        }
    }
    
    // Helper methods
    func getProgress() -> Float {
        guard let animation = recordedAnimation,
              animation.duration > 0 else {
            return 0
        }
        return Float(currentTime / Double(animation.duration))
    }
    
    var isPlaying: Bool {
        return state == .playing
    }
    
    var isPaused: Bool {
        return state == .paused
    }
    
    func getCurrentAnimation() -> CapturedAnimation? {
        return recordedAnimation
    }
    
    func seekTo(progress: Float) {
        guard let animation = recordedAnimation else { return }
        let clampedProgress = min(max(progress, 0), 1)
        currentTime = Double(clampedProgress) * Double(animation.duration)
    }
}

//
//  Time.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import Foundation
import MetalKit
import CoreFoundation

class Time {
    let maxDelta: Double = 0.1
    private var previousTime: CFTimeInterval
    private var startTime: CFTimeInterval
    private(set) var deltaTime: Double = 0.0
    private(set) var totalTime: Double = 0.0
    var deltaTimeFloat: Float { Float(deltaTime) }
    var totalTimeFloat: Float { Float(totalTime) }
    var now : Float

    init() {
        let initialTime = CACurrentMediaTime()
        self.previousTime = initialTime
        self.startTime = initialTime
        self.now = Float(CACurrentMediaTime())
    }

    func update() {
        let currentTime = CACurrentMediaTime()
        let rawDelta = currentTime - previousTime
        deltaTime = min(rawDelta, maxDelta)
        totalTime = currentTime - startTime
        previousTime = currentTime
        now =  Float(currentTime)
    }

    func reset() {
        let newTime = CACurrentMediaTime()
        previousTime = newTime
        startTime = newTime
        deltaTime = 0.0
        totalTime = 0.0
    }
}

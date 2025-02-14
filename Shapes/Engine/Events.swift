//
//  Events.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import SwiftUI
import Combine

enum TouchEventType {
    case drag(DragGesture.Value)
    case tap(CGPoint)
    case longPress(CGPoint)
    case pinch(MagnificationGesture.Value)
    case rotate(Angle)
    
    var position: CGPoint {
        switch self {
        case .drag(let value): return value.location
        case .tap(let point): return point
        case .longPress(let point): return point
        case .pinch, .rotate: return .zero
        }
    }
}

struct Event {
    let type: TouchEventType
    var delta: CGPoint
    var scale: CGFloat
    
    init(type: TouchEventType, delta: CGPoint = .zero, scale: CGFloat = 1.0) {
        self.type = type
        self.delta = delta
        self.scale = scale
    }
}

final class EventManager: ObservableObject {
    static let shared = EventManager()
    
    @Published private(set) var currentEvent: Event?
    @Published private(set) var isActive: Bool = false
    
    private var previousLocation: CGPoint = .zero
    private var previousScale: CGFloat = 1.0
    
    func process(_ event: Event) {
        var processedEvent = event
        isActive = true
        
        switch event.type {
        case .drag(let value):
            let currentLocation = value.location
            if previousLocation != .zero {
                processedEvent.delta = CGPoint(
                    x: (currentLocation.x - previousLocation.x) ,
                    y: (currentLocation.y - previousLocation.y)
                )
            }
            previousLocation = currentLocation
            
        case .pinch(let value):
            let scaleDelta = value / previousScale
            let zoomFactor = 1.0 + (1.0 - scaleDelta)
            
            processedEvent.scale = zoomFactor
            previousScale = value
            
        default:
            previousLocation = .zero
        }
        
        currentEvent = processedEvent
    }
    
    func endProcess() {
        isActive = false
        previousLocation = .zero
        previousScale = 1.0
        currentEvent = nil
    }
}

struct EventHandlingViewModifier: ViewModifier {
    @ObservedObject var manager: EventManager
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { manager.process(Event(type: .drag($0))) }
                    .onEnded { _ in manager.endProcess() }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { scale in
                        manager.process(Event(type: .pinch(scale)))
                    }
                    .onEnded { _ in
                        manager.endProcess()
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded { manager.process(Event(type: .tap(.zero))) }
            )
            .simultaneousGesture(
                LongPressGesture()
                    .onEnded { _ in manager.process(Event(type: .longPress(.zero))) }
            )
    }
}

extension View {
    func handleEvents(using manager: EventManager) -> some View {
        modifier(EventHandlingViewModifier(manager: manager))
    }
}

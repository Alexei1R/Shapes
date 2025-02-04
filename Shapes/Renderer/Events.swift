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
    case pinch(scale: CGFloat)
    case rotate(angle: Angle)
    
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
    var delta: CGPoint = .zero
}

final class EventManager: ObservableObject {
    static let shared = EventManager() // Singleton instance
    
    @Published private(set) var currentEvent: Event?
    @Published private(set) var isActive: Bool = false
    
    private var previousLocation: CGPoint = .zero
    
    func process(_ event: Event) {
        currentEvent = event
        isActive = true
        
        if case .drag(let value) = event.type {
            let currentLocation = value.location
            if previousLocation != .zero {
                currentEvent?.delta = CGPoint(
                    x: currentLocation.x - previousLocation.x,
                    y: currentLocation.y - previousLocation.y
                )
            }
            previousLocation = currentLocation
        } else {
            previousLocation = .zero
        }
        
#if DEBUG
        logEvent()
#endif
    }
    
    func endProcess() {
        isActive = false
        previousLocation = .zero
    }
    
    private func logEvent() {
        guard let event = currentEvent else { return }
        print("Delta: (x: \(String(format: "%.2f", event.delta.x)), y: \(String(format: "%.2f", event.delta.y)))")
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

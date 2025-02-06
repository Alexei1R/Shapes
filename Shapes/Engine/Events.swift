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
        
    }
    
    func endProcess() {
        isActive = false
        previousLocation = .zero
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


//import SwiftUI
//import Combine
//
//enum TouchEventType {
//    case drag(start: CGPoint, current: CGPoint)
//    case tap(CGPoint)
//    case longPress(CGPoint)
//    
//    var position: CGPoint {
//        switch self {
//        case .drag(_, let current): return current
//        case .tap(let pos), .longPress(let pos): return pos
//        }
//    }
//}
//
//struct Event {
//    let type: TouchEventType
//    var delta: CGSize = .zero
//}
//
//final class EventManager: ObservableObject {
//    static let shared = EventManager()
//    
//    @Published private(set) var currentEvent: Event?
//    @Published private(set) var isActive = false
//    private var dragStartLocation: CGPoint?
//    
//    func process(_ event: Event) {
//        switch event.type {
//        case .drag(let start, let current):
//            handleDrag(start: start, current: current)
//        default:
//            currentEvent = event
//            isActive = true
//        }
//    }
//    
//    private func handleDrag(start: CGPoint, current: CGPoint) {
//        let delta = CGSize(
//            width: current.x - (dragStartLocation?.x ?? start.x),
//            height: current.y - (dragStartLocation?.y ?? start.y)
//        )
//        
//        currentEvent = Event(
//            type: .drag(start: start, current: current),
//            delta: delta
//        )
//        dragStartLocation = current
//        isActive = true
//    }
//    
//    func endProcess() {
//        isActive = false
//        dragStartLocation = nil
//        currentEvent = nil
//    }
//}
//
//struct EventHandlingViewModifier: ViewModifier {
//    @ObservedObject var manager: EventManager
//    @State private var dragState: CGPoint?
//    
//    func body(content: Content) -> some View {
//        content
//            .gesture(dragGesture)
//            .gesture(tapGesture)
//            .gesture(longPressGesture)
//    }
//    
//    private var dragGesture: some Gesture {
//        DragGesture(minimumDistance: 1)
//            .onChanged { value in
//                let start = value.startLocation
//                let current = value.location
//                if dragState == nil {
//                    dragState = start
//                }
//                manager.process(Event(
//                    type: .drag(start: start, current: current),
//                    delta: value.translation
//                ))
//            }
//            .onEnded { value in
//                dragState = nil
//                manager.endProcess()
//            }
//    }
//    
//    private var tapGesture: some Gesture {
//        SpatialTapGesture()
//            .onEnded { value in
//                manager.process(Event(type: .tap(value.location)))
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                    manager.endProcess()
//                }
//            }
//    }
//    
//    private var longPressGesture: some Gesture {
//        LongPressGesture()
//            .onEnded { value in
//                manager.process(Event(type: .longPress(.zero)))
//                manager.endProcess()
//            }
//    }
//}
//
//extension View {
//    func handleEvents(using manager: EventManager) -> some View {
//        modifier(EventHandlingViewModifier(manager: manager))
//    }
//}

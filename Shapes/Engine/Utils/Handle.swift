//
//  Handle.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import Foundation


public class Handle: Hashable {
    private let id: UUID
    
    public init() {
        self.id = UUID()
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Handle, rhs: Handle) -> Bool {
        return lhs.id == rhs.id
    }
    
    public var description: String {
        return "Handle(\(id.uuidString))"
    }
    
    public var debugDescription: String {
        return description
    }
}

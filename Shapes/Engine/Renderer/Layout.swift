//
//  Layout.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//



import Foundation
import Metal

enum BufferDataType {
    case float
    case float2
    case float3
    case float4
    case int
    case int2
    case int3
    case int4
    case uint16
    case uint16x2
    case uint16x4
    case bool

    var metalFormat: MTLVertexFormat {
        switch self {
        case .float:     return .float
        case .float2:    return .float2
        case .float3:    return .float3
        case .float4:    return .float4
        case .int:       return .int
        case .int2:      return .int2
        case .int3:      return .int3
        case .int4:      return .int4
        case .uint16:    return .ushort
        case .uint16x2:  return .ushort2
        case .uint16x4:  return .ushort4
        case .bool:      return .uchar
        }
    }
    
    var byteSize: Int {
        switch self {
        case .float:     return 4
        case .float2:    return 8
        case .float3:    return 12
        case .float4:    return 16
        case .int:       return 4
        case .int2:      return 8
        case .int3:      return 12
        case .int4:      return 16
        case .uint16:    return 2
        case .uint16x2:  return 4
        case .uint16x4:  return 8
        case .bool:      return 1
        }
    }
    
    var alignment: Int {
        switch self {
        case .float:     return 4
        case .float2:    return 8
        case .float3:    return 16
        case .float4:    return 16
        case .int:       return 4
        case .int2:      return 8
        case .int3:      return 16
        case .int4:      return 16
        case .uint16:    return 2
        case .uint16x2:  return 4
        case .uint16x4:  return 8
        case .bool:      return 1
        }
    }
}

struct BufferElement {
    let name: String
    let type: BufferDataType
    let size: Int
    var offset: Int = 0
    
    init(type: BufferDataType, name: String) {
        self.name = name
        self.type = type
        self.size = type.byteSize
    }
}

class BufferLayout {
    private(set) var elements: [BufferElement]
    private(set) var stride: Int = 0
    
    init(elements: [BufferElement]) {
        self.elements = elements
        calculateLayout()
    }
    
    convenience init(elements: BufferElement...) {
        self.init(elements: elements)
    }
    
    private func calculateLayout() {
        var offset = 0
        var maxAlignment = 1
        
        for element in elements {
            maxAlignment = max(maxAlignment, element.type.alignment)
        }
        
        for i in 0..<elements.count {
            let dataType = elements[i].type
            offset = align(offset, to: dataType.alignment)
            
            var element = elements[i]
            element.offset = offset
            elements[i] = element
            
            offset += dataType.byteSize
        }
        
        stride = align(offset, to: maxAlignment)
    }
    
    private func align(_ offset: Int, to alignment: Int) -> Int {
        return (offset + alignment - 1) / alignment * alignment
    }
    
    
    func metalVertexDescriptor(bufferIndex: Int) -> MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()
        
        for (index, element) in elements.enumerated() {
            descriptor.attributes[index].format = element.type.metalFormat
            descriptor.attributes[index].offset = element.offset
            descriptor.attributes[index].bufferIndex = bufferIndex
        }
        
        descriptor.layouts[bufferIndex].stride = stride
        descriptor.layouts[bufferIndex].stepRate = 1
        descriptor.layouts[bufferIndex].stepFunction = .perVertex
        
        return descriptor
    }
}

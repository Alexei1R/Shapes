//
//  Buffer.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import Foundation

import Foundation
import MetalKit

enum BufferUsage {
    case uniforms
    case storagePrivate
    case storageShared
    
    var options: MTLResourceOptions {
        switch self {
        case .uniforms:
            return [.cpuCacheModeWriteCombined, .storageModeShared]
        case .storagePrivate:
            return [.storageModePrivate]
        case .storageShared:
            return [.storageModeShared]
        }
    }
}

enum BufferType {
    case vertex
    case fragment
}

class MetalBuffer<T> {
    private let device: MTLDevice
    private var buffer: MTLBuffer?
    private let usage: BufferUsage
    
    var count: Int
    var stride: Int { MemoryLayout<T>.stride }
    
    init(device: MTLDevice,
         elements: [T],
         usage: BufferUsage = .storageShared) {
        self.device = device
        self.usage = usage
        self.count = elements.count
        createBuffer(elements: elements)
    }
    
    init(device: MTLDevice,
         count: Int,
         usage: BufferUsage = .storageShared) {
        self.device = device
        self.usage = usage
        self.count = count
        createBuffer(size: count * MemoryLayout<T>.stride)
    }
    
    
    
    private func createBuffer(elements: [T]) {
        let size = elements.count * MemoryLayout<T>.stride
        buffer = device.makeBuffer(bytes: elements,
                                 length: size,
                                 options: usage.options)
    }
    
    private func createBuffer(size: Int) {
        buffer = device.makeBuffer(length: size,
                                 options: usage.options)
    }
    
    func update(with elements: [T], offset: Int = 0) {
        guard let bufferPointer = buffer?.contents() else { return }
        let offsetPointer = bufferPointer.advanced(by: offset)
        let sizeToUpdate = min(elements.count * stride,
                             (buffer?.length ?? 0) - offset)
        
        elements.withUnsafeBytes { rawBufferPointer in
            memcpy(offsetPointer,
                  rawBufferPointer.baseAddress,
                  sizeToUpdate)
        }
    }
    
    func update<U>(with data: U) {
        guard let bufferPointer = buffer?.contents() else { return }
        var value = data
        memcpy(bufferPointer, &value, MemoryLayout<U>.size)
    }
    
    func bind(to encoder: MTLRenderCommandEncoder,
              type: BufferType,
              index: Int,
              offset: Int = 0) {
        guard let buffer = buffer else { return }
        
        switch type {
        case .vertex:
            encoder.setVertexBuffer(buffer, offset: offset, index: index)
        case .fragment:
            encoder.setFragmentBuffer(buffer, offset: offset, index: index)
        }
    }
    
    func contents() -> UnsafeMutableRawPointer? {
        return buffer?.contents()
    }
    
    func raw() -> MTLBuffer? {
        return buffer
    }
}

// Extension for convenience initializers
extension MetalBuffer {
    convenience init?(device: MTLDevice,
                     element: T,
                     usage: BufferUsage = .storageShared) {
        self.init(device: device, elements: [element], usage: usage)
    }
}

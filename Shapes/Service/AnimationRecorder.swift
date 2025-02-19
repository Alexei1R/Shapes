//
//  JointRecorder.swift
//  Shapes
//
//  Created by Alexandr Novicov on 14.02.2025.
//

import Foundation
import simd

final class AnimationRecorder: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var capturedAnimation: CapturedAnimation? = nil
    
    private var recordingManager: RecordingManager
    private var disk: Disk = Disk()
    
    init(recordingManager: RecordingManager) {
        self.recordingManager = recordingManager
    }
    
    func saveCapturedAnimation() {
        do {
            // check directory
            if !FileManager.default.fileExists(atPath: disk.recordings.absoluteString) {
                do {
                    try FileManager.default.createDirectory(at: disk.recordings, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("🔴 Error: Could not create directory - \(error.localizedDescription)")
                    return
                }
            }
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(capturedAnimation)
            guard let capturedAnimation
            else { return }
            let url = disk.recordings.appendingPathComponent(capturedAnimation.name, conformingTo: .json)
            
            print(url)
            try data.write(to: url)
            recordingManager.recordings.append(capturedAnimation)
        } catch {
            print("🔴 Error in saving captured animation: " ,error.localizedDescription)
        }
    }
    
}


public struct CapturedJoint : Codable {
    let id: Int
    let name: String
    let path: String
    let bindTransform: mat4f
    let restTransform: mat4f
    let parentIndex: Int?
}

struct CapturedFrame: Codable {
    var id: Int
    var joints: [CapturedJoint]
    var timestamp: TimeInterval
    
    init(id: Int, joints: [CapturedJoint], timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.id = id
        self.joints = joints
        self.timestamp = timestamp
    }
}

struct CapturedAnimation: Codable, Equatable {
    var name: String
    var capturedFrames: [CapturedFrame]
    var duration: Float
    var frameRate: Float
    var recordingDate: Date
    
    init(name: String, capturedFrames: [CapturedFrame], duration: Float, frameRate: Float = 30.0 ) {
        self.name = name
        self.capturedFrames = capturedFrames
        self.duration = duration
        self.frameRate = frameRate
        self.recordingDate = Date()
    }
    static func == (lhs: CapturedAnimation, rhs: CapturedAnimation) -> Bool {
        return lhs.name == rhs.name
    }
    
    
}

extension simd_float4x4: Codable {
    enum CodingKeys: String, CodingKey {
        case columns
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let array = [columns.0, columns.1, columns.2, columns.3]
        try container.encode(array, forKey: .columns)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let array = try container.decode([SIMD4<Float>].self, forKey: .columns)
        
        guard array.count == 4 else {
            throw DecodingError.dataCorruptedError(forKey: .columns,
                                                   in: container,
                                                   debugDescription: "Invalid matrix size")
        }
        
        self.init(array[0], array[1], array[2], array[3])
    }
}


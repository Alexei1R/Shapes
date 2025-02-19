////
////  AnimationExporter.swift
////  Shapes
////
////  Created by rusu alexei on 19.02.2025.
////
//
//
///*
// 
// 
// 
// public struct CapturedJoint : Codable {
// let id: Int
// let name: String
// let path: String
// let bindTransform: mat4f
// let restTransform: mat4f
// let parentIndex: Int?
// }
// 
// struct CapturedFrame: Codable {
// var id: Int
// var joints: [CapturedJoint]
// var timestamp: TimeInterval
// 
// init(id: Int, joints: [CapturedJoint], timestamp: TimeInterval = Date().timeIntervalSince1970) {
// self.id = id
// self.joints = joints
// self.timestamp = timestamp
// }
// }
// 
// struct CapturedAnimation: Codable, Equatable {
// var name: String
// var capturedFrames: [CapturedFrame]
// var duration: Float
// var frameRate: Float
// var recordingDate: Date
// 
// init(name: String, capturedFrames: [CapturedFrame], duration: Float, frameRate: Float = 30.0) {
// self.name = name
// self.capturedFrames = capturedFrames
// self.duration = duration
// self.frameRate = frameRate
// self.recordingDate = Date()
// }
// static func == (lhs: CapturedAnimation, rhs: CapturedAnimation) -> Bool {
// return lhs.name == rhs.name
// }
// 
// 
// }
// 
// */
//
//import Foundation
//import ModelIO
//import simd
//import UIKit
//
//class AnimationExporter{
//    
//    
//    private var disk: Disk = Disk()
//    private var url : URL?
//    private var asset: MDLAsset
//    
//    
//    init() {
//        asset = MDLAsset()
//    }
//    
//    
//    private func documentsDirectoryURL() -> URL? {
//        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
//    }
//    
//    func exportAnimation(_ animation: CapturedAnimation, fileName: String? = nil) -> URL? {
//        
//        var fileExtension = "usdc"
//        if !MDLAsset.canExportFileExtension(fileExtension) {
//            print("Extension \(fileExtension) not supported. Falling back to 'usda'.")
//            fileExtension = "usda"
//        }
//        do {
//            if !FileManager.default.fileExists(atPath: disk.animations.absoluteString) {
//                do {
//                    try FileManager.default.createDirectory(at: disk.animations, withIntermediateDirectories: true, attributes: nil)
//                } catch {
//                    fatalError("🔴 Error: Could not create directory - \(error.localizedDescription)")
//                }
//            }
//            url = disk.animations.appendingPathComponent(animation.name).appendingPathExtension(fileExtension)
//        } catch {
//            print("🔴 Error in saving captured animation: " ,error.localizedDescription)
//        }
//        
//        
//        // NOTE: Export skeleton
//        let jointPaths = animation.capturedFrames.first?.joints.map { $0.path } ?? []
//        let skeleton = MDLSkeleton(name: animation.name, jointPaths: jointPaths)
//        print(jointPaths)
//        //get only the ocde that will help me export skeletons
//        
//        
//        if let fileURL = url as? URL {
//            do {
//                // Add animation
//                asset.add(skeleton)
//                //
//                try asset.export(to: fileURL)
//                print("Exported skeleton to \(fileURL)")
//                airDrop(url: fileURL)
//                return fileURL
//            } catch {
//                print("Error exporting skeleton: \(error.localizedDescription)")
//                return nil
//            }
//        }
//        
//        
//        
//        
//        
//        
//        
//        return url
//        
//    }
//    
//    
//    
//    func airDrop(url: URL) {
//        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//              let rootVC = windowScene.windows.first?.rootViewController else { return }
//        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
//        rootVC.present(activityVC, animated: true)
//    }
//    
//}
//
//
//

import Foundation
import ModelIO
import SwiftUI
import SceneKit


class AnimationExporter {
    private var disk: Disk = Disk()
    private var url: URL?
    private var asset: MDLAsset
    
    init() {
        asset = MDLAsset()
    }
    
    private func createSkeletonObject(from joints: [CapturedJoint]) -> MDLObject {
        let skeletonObject = MDLObject()
        skeletonObject.name = "Skeleton"
        
        // Create a hierarchy of MDLObjects for joints
        var jointObjects: [MDLObject] = []
        var rootJoints: [MDLObject] = []
        
        // First, create all joint objects
        for joint in joints {
            let jointObject = MDLObject()
            jointObject.name = joint.name
            
            // Create and set transform for the joint
            let transform = MDLTransform()
            transform.setLocalTransform(joint.bindTransform)
            jointObject.transform = transform
            
            jointObjects.append(jointObject)
            
            // If it's a root joint (no parent), add to roots array
            if joint.parentIndex == nil {
                rootJoints.append(jointObject)
            }
        }
        
        // Then, build the hierarchy
        for (index, joint) in joints.enumerated() {
            if let parentIndex = joint.parentIndex {
                let parentObject = jointObjects[parentIndex]
                parentObject.addChild(jointObjects[index])
            }
        }
        
        // Add root joints to the skeleton object
        for rootJoint in rootJoints {
            skeletonObject.addChild(rootJoint)
        }
        
        return skeletonObject
    }
    
    func exportAnimation(_ animation: CapturedAnimation, fileName: String? = nil) -> URL? {
        var fileExtension = "usdc"
        if !MDLAsset.canExportFileExtension(fileExtension) {
            print("Extension \(fileExtension) not supported. Falling back to 'usda'.")
            fileExtension = "usda"
        }
        
        // Setup export directory
        do {
            if !FileManager.default.fileExists(atPath: disk.animations.absoluteString) {
                try FileManager.default.createDirectory(at: disk.animations, withIntermediateDirectories: true, attributes: nil)
            }
            url = disk.animations.appendingPathComponent(animation.name).appendingPathExtension(fileExtension)
        } catch {
            print("🔴 Error in saving captured animation: ", error.localizedDescription)
            return nil
        }
        
        guard let firstFrame = animation.capturedFrames.first, !firstFrame.joints.isEmpty else {
            print("No joints found in the animation")
            return nil
        }
        
        // Debug print joint hierarchy
        print("\nJoint Hierarchy:")
        firstFrame.joints.enumerated().forEach { index, joint in
            let indent = String(repeating: "  ", count: joint.parentIndex?.distance(to: index) ?? 0)
            print("\(indent)[\(index)] \(joint.name) (Parent: \(String(describing: joint.parentIndex)))")
        }
        
        // Create skeleton object with hierarchy
        let skeletonObject = createSkeletonObject(from: firstFrame.joints)
        
        // Generate joint paths for animation
        let jointPaths = firstFrame.joints.enumerated().map { index, joint -> String in
            var path = joint.name
            var currentJoint = joint
            
            while let parentIndex = currentJoint.parentIndex,
                  parentIndex >= 0 && parentIndex < firstFrame.joints.count {
                let parent = firstFrame.joints[parentIndex]
                path = "\(parent.name)/\(path)"
                currentJoint = parent
            }
            
            return "/\(path)"
        }
        
        print("\nJoint Paths for Animation:")
        jointPaths.enumerated().forEach { index, path in
            print("[\(index)] \(path)")
        }
        
        // Create skeleton
        let skeleton = MDLSkeleton(name: "Skeleton", jointPaths: jointPaths)
        
        // Create animation data
        let packedAnimation = MDLPackedJointAnimation(name: "Animation", jointPaths: jointPaths)
        
        // Create animation bind component
        let bindComponent = MDLAnimationBindComponent()
        bindComponent.skeleton = skeleton
        bindComponent.jointAnimation = packedAnimation
        bindComponent.jointPaths = jointPaths
        bindComponent.geometryBindTransform = matrix_identity_double4x4
        
        // Add the bind component to the skeleton object
        skeletonObject.setComponent(bindComponent, for: MDLComponent.self)
        
        // Add skeleton object to asset
        asset.add(skeletonObject)
        
        // Export
        if let fileURL = url {
            do {
                try asset.export(to: fileURL)
                print("\nExport Summary:")
                print("- Animation Name: \(animation.name)")
                print("- Total Frames: \(animation.capturedFrames.count)")
                print("- Total Joints: \(firstFrame.joints.count)")
                print("- Duration: \(animation.duration)")
                print("- Frame Rate: \(animation.frameRate)")
                print("- Export Path: \(fileURL.path)")
                
                airDrop(url: fileURL)
                return fileURL
            } catch {
                print("Error exporting animation: \(error.localizedDescription)")
                return nil
            }
        }
        
        return nil
    }
    
    func airDrop(url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        rootVC.present(activityVC, animated: true)
    }
}

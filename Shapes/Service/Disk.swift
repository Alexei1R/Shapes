//
//  Disk.swift
//  Shapes
//
//  Created by Alexandr Novicov on 14.02.2025.
//
import Foundation

struct Disk {
    let localRoot = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).first!

    var recordings: URL {
        localRoot.appendingPathComponent("Recordings", conformingTo: .folder)
    }
    var models: URL {
        localRoot.appendingPathComponent("Models", conformingTo: .folder)
    }
    
    var animations: URL {
        localRoot.appendingPathComponent("Animations", conformingTo: .folder)
    }
}

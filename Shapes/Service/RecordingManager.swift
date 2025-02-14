//
//  RecordingManager.swift
//  Shapes
//
//  Created by Alexandr Novicov on 14.02.2025.
//
import Foundation

final class RecordingManager: ObservableObject {
    @Published var recordings: [CapturedAnimation] = []

    private var disk: Disk = Disk()

    init() {
        getRecordings()
    }

    func getRecordings() {
        do {
            let decoder = JSONDecoder()
            var fileURLs = try FileManager.default.contentsOfDirectory(at: disk.recordings, includingPropertiesForKeys: nil)
            for url in fileURLs {
                let data = try Data(contentsOf: url)
                let decodedData = try decoder.decode(CapturedAnimation.self, from: data)
                recordings.append(decodedData)
                
            }
        } catch {
            print("🔴 Error in decoding captured animation: " ,error.localizedDescription)
        }
    }
}

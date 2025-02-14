//
//  AppEnv.swift
//  Shapes
//
//  Created by Alexandr Novicov on 14.02.2025.
//

struct AppEnv {

    var recordingManager: RecordingManager
    var animationRecorder: AnimationRecorder
    static var shared: AppEnv {
        let recordingManager = RecordingManager()

        return AppEnv(
            recordingManager: recordingManager,
            animationRecorder: AnimationRecorder(recordingManager: recordingManager)
        )
    }
}

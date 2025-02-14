//
//  CameraViewModel.swift
//  Shapes
//
//  Created by Alexandr Novicov on 14.02.2025.
//

import Foundation
import Combine
import MetalKit

final class CameraViewModel: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordingName: String = ""
//    @Published var capturedAnimation: CapturedAnimation = CapturedAnimation(name: "", capturedFrames: [], duration: 0)
    private var startRecordingTime: TimeInterval? = nil
    private var frameRate: TimeInterval? = nil


    private var animationRecorder: AnimationRecorder
    private var cancellable = Set<AnyCancellable>()

    init(animationRecorder: AnimationRecorder) {
        self.animationRecorder = animationRecorder
        animationRecorder.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.isRecording = newValue
            }
            .store(in: &cancellable)
//        animationRecorder.$capturedAnimation
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] newValue in
//                guard let newValue
//                else { return }
//                self?.capturedAnimation = newValue
//            }
//            .store(in: &cancellable)
    }


    func startRecording() {
        startRecordingTime = CACurrentMediaTime()
        animationRecorder.capturedAnimation = .init(
            name: "",
            capturedFrames: [],
            duration: 0
        )
    }

    func endRecordind() {
        let deltaTime = CACurrentMediaTime() - (startRecordingTime ?? 0)
        print(deltaTime)
        animationRecorder.capturedAnimation?.duration = Float(deltaTime)
    }

    func saveRecording() {
        animationRecorder.capturedAnimation?.name = recordingName
        animationRecorder.saveCapturedAnimation()
        animationRecorder.capturedAnimation = nil
    }

    func handleFrame(capturedFrame: CapturedFrame) {
        let deltaTime = CACurrentMediaTime() - (frameRate ?? 0)
        // 30fps
        if deltaTime > 0.033 {
            frameRate = CACurrentMediaTime()
            if isRecording {
                animationRecorder.capturedAnimation?.capturedFrames.append(capturedFrame)
            }
        }
    }
}

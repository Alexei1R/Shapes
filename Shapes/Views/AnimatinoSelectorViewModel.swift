//
//  AnimatinoSelectorViewModel.swift
//  Shapes
//
//  Created by Alexandr Novicov on 14.02.2025.
//

import Foundation
import Combine

final class AnimatinoSelectorViewModel: ObservableObject {
    @Published var recordings: [CapturedAnimation] = []

    private var recordingManager: RecordingManager
    private var cancellable = Set<AnyCancellable>()

    init(recordingManager: RecordingManager) {
        self.recordingManager = recordingManager

        recordingManager.$recordings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.recordings = newValue
            }
            .store(in: &cancellable)
    }

    

}

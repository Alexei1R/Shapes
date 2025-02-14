//
//  AnimationSelectorView.swift
//  Shapes
//
//  Created by Alexandr Novicov on 14.02.2025.
//

import SwiftUI

struct AnimationSelectorView: View {

    @StateObject private var viewModel: AnimatinoSelectorViewModel = AnimatinoSelectorViewModel(recordingManager: AppEnv.shared.recordingManager)
    @Binding var selectedAnimation: CapturedAnimation?

    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(viewModel.recordings, id: \.name) { recording in
                        Text(recording.name)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(lineWidth: 3)
                                    .foregroundStyle(selectedAnimation?.name == recording.name ? .red : .gray)
                            )
                            .onTapGesture {
                                selectedAnimation = recording
                            }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    AnimationSelectorView(selectedAnimation: .constant(nil))
}

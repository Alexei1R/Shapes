//
//  CameraView.swift
//  Shapes
//
//  Created by Alexandr Novicov on 14.02.2025.
//

import SwiftUI

struct CameraView: View {

    @Binding var selectedTab: TabItem
    @StateObject private var viewModel: CameraViewModel = CameraViewModel(animationRecorder: AppEnv.shared.animationRecorder)
    @State private var showPopUp: Bool = false

    var body: some View {
        ZStack {
            ARViewContainer(handleFrame: { frame in
                viewModel.handleFrame(capturedFrame: frame)
            })
                .ignoresSafeArea()
            if showPopUp {
                createEndScanPopUp()
            }

        }
        .overlay(alignment: .topTrailing) {
            modeButton(
                iconName: "chevron.right",
                color: .green) {
                    selectedTab = .modelView
                }
                .padding(.top, 32)
                .padding(.horizontal, 8)
        }
        .overlay(alignment: .bottom) {
            createRecordButton()
                .padding(.bottom, 20)
        }
    }
}

#Preview {
    CameraView(selectedTab: .constant(.camera))
}

private extension CameraView {
    func modeButton(iconName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 22))
                .bold()
                .foregroundColor(color)
                .frame(width: 48, height: 48)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
        }
    }

    func createRecordButton() -> some View {
        VStack {
            Image(systemName: viewModel.isRecording ? "square.fill" : "circle.fill")
                .resizable()
                .frame(
                    width: 20,
                    height: 20
                )
                .padding(25)
                .foregroundStyle(.red)
                .background(
                    Circle()
                        .foregroundStyle(.black)
                        .opacity(0.6)
                )
                .onTapGesture {
                    if viewModel.isRecording {
                        print("end")
                        viewModel.endRecordind()
                        showPopUp = true
                    } else {
                        viewModel.startRecording()
                        print("start")
                    }
                    viewModel.isRecording.toggle()
                }
        }
        .frame(maxWidth: .infinity)
        .coordinateSpace(name: "Record")
        .padding(.bottom, 45)
        .ignoresSafeArea()
    }

    func createEndScanPopUp() -> some View {
        ZStack {
            VStack(spacing: 16) {
                Text("Save recording")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.top, 16)

                VStack(spacing: 16) {
                    Button {
                        viewModel.saveRecording()
                        showPopUp = false
                    } label: {
                        HStack {
                            TextField(text: $viewModel.recordingName, prompt: Text("")) {}
                                .foregroundColor(.white)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(lineWidth: 3)
                                        .foregroundStyle(.white)
                                )
                            Image(systemName: "square.and.arrow.down.fill")
                        }
                        .font(.system(size: 20))
                        .foregroundColor(.yellow)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                        
                    }
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .overlay(alignment: .topTrailing, content: {
                Image(systemName: "xmark")
                    .onTapGesture {
                        showPopUp = false
                    }
            })
            .frame(width: 300, height: 200)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }

}

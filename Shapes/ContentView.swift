//  ContentView.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import SwiftUI
import MetalKit

struct ContentView: View {
    @StateObject private var eventManager = EventManager.shared
    @StateObject private var drawable = Drawable(device: MTLCreateSystemDefaultDevice()!)
    @State private var showingSettings = false
    @State private var currentMode = "Rotate Mode"
    @State private var isPlaying = false
    @State private var hasStarted = false
    
    var body: some View {
        ZStack {
            ScanView(drawable: drawable)
                .edgesIgnoringSafeArea(.all)
                .handleEvents(using: eventManager)
                .onAppear {
                    drawable.playAnimation(index: 0)
                    isPlaying = true
                    hasStarted = true
                }
            
            VStack {
                HStack {
                    VStack(spacing: 4) {
                        modeButton(
                            iconName: "arrow.triangle.2.circlepath",
                            color: .orange,
                            action: {
                                drawable.setMovementMode(.rotate)
                                currentMode = "Rotate Mode"
                            }
                        )
                        
                        modeButton(
                            iconName: "arrow.up.and.down.and.arrow.left.and.right",
                            color: .green,
                            action: {
                                drawable.setMovementMode(.moveInPlane)
                                currentMode = "Translate Mode"
                            }
                        )
                        
                        modeButton(
                            iconName: isPlaying ? "pause.fill" : "play.fill",
                            color: .blue,
                            action: {
                                if isPlaying {
                                    drawable.pauseAnimation()
                                } else {
                                    drawable.resumeAnimation()
                                }
                                isPlaying.toggle()
                            }
                        )
                        
                        modeButton(
                            iconName: "gearshape.fill",
                            color: .white,
                            action: {
                                showingSettings.toggle()
                            }
                        )
                    }
                    .padding(.top, 32)
                    .padding(.leading, 8)
                    
                    Spacer()
                }
                Spacer()
            }
            
            VStack {
                Spacer()
                Text(currentMode)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(16)
                    .padding(.bottom, 20)
            }
            
            if showingSettings {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showingSettings = false
                    }
                
                VStack(spacing: 16) {
                    Text("Joint Controls")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(.top, 16)
                    
                    HStack(spacing: 16) {
                        Button(action: { drawable.selectPreviousJoint() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20))
                                .foregroundColor(.yellow)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(12)
                        }
                        
                        Text("Joint \(drawable.currentJointIndex)")
                            .foregroundColor(.white)
                            .frame(width: 100)
                        
                        Button(action: { drawable.selectNextJoint() }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 20))
                                .foregroundColor(.yellow)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer()
                }
                .frame(width: 300, height: 200)
                .background(Color.black.opacity(0.8))
                .cornerRadius(16)
                .shadow(radius: 10)
            }
        }
    }
    
    private func modeButton(iconName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 48, height: 48)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
        }
    }
}

//
//  ContentView.swift
//  Shapes
//
//  Created by rusu alexei on 04.02.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var eventManager = EventManager.shared
    @StateObject private var drawable = Drawable(device: MTLCreateSystemDefaultDevice()!)
    
    var body: some View {
        ZStack {
            ScanView(drawable: drawable)
                .edgesIgnoringSafeArea(.all)
                .handleEvents(using: eventManager)
            
            VStack {
                Spacer()
                
                HStack {
                    Button(action: {
                        drawable.playAnimation(index: 0 )
                    }) {
                        Text("Play")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        drawable.stopAnimation()
                    }) {
                        Text("Pause")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }

                    
                }
                HStack {
                    Button(action: {
                        drawable.selectPreviousJoint()
                    }) {
                        Text("Previous Joint")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Text("Joint: \(drawable.currentJointIndex)")
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(5)
                    
                    Button(action: {
                        drawable.selectNextJoint()
                    }) {
                        Text("Next Joint")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                }
                .padding()
            }
        }
    }
}
